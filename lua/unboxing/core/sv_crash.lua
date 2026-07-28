-- Crash: one continuous shared round (not a per-player lobby) - a multiplier climbs from 1.00x
-- once betting closes; anyone in can cash out any time before it crashes; anyone still in when
-- it crashes loses their wager. The crash point is rolled BEFORE betting even closes and is
-- never influenced by cash-out timing (server-authoritative, resolved up front, not reacted to).
local u = BCORE.Unbox
local thread = BCORE.netstream

u.CrashRound = u.CrashRound or { state = "betting", bets = {}, crashPoint = 0, startTime = 0, endsAt = 0 }

-- House edge is baked directly into the crash-point DISTRIBUTION (the standard way a real crash
-- game applies its edge - a lower average crash point, not a second cut taken at cashout time),
-- so cashing out never applies u:ApplyHouseEdge a second time on top of this.
local function RollCrashPoint()
    local houseEdge = (u.GamblingHouseEdgePercent or 5) / 100
    local r = math.random()
    if r >= 0.999 then r = 0.999 end -- avoid a division by ~0 producing an absurd point
    local point = (1 - houseEdge) / (1 - r)
    return math.Clamp(math.floor(point * 100) / 100, 1.00, 1000)
end

local function CurrentMultiplier(round)
    if round.state ~= "running" then return 1.00 end
    local elapsed = CurTime() - round.startTime
    return math.floor((1.00 * (1.06 ^ elapsed)) * 100) / 100
end

local function BroadcastCrash()
    local round = u.CrashRound
    local bettors = {}
    for _, bet in pairs(round.bets) do
        if IsValid(bet.ply) then
            bettors[#bettors + 1] = { name = bet.ply:Nick(), wager = bet.wager, cashedOutAt = bet.cashedOutAt }
        end
    end
    thread.Start(nil, "BCORE:UnboxCrashState", {
        state = round.state,
        multiplier = CurrentMultiplier(round),
        endsAt = round.endsAt,
        bettors = bettors,
    })
end

local StartBettingPhase

local function StartRunningPhase()
    local round = u.CrashRound
    round.state = "running"
    round.startTime = CurTime()
    round.crashPoint = RollCrashPoint()
    BroadcastCrash()

    timer.Create("BCORE.Unbox.CrashTick", 0.1, 0, function()
        local r = u.CrashRound
        if r.state ~= "running" then return end
        if CurrentMultiplier(r) >= r.crashPoint then
            r.state = "crashed"
            timer.Remove("BCORE.Unbox.CrashTick")

            local participants = {}
            for _, bet in pairs(r.bets) do participants[#participants + 1] = bet.ply end
            u:LogGambleRound("crash", participants, string.format("crashPoint=%.2f", r.crashPoint))

            thread.Start(nil, "BCORE:UnboxCrashCrashed", { crashPoint = r.crashPoint })
            BroadcastCrash()
            timer.Simple(3, StartBettingPhase)
        else
            BroadcastCrash()
        end
    end)
end

StartBettingPhase = function()
    local round = u.CrashRound
    round.state = "betting"
    round.bets = {}
    round.crashPoint = 0
    round.endsAt = CurTime() + (u.CrashBettingSeconds or 12)
    BroadcastCrash()
    timer.Create("BCORE.Unbox.CrashBetting", u.CrashBettingSeconds or 12, 1, StartRunningPhase)
end

-- Only actually starts the loop once, the first time this file loads on a fresh server boot -
-- a Lua refresh (re-including this file) would otherwise restart the whole cycle and orphan the
-- old timers, so guard on the round never having been started at all.
if not u.CrashRound.started then
    u.CrashRound.started = true
    StartBettingPhase()
end

thread.Hook("BCORE:UnboxCrashBet", function(ply, data)
    if not u:GamblingIsEnabled(ply, u.EnableCrash, "Crash") then return end
    local round = u.CrashRound
    if round.state ~= "betting" then
        ply:ChatPrint("[Unbox] Betting is closed for this round - wait for the next one.")
        return
    end

    local id = ply:SteamID64()
    if round.bets[id] then
        ply:ChatPrint("[Unbox] You've already got a bet in this round.")
        return
    end

    local wager = tonumber((data or {}).wager) or 0
    local ok, err = u:ChargeWager(ply, wager)
    if not ok then
        ply:ChatPrint("[Unbox] " .. err)
        return
    end

    round.bets[id] = { ply = ply, wager = wager, cashedOutAt = nil }
    BroadcastCrash()
end)

thread.Hook("BCORE:UnboxCrashCashOut", function(ply)
    local round = u.CrashRound
    local bet = round.bets[ply:SteamID64()]
    if not bet or bet.cashedOutAt or round.state ~= "running" then return end

    local mult = CurrentMultiplier(round)
    bet.cashedOutAt = mult
    local payout = math.floor(bet.wager * mult)
    u:PayWager(ply, payout)
    thread.Start(ply, "BCORE:UnboxCrashCashedOut", { multiplier = mult, payout = payout })
    BroadcastCrash()
end)

thread.Hook("BCORE:UnboxCrashRequestState", function(ply)
    BroadcastCrash()
end)

-- No PlayerDisconnected handling needed here (unlike Coinflip/Case Battles' own lobby cleanup):
-- a disconnected player's bet simply stays in round.bets, still counted, still eligible to lose
-- to a crash - they just can't send a cash-out request anymore. Consistent with a real crash
-- game: leaving mid-round doesn't get your wager back.
