-- Trade-In: scrap owned items for cash, or trade up a batch of same-rarity items for one item
-- of the next rarity tier. New feature - there was no sell-back/trade-up path anywhere in this
-- addon before (u:RemoveItem existed but nothing called it in exchange for anything).

local u = BCORE.Unbox
local thread = BCORE.netstream

local function TradeInIsEnabled(ply)
    if u.TradeInEnabled == false then
        if IsValid(ply) then ply:ChatPrint("[Unbox] Trade-In is currently disabled.") end
        return false
    end
    return true
end

-- Resolves the rarity immediately above `rarity` in the canonical progression
-- (BCORE.Unbox.RarityOrder, mainconfig/sh_config.lua - derived from the registered
-- RarityWeights order, not a second hardcoded list). Returns nil if `rarity` is already the
-- highest tier or isn't recognized at all.
function u:NextRarity(rarity)
    local order = u.RarityOrder or { "common", "uncommon", "rare", "epic", "legendary" }
    rarity = string.lower(rarity or "")
    for i, r in ipairs(order) do
        if r == rarity then return order[i + 1] end
    end
    return nil
end

-- Scraps a list of owned item keys for cash. `counts` is a { [itemKey] = countToScrap } map (a
-- player can scrap more than one of the same item at once) so this never needs to be called
-- once per item.
function u:ScrapItems(ply, counts)
    if not IsValid(ply) or not TradeInIsEnabled(ply) then return end
    if not istable(counts) then return end

    local p = self:GetPlayer(ply)
    local scrapPct = (u.ScrapPercent or 40) / 100

    -- Validate ownership FIRST, entirely, before removing or paying out anything - a request
    -- for an item the player doesn't own (or doesn't own enough of) fails the whole batch
    -- rather than partially scrapping whatever it could.
    local payout = 0
    for key, count in pairs(counts) do
        count = math.floor(tonumber(count) or 0)
        if count <= 0 then continue end
        local owned = p.inventory[key] or 0
        if owned < count then
            if IsValid(ply) then ply:ChatPrint("[Unbox] You don't own that many of '" .. key .. "'.") end
            return
        end
        local item = u.Items[key]
        if not item then
            if IsValid(ply) then ply:ChatPrint("[Unbox] Unknown item.") end
            return
        end
        payout = payout + math.floor((item.basePrice or 0) * scrapPct) * count
    end

    if payout <= 0 then
        if IsValid(ply) then ply:ChatPrint("[Unbox] Nothing worth scrapping.") end
        return
    end

    for key, count in pairs(counts) do
        count = math.floor(tonumber(count) or 0)
        for i = 1, count do
            self:RemoveItem(key, ply)
        end
    end

    if ply.addMoney then ply:addMoney(payout) end
    self:Sync(ply)
    return true, payout
end

thread.Hook("BCORE:UnboxScrapItems", function(ply, data)
    local ok, payout = u:ScrapItems(ply, (data or {}).counts)
    if ok then
        thread.Start(ply, "BCORE:UnboxAdmin.Result", { ok = true, msg = "Scrapped for " .. u:FormatMoneyServer(payout) .. "!" })
    end
end)

-- Trades in TradeUpItemsRequired items, all the SAME rarity, for one item rolled from the pool
-- of items one rarity tier higher. `keys` is a list of item keys (each entry is one unit - if a
-- player wants to trade in 3 of the same item, that key appears 3 times).
function u:TradeUpItems(ply, keys)
    if not IsValid(ply) or not TradeInIsEnabled(ply) then return end
    if not istable(keys) or #keys == 0 then return end

    local required = u.TradeUpItemsRequired or 5
    if #keys ~= required then
        if IsValid(ply) then ply:ChatPrint("[Unbox] Trade-up needs exactly " .. required .. " items.") end
        return
    end

    local p = self:GetPlayer(ply)

    -- Count how many of each key were submitted, validate ownership, and confirm every item
    -- shares the same rarity.
    local counts, rarity = {}, nil
    for _, key in ipairs(keys) do
        counts[key] = (counts[key] or 0) + 1
        local item = u.Items[key]
        if not item then
            if IsValid(ply) then ply:ChatPrint("[Unbox] Unknown item.") end
            return
        end
        local itemRarity = string.lower(item.rarity or "common")
        if rarity and itemRarity ~= rarity then
            if IsValid(ply) then ply:ChatPrint("[Unbox] Every item in a trade-up must share the same rarity.") end
            return
        end
        rarity = itemRarity
    end

    for key, count in pairs(counts) do
        if (p.inventory[key] or 0) < count then
            if IsValid(ply) then ply:ChatPrint("[Unbox] You don't own that many of '" .. key .. "'.") end
            return
        end
    end

    local nextRarity = self:NextRarity(rarity)
    if not nextRarity then
        if IsValid(ply) then ply:ChatPrint("[Unbox] '" .. rarity .. "' is already the highest rarity.") end
        return
    end

    -- Build a weighted pool of every item at the next rarity tier and roll one (same
    -- RollFromPool every case-opening/case-battle path uses).
    local pool, total = {}, 0
    for key, item in pairs(u.Items) do
        if string.lower(item.rarity or "common") == nextRarity then
            table.insert(pool, { key = key, w = 10 })
            total = total + 10
        end
    end

    local result = self:RollFromPool(pool, total)
    if not result then
        if IsValid(ply) then ply:ChatPrint("[Unbox] No items exist at the next rarity tier yet - ask an admin to add some.") end
        return
    end

    for key, count in pairs(counts) do
        for i = 1, count do
            self:RemoveItem(key, ply)
        end
    end

    self:GiveItem(result, ply)
    self:Sync(ply)
    return true, result
end

thread.Hook("BCORE:UnboxTradeUpItems", function(ply, data)
    local ok, result = u:TradeUpItems(ply, (data or {}).keys)
    if ok then
        local resultItem = u.Items[result] or {}
        thread.Start(ply, "BCORE:UnboxAdmin.Result", { ok = true, msg = "Traded up into " .. (resultItem.name or result) .. "!" })
    end
end)
