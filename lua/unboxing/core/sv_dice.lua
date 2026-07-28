-- Dice/Roulette: pick a "roll under" threshold (1-99), wager cash, server rolls 1-100. Win if
-- the roll is <= the threshold. Payout scales inversely with win chance so every threshold has
-- the same expected value (before house edge) - the standard, simplest gambling format.
local u = BCORE.Unbox
local thread = BCORE.netstream

thread.Hook("BCORE:UnboxDicePlay", function(ply, data)
    if not u:GamblingIsEnabled(ply, u.EnableDice, "Dice") then return end
    data = data or {}

    local threshold = math.Clamp(math.floor(tonumber(data.threshold) or 50), 1, 99)
    local wager = tonumber(data.wager) or 0

    local ok, err = u:ChargeWager(ply, wager)
    if not ok then
        ply:ChatPrint("[Unbox] " .. err)
        return
    end

    local roll = math.random(1, 100)
    local won = roll <= threshold

    local payout = 0
    if won then
        payout = u:ApplyHouseEdge(math.floor(wager * (100 / threshold)))
        u:PayWager(ply, payout)
    end

    u:LogGambleRound("dice", { ply }, string.format("threshold=%d roll=%d wager=%d payout=%d", threshold, roll, wager, payout))

    thread.Start(ply, "BCORE:UnboxDiceResult", {
        threshold = threshold, roll = roll, won = won, wager = wager, payout = payout,
    })
end)
