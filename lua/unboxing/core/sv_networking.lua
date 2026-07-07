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
                name      = v.name,
                class     = v.class,
                type      = v.type,
                rarity    = v.rarity,
                basePrice = v.basePrice,
            }
        end
    end
    return out
end

local function sanitizeCaseDefs(cases)
    local out = {}
    for k, v in pairs(cases or {}) do
        out[k] = {
            Name      = v.Name,
            Rarity    = v.Rarity,
            Price     = v.Price,
            itemCount = v._itemCount or 0,
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

thread.Hook("BCORE:UnboxOpenCase", function(ply, data)
    if not IsValid(ply) or not data or not data.caseName then return end
    local pd = u:GetPlayer(ply)
    if not pd.cases[data.caseName] or pd.cases[data.caseName] <= 0 then return end
    local item, rarity = u:OpenCase(data.caseName, ply)
    if item then
        thread.Start(ply, "BCORE:UnboxOpenResult", {
            item     = item,
            rarity   = rarity,
            caseName = data.caseName,
        })
        u:Sync(ply)
    end
end)