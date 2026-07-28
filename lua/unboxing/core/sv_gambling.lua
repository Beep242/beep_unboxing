-- Shared gambling plumbing every minigame (sv_coinflip/sv_dice/sv_jackpot/sv_casebattles/
-- sv_crash) calls into - the "check balance, deduct up front, pay out after resolution"
-- discipline u:PurchaseItem/u:PurchaseCase (sv_economy.lua) already establish, centralized once
-- rather than reimplemented five times. All config-driven (mainconfig/sh_config.lua) - house
-- edge, min/max bet, and each game's own enable toggle - nothing here is hardcoded.

local u = BCORE.Unbox
local thread = BCORE.netstream

u.GamblingLogs = u.GamblingLogs or {}

-- Every result is server-rolled before any client input is read (see each game's own file),
-- and every round appends here for after-the-fact auditability - not a full cryptographic
-- provably-fair scheme (out of scope for a private server), but a real, honest log.
function u:LogGambleRound(kind, playersInvolved, result)
    local names = {}
    for _, ply in ipairs(playersInvolved or {}) do
        if IsValid(ply) then names[#names + 1] = ply:Nick() end
    end
    table.insert(u.GamblingLogs, 1, {
        kind = kind,
        players = names,
        result = tostring(result),
        time = os.time(),
    })
    if #u.GamblingLogs > 200 then table.remove(u.GamblingLogs) end
end

-- Validates a wager amount against the shared min/max config and the player's own balance, then
-- deducts it immediately. Returns true on success (money already deducted), or false plus a
-- player-facing reason string. Does NOT check GamblingEnabled/per-game toggles - callers check
-- their own game's toggle first, since the reason message should name that specific game.
function u:ChargeWager(ply, amount)
    if not IsValid(ply) then return false, "Invalid player" end
    amount = math.floor(tonumber(amount) or 0)

    if amount < (u.GamblingMinBet or 0) then
        return false, "Minimum bet is " .. u:FormatMoneyServer(u.GamblingMinBet or 0)
    end
    if u.GamblingMaxBet and u.GamblingMaxBet > 0 and amount > u.GamblingMaxBet then
        return false, "Maximum bet is " .. u:FormatMoneyServer(u.GamblingMaxBet)
    end

    if not ply.getDarkRPVar or not ply.addMoney then
        return false, "Money system unavailable"
    end
    if ply:getDarkRPVar("money") < amount then
        return false, "You can't afford that bet"
    end

    ply:addMoney(-amount)
    return true
end

function u:PayWager(ply, amount)
    if not IsValid(ply) or not ply.addMoney then return end
    if amount and amount > 0 then ply:addMoney(math.floor(amount)) end
end

-- Applies the shared house edge to a raw payout amount.
function u:ApplyHouseEdge(amount)
    local edge = (u.GamblingHouseEdgePercent or 0) / 100
    return math.floor(amount * (1 - edge))
end

-- Server has no BUi/string.Comma dependency concern (string.Comma is a real engine global, not
-- a client-only one) - this is just a same-shaped helper so gambling files never have to guess
-- whether they're allowed to call the client-side BCORE.Unbox:FormatMoney.
function u:FormatMoneyServer(amount)
    return "$" .. string.Comma(math.floor(tonumber(amount) or 0))
end

-- Whole-system kill switch, checked by every game's own netstream hook before doing anything
-- else - mirrors beep-inventory's own EnableUpgrading/EnableModifiers gate pattern.
function u:GamblingIsEnabled(ply, gameEnabledFlag, gameName)
    if u.GamblingEnabled == false then
        if IsValid(ply) then ply:ChatPrint("[Unbox] Gambling is currently disabled.") end
        return false
    end
    if gameEnabledFlag == false then
        if IsValid(ply) then ply:ChatPrint("[Unbox] " .. gameName .. " is currently disabled.") end
        return false
    end
    return true
end
