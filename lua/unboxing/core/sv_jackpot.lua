-- Jackpot: a timed round window where any number of players contribute cash to a shared pot; at
-- round-end, one contributor is picked with probability proportional to their share of the pot
-- (u:RollFromPool, the same weighted-pick every case-opening/trade-up/case-battle path uses).
local u = BCORE.Unbox
local thread = BCORE.netstream

u.JackpotRound = u.JackpotRound or { entries = {}, endsAt = 0, active = false }

local function BroadcastJackpot()
    local entries = {}
    for _, e in ipairs(u.JackpotRound.entries) do
        if IsValid(e.ply) then entries[#entries + 1] = { name = e.ply:Nick(), amount = e.amount } end
    end
    thread.Start(nil, "BCORE:UnboxJackpotState", {
        entries = entries,
        endsAt = u.JackpotRound.endsAt,
        active = u.JackpotRound.active,
    })
end

local function ResolveJackpot()
    local round = u.JackpotRound
    round.active = false

    local pool, total = {}, 0
    for i, e in ipairs(round.entries) do
        if IsValid(e.ply) then
            table.insert(pool, { key = i, w = e.amount })
            total = total + e.amount
        end
    end

    if #pool == 0 then
        round.entries = {}
        BroadcastJackpot()
        return
    end

    local winnerIndex = u:RollFromPool(pool, total)
    local winnerEntry = round.entries[winnerIndex]
    local payout = u:ApplyHouseEdge(total)

    if IsValid(winnerEntry.ply) then
        u:PayWager(winnerEntry.ply, payout)
    end

    local participants = {}
    for _, e in ipairs(round.entries) do participants[#participants + 1] = e.ply end
    u:LogGambleRound("jackpot", participants, string.format("pot=%d winner=%s payout=%d", total,
        IsValid(winnerEntry.ply) and winnerEntry.ply:Nick() or "?", payout))

    thread.Start(nil, "BCORE:UnboxJackpotResult", {
        winnerName = IsValid(winnerEntry.ply) and winnerEntry.ply:Nick() or "Unknown",
        pot = total,
        payout = payout,
    })

    round.entries = {}
    BroadcastJackpot()
end

thread.Hook("BCORE:UnboxJackpotJoin", function(ply, data)
    if not u:GamblingIsEnabled(ply, u.EnableJackpot, "Jackpot") then return end
    local amount = tonumber((data or {}).amount) or 0

    local ok, err = u:ChargeWager(ply, amount)
    if not ok then
        ply:ChatPrint("[Unbox] " .. err)
        return
    end

    local round = u.JackpotRound
    table.insert(round.entries, { ply = ply, amount = amount })

    if not round.active then
        round.active = true
        round.endsAt = CurTime() + (u.JackpotRoundSeconds or 45)
        timer.Create("BCORE.Unbox.JackpotRound", u.JackpotRoundSeconds or 45, 1, ResolveJackpot)
    end

    BroadcastJackpot()
end)

thread.Hook("BCORE:UnboxJackpotRequestState", function(ply)
    BroadcastJackpot()
end)
