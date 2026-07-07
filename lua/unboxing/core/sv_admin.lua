BCORE.Unbox.Admin = BCORE.Unbox.Admin or {}

local UA     = BCORE.Unbox.Admin
local u      = BCORE.Unbox
local thread = BCORE.netstream

UA.Logs = UA.Logs or {}

local function cleanItems()
    u.Items = u.Items or {}

    for k, v in pairs(u.Items) do
        if istable(v) then
            u.Items[k] = {
                name        = tostring(v.name or v.PrintName or k),
                class       = tostring(v.class or k),
                type        = tostring(v.type or "Weapon"),
                rarity      = tostring(v.rarity or "common"),
                basePrice   = tonumber(v.basePrice or 100),
                soldInStore = v.soldInStore,  -- nil=shown, false=hidden, true=shown
        model       = v.model,
                model       = v.model or (function()
                    local sw = weapons.GetStored(v.class or k)
                    return sw and (sw.WorldModel or sw.ViewModel) or nil
                end)(),
            }
        else
            u.Items[k] = nil
        end
    end
end

function UA:IsAdmin(ply)
    if not IsValid(ply) then return false end

    if ply:IsSuperAdmin() then
        return true
    end

    for _, group in ipairs((BCORE.Inventory and BCORE.Inventory.config and BCORE.Inventory.config.Admins) or {}) do
        if ply:IsUserGroup(group) then
            return true
        end
    end

    return false
end

function UA:Log(ply, action, detail)
    table.insert(self.Logs, {
        time   = os.time(),
        admin  = IsValid(ply) and ply:Nick() or "?",
        action = action,
        detail = detail or ""
    })

    while #self.Logs > 200 do
        table.remove(self.Logs, 1)
    end

    print(string.format(
        "[UnboxAdmin] %s → %s (%s)",
        IsValid(ply) and ply:Nick() or "?",
        action,
        detail or ""
    ))
end

local function sanitizeItem(v)
    return {
        name        = v.name,
        class       = v.class,
        type        = v.type,
        rarity      = v.rarity,
        basePrice   = v.basePrice,
        soldInStore = v.soldInStore,  -- nil=shown, false=hidden, true=shown
        model       = v.model,
    }
end

local function sanitizeItems(items)
    local out = {}

    for k, v in pairs(items or {}) do
        if istable(v) then
            out[k] = sanitizeItem(v)
        end
    end

    return out
end

local function sanitizeCases(cases)
    local out = {}

    for k, v in pairs(cases or {}) do
        local keys = {}

        if v._byRarity then
            for _, pool in pairs(v._byRarity) do
                for _, ik in ipairs(pool) do
                    table.insert(keys, ik)
                end
            end
        end

        out[k] = {
            Name     = v.Name,
            Rarity   = v.Rarity,
            Price    = v.Price,
            itemKeys = keys,
            weights  = v.weights or {},
        }
    end

    return out
end

local DATA_DIR   = "bcore_unbox"
local CASES_FILE = DATA_DIR .. "/cases.json"
local ITEMS_FILE = DATA_DIR .. "/items.json"

local function ensureDir()
    if not file.IsDir(DATA_DIR, "DATA") then
        file.CreateDir(DATA_DIR)
    end
end

function UA:SaveCasesToDisk()
    ensureDir()
    file.Write(CASES_FILE, util.TableToJSON(sanitizeCases(u.Cases), true))
end

function UA:SaveItemsToDisk()
    ensureDir()
    file.Write(ITEMS_FILE, util.TableToJSON(sanitizeItems(u.Items), true))
end

function UA:LoadFromDisk()
    ensureDir()

    if file.Exists(ITEMS_FILE, "DATA") then
        local raw = util.JSONToTable(file.Read(ITEMS_FILE, "DATA") or "{}") or {}

        for k, v in pairs(raw) do
            u:CreateItem(k, v)
        end

        print("[UnboxAdmin] Loaded " .. table.Count(raw) .. " items from disk.")
    end

    if file.Exists(CASES_FILE, "DATA") then
        local raw = util.JSONToTable(file.Read(CASES_FILE, "DATA") or "{}") or {}

        for k, v in pairs(raw) do
            local caseItems = {}

            local itemsByRarity = {}
            local diskWeights   = v.weights or {}
            local loadedWeights = {}
            for _, ik in ipairs(v.itemKeys or {}) do
                if u.Items[ik] then
                    caseItems[ik]    = u.Items[ik]
                    loadedWeights[ik] = tonumber(diskWeights[ik]) or 10
                    local r = string.lower(u.Items[ik].rarity or "common")
                    if not itemsByRarity[r] then itemsByRarity[r] = {} end
                    table.insert(itemsByRarity[r], ik)
                end
            end

            u:CreateCase(k, {
                Name      = v.Name,
                Rarity    = v.Rarity,
                Price     = v.Price,
                CaseItems = caseItems,
                weights   = loadedWeights,
                items     = itemsByRarity,
                _byRarity = itemsByRarity,
            })
        end

        print("[UnboxAdmin] Loaded " .. table.Count(raw) .. " cases from disk.")
    end

    -- NOTE: cleanItems() is NOT called here anymore.
    -- It runs via timer.Simple(0) in the InitPostEntity hook below,
    -- after ALL other InitPostEntity hooks (including u:ImportWeapons) have fired.
end

hook.Add("InitPostEntity", "BCORE.UnboxAdmin.Load", function()
    UA:LoadFromDisk()
    -- Defer cleanItems so it runs after BCORE_Unbox_ImportWeapons has added
    -- all weapon items.  Without this, cleanItems saw an empty u.Items table
    -- and the weapons added by ImportWeapons were left with soldInStore=nil.
    timer.Simple(0, function()
        local before = table.Count(u.Items)
        cleanItems()
        local after = table.Count(u.Items)
        -- Sample one item so we can verify basePrice is set
        local sample_key, sample_bp = "?", "?"
        for k, v in pairs(u.Items) do
            sample_key = k
            sample_bp  = tostring(v and v.basePrice)
            break
        end
        print(string.format("[UnboxAdmin] cleanItems() done — %d items, sample: %s.basePrice=%s",
            after, sample_key, sample_bp))
        -- Re-sync every connected player now that items are normalised
        for _, p in ipairs(player.GetAll()) do
            if u.Sync then u:Sync(p) end
        end
    end)
end)

function UA:BuildAdminData()
    return {
        cases = sanitizeCases(u.Cases),
        items = sanitizeItems(u.Items),
        logs  = self.Logs
    }
end

function UA:SyncAdmin(ply)
    if not IsValid(ply) then return end
    thread.Start(ply, "BCORE:UnboxAdmin.SendData", self:BuildAdminData())
end

local function respond(ply, ok, msg)
    thread.Start(ply, "BCORE:UnboxAdmin.Result", { ok = ok, msg = msg })
end

local function syncAll()
    for _, p in ipairs(player.GetAll()) do
        if UA:IsAdmin(p) then UA:SyncAdmin(p) end
        if u.Sync then u:Sync(p) end
    end
end

thread.Hook("BCORE:UnboxAdmin.RequestData", function(ply)
    if not UA:IsAdmin(ply) then return end
    UA:SyncAdmin(ply)
end)

thread.Hook("BCORE:UnboxAdmin.SaveCase", function(ply, data)
    if not UA:IsAdmin(ply) then return end

    if not data or data.key == "" then
        respond(ply, false, "Key is required")
        return
    end

    if data.oldKey and data.oldKey ~= "" and data.oldKey ~= data.key then
        u.Cases[data.oldKey] = nil
    end

    local caseItems    = {}
    local caseWeights  = {}
    local inWeights    = data.weights or {}

    for _, ik in ipairs(data.itemKeys or {}) do
        if u.Items[ik] then
            caseItems[ik]   = u.Items[ik]
            caseWeights[ik] = tonumber(inWeights[ik]) or 10
        end
    end

    local itemsByRarity = {}
    for ik, idata in pairs(caseItems) do
        local r = string.lower(idata.rarity or "common")
        if not itemsByRarity[r] then itemsByRarity[r] = {} end
        table.insert(itemsByRarity[r], ik)
    end

    u:CreateCase(data.key, {
        Name      = data.Name or data.key,
        Rarity    = data.Rarity or "Common",
        Price     = data.Price or 50000,
        CaseItems = caseItems,
        weights   = caseWeights,
        items     = itemsByRarity,
        _byRarity = itemsByRarity,
    })

    UA:Log(ply, "SaveCase", data.key .. " (" .. table.Count(caseItems) .. " items)")
    UA:SaveCasesToDisk()
    syncAll()
    respond(ply, true, "Case saved.")
end)

thread.Hook("BCORE:UnboxAdmin.DeleteCase", function(ply, data)
    if not UA:IsAdmin(ply) then return end

    if not data or not data.key or not u.Cases[data.key] then
        respond(ply, false, "Case not found")
        return
    end

    local name = u.Cases[data.key].Name or data.key
    u.Cases[data.key] = nil

    UA:Log(ply, "DeleteCase", data.key)
    UA:SaveCasesToDisk()
    syncAll()
    respond(ply, true, "Case \"" .. name .. "\" deleted.")
end)

thread.Hook("BCORE:UnboxAdmin.SaveItem", function(ply, data)
    if not UA:IsAdmin(ply) then return end

    if not data or data.key == "" then
        respond(ply, false, "Key is required")
        return
    end

    if data.oldKey and data.oldKey ~= "" and data.oldKey ~= data.key then
        u.Items[data.oldKey] = nil

        for _, case in pairs(u.Cases) do
            if case._byRarity then
                for _, pool in pairs(case._byRarity) do
                    for i, ik in ipairs(pool) do
                        if ik == data.oldKey then pool[i] = data.key end
                    end
                end
            end

            if case.CaseItems and case.CaseItems[data.oldKey] then
                case.CaseItems[data.key]     = case.CaseItems[data.oldKey]
                case.CaseItems[data.oldKey]  = nil
            end
        end
    end

    u:CreateItem(data.key, {
        name        = data.name or data.key,
        class       = data.class ~= "" and data.class or nil,
        type        = data.type  ~= "" and data.type  or "Weapon",
        rarity      = data.rarity    or "common",
        basePrice   = data.basePrice or 100,
        soldInStore = data.soldInStore or false,    -- FIX: persist the value the client sent
    })

    UA:Log(ply, "SaveItem", data.key)
    UA:SaveItemsToDisk()
    UA:SaveCasesToDisk()
    syncAll()
    respond(ply, true, "Item saved.")
end)

thread.Hook("BCORE:UnboxAdmin.DeleteItem", function(ply, data)
    if not UA:IsAdmin(ply) then return end

    if not data or not data.key or not u.Items[data.key] then
        respond(ply, false, "Item not found")
        return
    end

    local name = u.Items[data.key].name or data.key
    u.Items[data.key] = nil

    for _, case in pairs(u.Cases) do
        if case.CaseItems then case.CaseItems[data.key] = nil end

        if case._byRarity then
            for _, pool in pairs(case._byRarity) do
                table.RemoveByValue(pool, data.key)
            end
        end
    end

    UA:Log(ply, "DeleteItem", data.key)
    UA:SaveItemsToDisk()
    UA:SaveCasesToDisk()
    syncAll()
    respond(ply, true, "Item \"" .. name .. "\" deleted.")
end)

thread.Hook("BCORE:UnboxAdmin.ImportWeapons", function(ply)
    if not UA:IsAdmin(ply) then return end

    local imported = 0

    for _, swep in ipairs(weapons.GetList()) do
        local class = swep.ClassName or swep.class

        if class and class ~= "" then
            local sw2 = weapons.GetStored(class)
            u:CreateItem(class, {
                name        = swep.PrintName and swep.PrintName ~= "" and swep.PrintName or class,
                class       = class,
                type        = "Weapon",
                rarity      = "common",
                basePrice   = 100,
                soldInStore = false,
                model       = sw2 and (sw2.WorldModel or sw2.ViewModel) or nil,
            })

            imported = imported + 1
        end
    end

    cleanItems()
    UA:Log(ply, "ImportWeapons", imported .. " items total")
    UA:SaveItemsToDisk()
    UA:SaveCasesToDisk()
    syncAll()
    respond(ply, true, "Imported " .. imported .. " items.")
end)

-- Batch-enable all items that have a basePrice set (for shop display)
thread.Hook("BCORE:UnboxAdmin.ListAllInStore", function(ply)
    if not UA:IsAdmin(ply) then return end
    local count = 0
    for k, v in pairs(u.Items) do
        if istable(v) and v.basePrice then
            v.soldInStore = true
            count = count + 1
        end
    end
    UA:Log(ply, "ListAllInStore", count .. " items enabled")
    UA:SaveItemsToDisk()
    syncAll()
    respond(ply, true, count .. " items listed in store.")
end)

-- Admin: wipe a player's entire inventory
thread.Hook("BCORE:UnboxAdmin.WipePlayerInv", function(ply, data)
    if not UA:IsAdmin(ply) then return end
    local target
    for _, p in ipairs(player.GetAll()) do
        if p:UserID() == data.userID then target = p; break end
    end
    if not IsValid(target) then respond(ply, false, "Player not found"); return end
    local p = u:GetPlayer(target)
    p.inventory = {}
    p.cases     = {}
    u:SavePlayer(target); u:Sync(target)
    UA:Log(ply, "WipePlayerInv", target:Nick())
    thread.Start(ply, "BCORE:UnboxAdmin.PlayerInvData", {
        userID=data.userID, name=target:Nick(), steamid=target:SteamID64(),
        inventory={}, cases={},
    })
end)

-- Admin: remove an item from a player's inventory
thread.Hook("BCORE:UnboxAdmin.RemovePlayerItem", function(ply, data)
    if not UA:IsAdmin(ply) then return end
    local target
    for _, p in ipairs(player.GetAll()) do
        if p:UserID() == data.userID then target = p; break end
    end
    if not IsValid(target) then respond(ply, false, "Player not found"); return end
    local p = u:GetPlayer(target)
    if not p.inventory or not p.inventory[data.itemKey] then
        respond(ply, false, "Item not found"); return
    end
    p.inventory[data.itemKey] = (p.inventory[data.itemKey] or 0) - (data.amount or 1)
    if p.inventory[data.itemKey] <= 0 then p.inventory[data.itemKey] = nil end
    u:SavePlayer(target); u:Sync(target)
    UA:Log(ply, "RemovePlayerItem", target:Nick().." - "..data.itemKey)
    local pd = u:GetPlayer(target)
    thread.Start(ply, "BCORE:UnboxAdmin.PlayerInvData", {
        userID=data.userID, name=target:Nick(), steamid=target:SteamID64(),
        inventory=pd.inventory or {}, cases=pd.cases or {},
    })
end)

-- Admin: remove a case from a player's inventory
thread.Hook("BCORE:UnboxAdmin.RemovePlayerCase", function(ply, data)
    if not UA:IsAdmin(ply) then return end
    local target
    for _, p in ipairs(player.GetAll()) do
        if p:UserID() == data.userID then target = p; break end
    end
    if not IsValid(target) then respond(ply, false, "Player not found"); return end
    local p = u:GetPlayer(target)
    if not p.cases or not p.cases[data.caseKey] then
        respond(ply, false, "Case not found"); return
    end
    p.cases[data.caseKey] = (p.cases[data.caseKey] or 0) - (data.amount or 1)
    if p.cases[data.caseKey] <= 0 then p.cases[data.caseKey] = nil end
    u:SavePlayer(target)
    UA:Log(ply, "RemovePlayerCase", target:Nick().." - "..data.caseKey)
    local pd = u:GetPlayer(target)
    thread.Start(ply, "BCORE:UnboxAdmin.PlayerInvData", {
        userID=data.userID, name=target:Nick(), steamid=target:SteamID64(),
        inventory=pd.inventory or {}, cases=pd.cases or {},
    })
end)

-- Admin: view any player's unbox inventory
thread.Hook("BCORE:UnboxAdmin.GetPlayerInv", function(ply, data)
    if not UA:IsAdmin(ply) then return end
    local target
    for _, p in ipairs(player.GetAll()) do
        if p:UserID() == data.userID then target = p; break end
    end
    if not IsValid(target) then
        respond(ply, false, "Player not found"); return
    end
    local p = u:GetPlayer(target)
    thread.Start(ply, "BCORE:UnboxAdmin.PlayerInvData", {
        userID    = data.userID,
        name      = target:Nick(),
        steamid   = target:SteamID64(),
        inventory = p.inventory or {},
        cases     = p.cases     or {},
    })
end)

hook.Add("PlayerSay", "BCORE.UnboxAdmin.ChatCmd", function(ply, text)
    if text == "!unboxadmin" and UA:IsAdmin(ply) then
        ply:ConCommand("open_unbox_admin")
        return ""
    end
end)