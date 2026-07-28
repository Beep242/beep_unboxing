BCORE.Unbox = BCORE.Unbox or {}
local u      = BCORE.Unbox
local thread = BCORE.netstream

--------------------------------------------------------------------------------
-- SANITIZE
-- PON (the netstream serializer) cannot handle function values, metatables,
-- userdata, or any non-plain type.  Strip every item down to the five fields
-- that the client actually needs before anything touches the network.
--------------------------------------------------------------------------------
local function sanitizeItems(items)
    local out = {}
    for k, v in pairs(items or {}) do
        if type(v) == "table" then
            out[k] = {
                name        = v.name,
                class       = v.class,
                type        = v.type,
                rarity      = v.rarity,
                basePrice   = v.basePrice,
                -- Real, previously-missing fields: cl_shop.lua's isForSale() reads
                -- item.soldInStore (`~= false` means "show it"), but this sanitizer never sent
                -- it at all - every item's soldInStore was always nil on the regular player-
                -- facing payload, which reads as "for sale" regardless of what the admin
                -- actually configured in the item editor. model is likewise real, needed data
                -- (cl_shop.lua's 3D preview reads item.model directly) that was silently
                -- dropped the same way. onUseCode is deliberately NOT included here - it's
                -- server-only logic (u:UseItem, sv_economy.lua) with no reason to ship raw Lua
                -- source to every connected client.
                soldInStore = v.soldInStore,
                model       = v.model,
            }
        end
    end
    return out
end

local function sanitizeCaseDefs(cases)
    local out = {}
    for k, v in pairs(cases or {}) do
        -- Real, reported bug (the deeper root cause behind the one the comment below already
        -- documents): v.itemKeys itself was NEVER actually populated by a save through the admin
        -- panel (sv_admin.lua's SaveCase handler only ever built .CaseItems/.weights/._byRarity,
        -- never the flat .itemKeys list) - so forwarding "v.itemKeys or {}" here still always
        -- forwarded an empty table for every case saved before that fix, regardless of how many
        -- items it actually has. SaveCase now populates itemKeys going forward, but a case saved
        -- BEFORE that fix (already sitting in memory/on disk with no itemKeys of its own) would
        -- otherwise stay broken until an admin re-opens and re-saves it. Falling back to
        -- deriving itemKeys from _byRarity here (the exact same derivation sanitizeCases already
        -- does for the admin panel's own view, sv_admin.lua) self-heals any such case immediately
        -- on the very next sync, no re-save required.
        local keys = v.itemKeys
        if not keys or #keys == 0 then
            keys = {}
            if v._byRarity then
                for _, pool in pairs(v._byRarity) do
                    for _, ik in ipairs(pool) do table.insert(keys, ik) end
                end
            end
        end

        out[k] = {
            Name      = v.Name,
            Rarity    = v.Rarity,
            Price     = v.Price,
            itemCount = v._itemCount or 0,
            -- Same "sanitizer silently drops a field the client actually reads" bug class as
            -- sanitizeItems' own soldInStore/model fix above, just never caught here until now:
            -- Model was dropped entirely, so every case card (cl_dash.lua/cl_inventory.lua, both
            -- read cdef.Model directly) fell back to the default oildrum regardless of what an
            -- admin set in the case editor - the whole per-case Model feature was silently inert.
            -- itemKeys/weights were ALSO dropped entirely (only a precomputed itemCount was
            -- sent), which broke cl_shop.lua's own "VIEW CONTENTS" popup - it reads case.itemKeys/
            -- case.weights directly to build the odds list, so it always saw an empty pool and
            -- showed "No items in this case" regardless of the case's real contents.
            Model     = v.Model,
            itemKeys  = keys,
            weights   = v.weights or {},
        }
    end
    return out
end

local function sanitizeInventory(inv)
    local out = {}
    for k, v in pairs(inv or {}) do
        if type(k) == "string" and type(v) == "number" then
            out[k] = v
        end
    end
    return out
end

--------------------------------------------------------------------------------
-- BUILD SYNC PAYLOAD
--------------------------------------------------------------------------------
function u:BuildSyncData(ply)
    local id = ply:SteamID64()
    local pd = u.Players[id] or {}

    local prices = {}
    for k in pairs(u.Items) do
        local p = u:GetDynamicPrice(k, 1)
        if p then prices[k] = p end
    end

    return {
        inventory = sanitizeInventory(pd.inventory),
        cases     = sanitizeInventory(pd.cases),      -- same shape: {name=count}
        items     = sanitizeItems(u.Items),            -- ← no functions, ever
        caseDefs  = sanitizeCaseDefs(u.Cases),
        prices    = prices,
    }
end

function u:Sync(ply)
    if not IsValid(ply) then return end
    thread.Start(ply, "BCORE:UnboxSendData", self:BuildSyncData(ply))
end

--------------------------------------------------------------------------------
-- HOOKS
--------------------------------------------------------------------------------
thread.Hook("BCORE:UnboxRequestSync", function(ply)
    if IsValid(ply) then u:Sync(ply) end
end)

thread.Hook("BCORE:UnboxPurchase", function(ply, data)
    if not IsValid(ply) or not data then return end
    local ok, _, total = u:PurchaseItem(ply, data.itemName, data.amount or 1)
    if ok then u:Sync(ply) end
end)

thread.Hook("BCORE:UnboxAction", function(ply, data)
    if not IsValid(ply) or not data then return end
    u:UseItem(data.itemName, ply)
    u:Sync(ply)
end)

-- Opening N cases with real individual animations still means N separate reel spins client
-- side (each takes a few real seconds) - capped well below the shop's own bulk-buy quantities
-- (which just add to a count, no per-unit animation) so a request can't queue an absurdly long
-- animation sequence.
local MAX_OPEN_AMOUNT = 10

thread.Hook("BCORE:UnboxOpenCase", function(ply, data)
    if not IsValid(ply) or not data or not data.caseName then return end

    local pd = u:GetPlayer(ply)
    local owned = pd.cases[data.caseName] or 0
    if owned <= 0 then return end

    local amount = math.Clamp(math.floor(tonumber(data.amount) or 1), 1, MAX_OPEN_AMOUNT)
    amount = math.min(amount, owned)

    local results = {}
    for i = 1, amount do
        local item, rarity = u:OpenCase(data.caseName, ply)
        if not item then break end
        table.insert(results, { item = item, rarity = rarity })
        u:AnnounceUnbox(ply, item, rarity)
    end

    if #results > 0 then
        thread.Start(ply, "BCORE:UnboxOpenResult", {
            results  = results,
            caseName = data.caseName,
        })
        u:Sync(ply)
    end
end)