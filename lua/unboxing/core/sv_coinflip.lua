-- Coinflip: real player-vs-player wagering, not vs-house. One player creates a lobby with a
-- cash wager (charged immediately, held server-side in the lobby itself - not returned unless
-- the lobby is cancelled before anyone joins); any other player can join it, which resolves the
-- flip immediately: a single weighted (50/50) math.random call, winner takes both wagers minus
-- house edge, both players charged/paid via the shared u:ChargeWager/u:PayWager.
local u = BCORE.Unbox
local thread = BCORE.netstream

u.CoinflipLobbies = u.CoinflipLobbies or {}
local nextLobbyId = 1

local function BroadcastLobbies()
    local list = {}
    for id, lobby in pairs(u.CoinflipLobbies) do
        if IsValid(lobby.creator) then
            list[#list + 1] = { id = id, creatorName = lobby.creator:Nick(), wager = lobby.wager }
        end
    end
    thread.Start(nil, "BCORE:UnboxCoinflipLobbies", { lobbies = list })
end

thread.Hook("BCORE:UnboxCoinflipCreate", function(ply, data)
    if not u:GamblingIsEnabled(ply, u.EnableCoinflip, "Coinflip") then return end
    local wager = tonumber((data or {}).wager) or 0

    local ok, err = u:ChargeWager(ply, wager)
    if not ok then
        ply:ChatPrint("[Unbox] " .. err)
        return
    end

    local id = nextLobbyId
    nextLobbyId = nextLobbyId + 1
    u.CoinflipLobbies[id] = { creator = ply, wager = wager }
    BroadcastLobbies()
end)

thread.Hook("BCORE:UnboxCoinflipCancel", function(ply, data)
    local id = (data or {}).id
    local lobby = id and u.CoinflipLobbies[id]
    if not lobby or lobby.creator ~= ply then return end

    u:PayWager(ply, lobby.wager) -- refund - nobody joined yet
    u.CoinflipLobbies[id] = nil
    BroadcastLobbies()
end)

thread.Hook("BCORE:UnboxCoinflipJoin", function(ply, data)
    if not u:GamblingIsEnabled(ply, u.EnableCoinflip, "Coinflip") then return end
    local id = (data or {}).id
    local lobby = id and u.CoinflipLobbies[id]
    if not lobby or not IsValid(lobby.creator) then
        ply:ChatPrint("[Unbox] That lobby no longer exists.")
        return
    end
    if lobby.creator == ply then
        ply:ChatPrint("[Unbox] You can't join your own lobby.")
        return
    end

    local ok, err = u:ChargeWager(ply, lobby.wager)
    if not ok then
        ply:ChatPrint("[Unbox] " .. err)
        return
    end

    u.CoinflipLobbies[id] = nil
    BroadcastLobbies()

    local creator = lobby.creator
    local heads = math.random() < 0.5
    local winner = heads and creator or ply
    local loser = heads and ply or creator
    local pot = lobby.wager + lobby.wager
    local payout = u:ApplyHouseEdge(pot)

    u:PayWager(winner, payout)
    u:LogGambleRound("coinflip", { creator, ply }, string.format("wager=%d winner=%s payout=%d", lobby.wager, winner:Nick(), payout))

    local result = { heads = heads, wager = lobby.wager, payout = payout, winnerName = winner:Nick(), loserName = loser:Nick() }
    thread.Start(creator, "BCORE:UnboxCoinflipResult", result)
    thread.Start(ply, "BCORE:UnboxCoinflipResult", result)
end)

-- A player who disconnects with an open lobby can't be paid back (addMoney on an invalid/gone
-- player does nothing - there's no real way to refund a wager to someone no longer connected).
-- Removing the stale lobby at least stops it from lingering in the list forever, offered to
-- other players, for a creator who's already gone.
hook.Add("PlayerDisconnected", "BCORE.Unbox.CoinflipCleanupOnDisconnect", function(ply)
    for id, lobby in pairs(u.CoinflipLobbies) do
        if lobby.creator == ply then
            u.CoinflipLobbies[id] = nil
        end
    end
end)

thread.Hook("BCORE:UnboxCoinflipRequestLobbies", function(ply)
    BroadcastLobbies()
end)
