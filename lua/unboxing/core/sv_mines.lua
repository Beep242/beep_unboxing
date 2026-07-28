-- Mines: pick how many mines sit in a 5x5 grid, wager, then reveal tiles one at a time - each
-- safe reveal raises a fair multiplier, cash out any time, hit a mine and lose the wager. One
-- round is per-player server-side state (unlike Jackpot/Crash/Coinflip/Case Battles, this never
-- needs another player at all - closer to Dice in that sense, just with a live in-progress state
-- instead of resolving instantly).
local u = BCORE.Unbox
local thread = BCORE.netstream

local GRID_SIZE = 25
u.MinesRounds = u.MinesRounds or {}

-- The standard, fair "mines" payout formula: after `picks` successful reveals out of `mines`
-- total mines in a `GRID_SIZE`-tile grid, the fair multiplier is the product, for each pick, of
-- (tiles remaining) / (safe tiles remaining) at that point - i.e. the inverse of the actual
-- probability of having survived that many picks in a row. House edge is applied on top once, at
-- cash-out time (the same "apply once, at payout" convention every other game here uses).
local function FairMultiplier(mines, picks)
    local mult = 1
    for i = 0, picks - 1 do
        local tilesLeft = GRID_SIZE - i
        local safeLeft = (GRID_SIZE - mines) - i
        if safeLeft <= 0 then return mult end
        mult = mult * (tilesLeft / safeLeft)
    end
    return mult
end

thread.Hook("BCORE:UnboxMinesStart", function(ply, data)
    if not u:GamblingIsEnabled(ply, u.EnableMines, "Mines") then return end
    data = data or {}

    local id = ply:SteamID64()
    if u.MinesRounds[id] then
        ply:ChatPrint("[Unbox] You already have a Mines round in progress.")
        return
    end

    local mineCount = math.Clamp(math.floor(tonumber(data.mineCount) or 3), 1, GRID_SIZE - 1)
    local wager = tonumber(data.wager) or 0

    local ok, err = u:ChargeWager(ply, wager)
    if not ok then
        ply:ChatPrint("[Unbox] " .. err)
        return
    end

    -- Shuffle a flat list of tile indices, first `mineCount` are mines.
    local tiles = {}
    for i = 1, GRID_SIZE do tiles[i] = i end
    for i = GRID_SIZE, 2, -1 do
        local j = math.random(i)
        tiles[i], tiles[j] = tiles[j], tiles[i]
    end
    local mineSet = {}
    for i = 1, mineCount do mineSet[tiles[i]] = true end

    u.MinesRounds[id] = { mines = mineSet, mineCount = mineCount, wager = wager, revealed = 0, revealedTiles = {} }
    thread.Start(ply, "BCORE:UnboxMinesStarted", { mineCount = mineCount, wager = wager })
end)

thread.Hook("BCORE:UnboxMinesReveal", function(ply, data)
    local id = ply:SteamID64()
    local round = u.MinesRounds[id]
    if not round then return end

    local tile = math.floor(tonumber((data or {}).tile) or 0)
    if tile < 1 or tile > GRID_SIZE or round.revealedTiles[tile] then return end

    round.revealedTiles[tile] = true

    if round.mines[tile] then
        u.MinesRounds[id] = nil
        local allMines = {}
        for k in pairs(round.mines) do allMines[#allMines + 1] = k end
        u:LogGambleRound("mines", { ply }, string.format("mines=%d wager=%d result=hit tile=%d", round.mineCount, round.wager, tile))
        thread.Start(ply, "BCORE:UnboxMinesResult", { won = false, tile = tile, allMines = allMines })
        return
    end

    round.revealed = round.revealed + 1
    local multiplier = FairMultiplier(round.mineCount, round.revealed)
    thread.Start(ply, "BCORE:UnboxMinesRevealResult", { tile = tile, multiplier = multiplier, revealed = round.revealed })
end)

thread.Hook("BCORE:UnboxMinesCashout", function(ply)
    local id = ply:SteamID64()
    local round = u.MinesRounds[id]
    if not round or round.revealed <= 0 then return end

    local multiplier = FairMultiplier(round.mineCount, round.revealed)
    local payout = u:ApplyHouseEdge(math.floor(round.wager * multiplier))
    u:PayWager(ply, payout)
    u.MinesRounds[id] = nil

    u:LogGambleRound("mines", { ply }, string.format("mines=%d wager=%d revealed=%d payout=%d", round.mineCount, round.wager, round.revealed, payout))
    thread.Start(ply, "BCORE:UnboxMinesCashedOut", { payout = payout, multiplier = multiplier })
end)

hook.Add("PlayerDisconnected", "BCORE.Unbox.MinesCleanupOnDisconnect", function(ply)
    -- Same reasoning as Crash's own bettors: an in-progress round's wager was already charged
    -- up front and simply can't be refunded to someone no longer connected. Clearing the round
    -- state just stops it from lingering forever, tying up nothing real.
    u.MinesRounds[ply:SteamID64()] = nil
end)
