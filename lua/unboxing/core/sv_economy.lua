BCORE = BCORE or {}
BCORE.Unbox = BCORE.Unbox or {}

local u = BCORE.Unbox
local thread = BCORE.netstream

u.Items = u.Items or {}
u.Cases = u.Cases or {}
u.Players = u.Players or {}
u.Types = u.Types or {}
-- Per-TYPE custom "on use" script (typeName -> Lua source), editable in-game via the Unbox
-- admin panel's TYPES tab (cl_unbox.lua) - see u:UseItem below for how this fits between a
-- per-item override and the compiled-in u.Types[..].onAction default.
u.TypeCode = u.TypeCode or {}

-- These defaults are overridden in-game via BCORE.Config once mainconfig/sh_config.lua loads
-- (see its own SyncUnboxConfigMirror) - kept as real fallback values here too so this addon
-- still works with the same behavior as before if that config layer is ever unavailable.
u.RarityWeights = u.RarityWeights or {
    common = 60,
    uncommon = 25,
    rare = 10,
    epic = 4,
    legendary = 1
}

local function rollRarity()
    local roll = math.random(1,100)
    local acc = 0
    for r, w in pairs(u.RarityWeights) do
        acc = acc + w
        if roll <= acc then
            return r
        end
    end
    return "common"
end

-- "At or above" a configured rarity, using the SAME weight table the roll itself uses -
-- LOWER weight means rarer (legendary = 1, common = 60), so a rarity "qualifies" once its own
-- weight drops to or below the configured threshold's weight. This reuses u.RarityWeights
-- directly instead of a second hardcoded order list, so admin edits to Rarity Roll Weights
-- (sh_config.lua) automatically keep the announcement threshold consistent with actual drop
-- odds - no separate table to fall out of sync.
util.AddNetworkString("BCORE:UnboxAnnounce")
function u:AnnounceUnbox(ply, itemKey, rarity)
    local threshold = u.AnnounceRarity
    if not threshold or threshold == "Off" then return end

    local thresholdWeight = u.RarityWeights[string.lower(threshold)]
    local itemWeight = u.RarityWeights[string.lower(rarity or "common")]
    if not thresholdWeight or not itemWeight or itemWeight > thresholdWeight then return end

    local itemDef = u.Items[itemKey] or {}
    thread.Start(nil, "BCORE:UnboxAnnounce", {
        plyName  = IsValid(ply) and ply:Nick() or "Someone",
        itemName = itemDef.name or itemKey,
        rarity   = rarity or "common",
    })
end

function u:CreateItem(name, data)
    data.name = name
    u.Items[name] = data
end

function u:CreateCase(name, data)
    u.Cases[name] = data
end

function u:GiveItem(item, ply)
    local p = self:GetPlayer(ply)
    p.inventory[item] = (p.inventory[item] or 0) + 1
    self:SavePlayer(ply)
end

function u:GiveCase(caseName, ply)
    local p = self:GetPlayer(ply)
    p.cases[caseName] = (p.cases[caseName] or 0) + 1
    self:SavePlayer(ply)
end

function u:RemoveItem(item, ply)
    local p = self:GetPlayer(ply)
    if not p.inventory[item] then return end
    p.inventory[item] = p.inventory[item] - 1
    if p.inventory[item] <= 0 then p.inventory[item] = nil end
    self:SavePlayer(ply)
end

-- Generic weighted pick over a `{ {key=..., w=...}, ... }` pool - extracted out of this
-- function's own former inline copy so Trade-Up (sv_tradein.lua) and Case Battles
-- (sv_casebattles.lua) can roll from a weighted pool the exact same tested way, instead of each
-- reimplementing the cumulative-weight loop separately. Returns nil if the pool is empty/total
-- is non-positive.
function u:RollFromPool(pool, total)
    if not pool or #pool == 0 or not total or total <= 0 then return nil end
    local rand = math.random() * total
    local cum = 0
    for _, entry in ipairs(pool) do
        cum = cum + entry.w
        if rand <= cum then return entry.key end
    end
    return pool[#pool].key
end

-- Builds the weighted item pool for a case (real CaseItems/weights, falling back to the legacy
-- per-rarity pool the same way u:OpenCase always has) - extracted so Case Battles can roll from
-- the SAME pool a normal case open would, without duplicating this fallback logic.
-- Returns pool, total, caseItems (caseItems is needed by callers to resolve a chosen key's own
-- rarity afterward).
function u:BuildCasePool(caseName)
    local case = u.Cases[caseName]
    if not case then return nil end

    local weights   = case.weights or {}
    local caseItems = case.CaseItems or {}
    local pool      = {}
    local total     = 0

    for k in pairs(caseItems) do
        local w = tonumber(weights[k]) or 10
        total   = total + w
        table.insert(pool, { key = k, w = w })
    end

    if #pool == 0 then
        local rarity = rollRarity()
        local legPool = case.items and case.items[rarity]
        if not legPool or #legPool == 0 then return nil end
        for _, k in ipairs(legPool) do
            table.insert(pool, { key = k, w = 10 })
            total = total + 10
        end
    end

    return pool, total, caseItems
end

function u:OpenCase(caseName, ply)
    local p = self:GetPlayer(ply)
    if not p.cases[caseName] or p.cases[caseName] <= 0 then return end

    local pool, total, caseItems = self:BuildCasePool(caseName)
    if not pool then return end

    local chosen = self:RollFromPool(pool, total)
    if not chosen then return end

    p.cases[caseName] = p.cases[caseName] - 1
    if p.cases[caseName] <= 0 then p.cases[caseName] = nil end

    self:GiveItem(chosen, ply)
    self:SavePlayer(ply)

    local chosenItem = caseItems[chosen] or u.Items[chosen] or {}
    return chosen, chosenItem.rarity or "common"
end

-- Executes an admin-authored Lua snippet as either an item's own override, or a whole TYPE's
-- "on use" behavior - identifier is just a stable, human-readable tag for error messages/
-- CompileString's own internal naming, it has no functional effect. Compiled fresh every call
-- rather than cached, so an admin's live edit (of an item OR a type) takes effect immediately
-- with no server restart - a single player pressing "Use" is rare enough that recompiling each
-- time is not a real cost. The snippet gets `ply` (the player using the item) and `item` (this
-- specific item's own definition table) as its own varargs - `local ply, item = ...` is
-- prepended automatically so an admin never has to remember that boilerplate.
function u:RunOnUseCode(code, identifier, item, itemName, ply)
    local wrapped = "local ply, item = ...\n" .. code

    -- CompileString's third arg (false) makes a syntax error come back as a STRING instead of
    -- throwing immediately - isfunction() is what actually distinguishes "compiled fine" from
    -- "here's the error message" below.
    local func = CompileString(wrapped, identifier, false)
    if not isfunction(func) then
        print("[Unbox] OnUseCode compile error (" .. identifier .. "): " .. tostring(func))
        if IsValid(ply) then ply:ChatPrint("[Unbox] '" .. (item.name or itemName) .. "' has a broken custom script - contact an admin.") end
        return
    end

    local ok, err = pcall(func, ply, item)
    if not ok then
        print("[Unbox] OnUseCode runtime error (" .. identifier .. "): " .. tostring(err))
        if IsValid(ply) then ply:ChatPrint("[Unbox] '" .. (item.name or itemName) .. "' failed to activate - contact an admin.") end
    end
end

function u:UseItem(itemName, ply)
    local item = u.Items[itemName]
    if not item then return end

    -- Priority order: (1) this specific item's own override script, if an admin wrote one for
    -- it specifically - (2) the ITEM'S TYPE's own custom script, if an admin wrote one for the
    -- whole category (the main way this is meant to be used - see the admin panel's TYPES tab)
    -- - (3) the compiled-in Lua default for that type (u:RegisterType above) as a safety net so
    -- a type with no custom script written yet still does something sensible.
    if item.onUseCode and item.onUseCode ~= "" then
        self:RunOnUseCode(item.onUseCode, "unbox_item_" .. tostring(itemName), item, itemName, ply)
    elseif item.type and u.TypeCode[item.type] and u.TypeCode[item.type] ~= "" then
        self:RunOnUseCode(u.TypeCode[item.type], "unbox_type_" .. tostring(item.type), item, itemName, ply)
    elseif item.type and u.Types[item.type] and u.Types[item.type].onAction then
        u.Types[item.type].onAction(ply, item)
    elseif item.onAction then
        item.onAction(ply)
    end

    if item.onAction ~= false then
        self:RemoveItem(itemName, ply)
    end
end


function u:CheckInventory(ply)
    return self:GetPlayer(ply).inventory
end

function u:CheckCases(ply)
    return self:GetPlayer(ply).cases
end

function u:CheckItem(item)
    return u.Items[item]
end

function u:CheckCase(caseName)
    return u.Cases[caseName]
end

function u:RegisterType(name, data)
    data.id = name
    u.Types[name] = data
end

function u:GetType(name)
    return u.Types[name]
end

-- Real, previously-missing default behavior for the two built-in item CATEGORY/TYPE choices
-- (sh_config.lua's ItemTypes list). u:RegisterType existed as a real extension point, but
-- nothing ever actually called it - u.Types was permanently empty, so u:UseItem's type-based
-- dispatch always found nothing and silently fell through, meaning EVERY unbox item (weapon or
-- otherwise) did nothing but delete itself the instant a player used it.
u:RegisterType("Weapon", {
    onAction = function(ply, item)
        if not IsValid(ply) or not item.class or item.class == "" then return end
        ply:Give(item.class)
    end
})

u:RegisterType("Consumable", {
    -- No universal built-in effect makes sense for an arbitrary "Consumable" - unlike Weapon
    -- (always just give the class), a consumable's real behavior is meant to be written
    -- per-item via the admin item editor's CODE field (u.onUseCode, see u:RunItemOnUseCode
    -- above). This only exists so using a consumable with no code written yet gives clear
    -- feedback instead of silently vanishing with zero explanation.
    onAction = function(ply, item)
        if IsValid(ply) then
            ply:ChatPrint("[Unbox] '" .. (item.name or "This item") .. "' has no effect configured yet.")
        end
    end
})

local DefaultWeapons = {
    "keys", "pocket", "weapon_physgun", "weapon_physcannon", "gmod_tool",
    "weapon_keypadchecker", "weaponchecker", "arrest_stick", "unarrest_stick",
    "stunstick", "door_ram", "med_kit", "weapon_fists", "gmod_camera",

    "weapon_pistol", "weapon_357", "weapon_smg1", "weapon_ar2", "weapon_shotgun",
    "weapon_crossbow", "weapon_frag", "weapon_crowbar", "weapon_rpg",
    "weapon_slam", "weapon_bugbait"
}

local DefaultWeaponSet = {}
for _, wep in ipairs(DefaultWeapons) do
    DefaultWeaponSet[wep] = true
end




function u:ImportWeapons()
    for _, swep in ipairs(weapons.GetList()) do
        if not swep.ClassName then continue end

        if DefaultWeaponSet[swep.ClassName] then return end

        if swep.Spawnable == false then continue end
        if swep.AdminOnly then continue end
        if swep.Category == "Tools" then continue end

        local dmg = swep.Primary and swep.Primary.Damage or 0
        local rpm = swep.Primary and swep.Primary.Delay and (60 / swep.Primary.Delay) or 0
        local clip = swep.Primary and swep.Primary.ClipSize or 0
        local recoil = swep.Primary and swep.Primary.Recoil or 0
        local auto = swep.Primary and swep.Primary.Automatic or false

        local score =
            (dmg * 1.5) +
            (rpm * 0.05) +
            (clip * 0.3) -
            (recoil * 5)

        local rarity = "common"
        if score >= 250 then rarity = "legendary"
        elseif score >= 180 then rarity = "epic"
        elseif score >= 120 then rarity = "rare"
        elseif score >= 70 then rarity = "uncommon" end

        -- Preserve admin-configured fields if the item already exists from LoadFromDisk.
        -- Without this, ImportWeapons on every startup wipes soldInStore and basePrice.
        local existing = u.Items[swep.ClassName]
        u:CreateItem(swep.ClassName, {
            name        = swep.PrintName or swep.ClassName,
            class       = swep.ClassName,
            type        = "Weapon",
            rarity      = rarity,
            basePrice   = existing and existing.basePrice   or nil,
            soldInStore = existing and existing.soldInStore or false,
            model       = (existing and existing.model)
                          or swep.WorldModel or swep.ViewModel or nil,
        })
    end
end

u.RarityPricing = u.RarityPricing or {
    common = 1,
    uncommon = 1.25,
    rare = 1.75,
    epic = 2.5,
    legendary = 4
}

-- Sorted descending by minAmount - the first tier whose threshold the purchase amount meets
-- or exceeds wins. Also overridden in-game via BCORE.Config (see sh_config.lua).
u.BulkDiscounts = u.BulkDiscounts or {
    { minAmount = 50, multiplier = 0.85 },
    { minAmount = 20, multiplier = 0.9 },
    { minAmount = 10, multiplier = 0.95 },
}

function u:GetDynamicPrice(itemName, amount)
    local item = u.Items[itemName]
    if not item or not item.basePrice then return end

    local rarity = item.rarity or "common"
    local rarityMul = u.RarityPricing[rarity] or 1

    local bulkMul = 1
    for _, tier in ipairs(u.BulkDiscounts) do
        if amount >= (tier.minAmount or math.huge) then
            bulkMul = tier.multiplier or 1
            break
        end
    end

    local pricePer = math.floor(item.basePrice * rarityMul * bulkMul)
    return pricePer, pricePer * amount
end

function u:PurchaseCase(ply, caseKey, amount)
    if not IsValid(ply) then return end
    local case = u.Cases[caseKey]
    if not case or not case.Price then return end
    amount = math.max(1, math.floor(tonumber(amount) or 1))
    local total = case.Price * amount
    if ply.getDarkRPVar and ply:getDarkRPVar("money") < total then return end
    if ply.addMoney then ply:addMoney(-total) end
    for i = 1, amount do
        u:GiveCase(caseKey, ply)
    end
    u:Sync(ply)
    return true
end

thread.Hook("BCORE:UnboxBuyCase", function(ply, data)
    if not data or not data.caseKey then return end
    local ok = u:PurchaseCase(ply, data.caseKey, data.amount or 1)
    if ok then
        BCORE.netstream.Start(ply, "BCORE:UnboxAdmin.Result",
            {ok=true, msg="Case purchased!"})
    end
end)

function u:PurchaseItem(ply, itemName, amount)
    if not IsValid(ply) then return end
    amount = math.max(1, math.floor(tonumber(amount) or 1))

    -- The shop UI hides an item with soldInStore=false purely client-side (cl_shop.lua) - the
    -- server has to enforce it too, or a crafted purchase request could still buy anything
    -- with a basePrice regardless of whether an admin hid it from the store.
    -- `not item.soldInStore` was ALSO true for soldInStore left unset (nil) - every other place
    -- in this addon (isForSale in cl_shop.lua, the comments in sv_admin.lua) documents nil as
    -- meaning "shown/purchasable by default", same as true, with only an explicit false
    -- meaning hidden. This blocked a real purchase for any item an admin never explicitly
    -- flipped the CAN SELL dropdown on, with no error shown to the player - the client already
    -- fired its own "Purchase sent!" toast optimistically, so it silently looked like nothing
    -- happened at all.
    local item = u.Items[itemName]
    if not item or item.soldInStore == false then return end

    local pricePer, total = self:GetDynamicPrice(itemName, amount)
    if not total then return end

    if ply.getDarkRPVar and ply:getDarkRPVar("money") < total then return end
    if ply.addMoney then ply:addMoney(-total) end

    for i = 1, amount do
        self:GiveItem(itemName, ply)
    end

    self:Sync(ply)
    return true, pricePer, total
end