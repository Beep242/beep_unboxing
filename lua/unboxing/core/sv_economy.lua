BCORE = BCORE or {}
BCORE.Unbox = BCORE.Unbox or {}

local u = BCORE.Unbox
local thread = BCORE.netstream

u.Items = u.Items or {}
u.Cases = u.Cases or {}
u.Players = u.Players or {}
u.Types = u.Types or {}

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

function u:OpenCase(caseName, ply)
    local p = self:GetPlayer(ply)
    if not p.cases[caseName] or p.cases[caseName] <= 0 then return end
    local case = u.Cases[caseName]
    if not case then return end

    -- Build weighted pool from all case items
    local weights   = case.weights or {}
    local caseItems = case.CaseItems or {}
    local pool      = {}
    local total     = 0

    for k in pairs(caseItems) do
        local w = tonumber(weights[k]) or 10
        total   = total + w
        table.insert(pool, { key = k, w = w })
    end

    -- Fall back to legacy per-rarity pool if no CaseItems
    if #pool == 0 then
        local rarity = rollRarity()
        local legPool = case.items and case.items[rarity]
        if not legPool or #legPool == 0 then return end
        for _, k in ipairs(legPool) do
            table.insert(pool, { key = k, w = 10 })
            total = total + 10
        end
    end

    if total <= 0 then return end

    local rand = math.random() * total
    local cum  = 0
    local chosen
    for _, entry in ipairs(pool) do
        cum = cum + entry.w
        if rand <= cum then chosen = entry.key; break end
    end
    chosen = chosen or pool[#pool].key

    p.cases[caseName] = p.cases[caseName] - 1
    if p.cases[caseName] <= 0 then p.cases[caseName] = nil end

    self:GiveItem(chosen, ply)
    self:SavePlayer(ply)

    local chosenItem = caseItems[chosen] or u.Items[chosen] or {}
    return chosen, chosenItem.rarity or "common"
end

function u:UseItem(itemName, ply)
    local item = u.Items[itemName]
    if not item then return end

    if item.type and u.Types[item.type] and u.Types[item.type].onAction then
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
    local item = u.Items[itemName]
    if not item or not item.soldInStore then return end

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