-- Case Battles: players pay a case's price (x however many cases the battle uses) as entry -
-- purchasing-and-opening atomically, no owned-case inventory item required. The server opens
-- that case for every participant via the same u:BuildCasePool/u:RollFromPool every normal case
-- open uses (so item-granting behavior is identical - no new escrow/transfer logic needed, every
-- participant keeps their own opened items). The highest-total participant additionally
-- receives the sum of every other participant's entry fee minus house edge - a cash side-pot on
-- top of everyone's own items.
local u = BCORE.Unbox
local thread = BCORE.netstream

u.CaseBattleLobbies = u.CaseBattleLobbies or {}
local nextBattleId = 1

local function BroadcastBattles()
    local list = {}
    for id, lobby in pairs(u.CaseBattleLobbies) do
        local names = {}
        for _, ply in ipairs(lobby.players) do
            if IsValid(ply) then names[#names + 1] = ply:Nick() end
        end
        list[#list + 1] = {
            id = id, caseName = lobby.caseName, caseCount = lobby.caseCount,
            maxPlayers = lobby.maxPlayers, players = names, entryFee = lobby.entryFee,
        }
    end
    thread.Start(nil, "BCORE:UnboxCaseBattleLobbies", { lobbies = list })
end

local function ItemValue(itemKey)
    local item = u.Items[itemKey]
    return item and (item.basePrice or 0) or 0
end

local function ResolveBattle(id)
    local lobby = u.CaseBattleLobbies[id]
    if not lobby then return end
    u.CaseBattleLobbies[id] = nil
    BroadcastBattles()

    local pool, total, caseItems = u:BuildCasePool(lobby.caseName)
    if not pool then
        -- Case became invalid mid-lobby (admin deleted it) - refund everyone rather than
        -- silently keep their entry fee for a battle that can never resolve.
        for _, ply in ipairs(lobby.players) do
            if IsValid(ply) then u:PayWager(ply, lobby.entryFee) end
        end
        return
    end

    local results = {}
    for _, ply in ipairs(lobby.players) do
        local totalValue = 0
        local won = {}
        for i = 1, lobby.caseCount do
            local chosen = u:RollFromPool(pool, total)
            if chosen then
                if IsValid(ply) then u:GiveItem(chosen, ply) end
                totalValue = totalValue + ItemValue(chosen)
                won[#won + 1] = chosen
            end
        end
        if IsValid(ply) then u:Sync(ply) end
        results[#results + 1] = { ply = ply, totalValue = totalValue, won = won }
    end

    table.sort(results, function(a, b) return a.totalValue > b.totalValue end)
    local winner = results[1]
    local sidePot = lobby.entryFee * (#lobby.players - 1)
    local payout = u:ApplyHouseEdge(sidePot)
    if winner and IsValid(winner.ply) and payout > 0 then
        u:PayWager(winner.ply, payout)
    end

    u:LogGambleRound("casebattle", lobby.players, string.format("case=%s players=%d winner=%s payout=%d",
        lobby.caseName, #lobby.players, (winner and IsValid(winner.ply)) and winner.ply:Nick() or "?", payout))

    local resultPayload = {
        caseName = lobby.caseName,
        winnerName = (winner and IsValid(winner.ply)) and winner.ply:Nick() or "Unknown",
        payout = payout,
        players = {},
    }
    for _, r in ipairs(results) do
        resultPayload.players[#resultPayload.players + 1] = {
            name = IsValid(r.ply) and r.ply:Nick() or "?",
            totalValue = r.totalValue,
            won = r.won,
        }
    end

    for _, ply in ipairs(lobby.players) do
        if IsValid(ply) then thread.Start(ply, "BCORE:UnboxCaseBattleResult", resultPayload) end
    end
end

thread.Hook("BCORE:UnboxCaseBattleCreate", function(ply, data)
    if not u:GamblingIsEnabled(ply, u.EnableCaseBattles, "Case Battles") then return end
    data = data or {}

    local caseName = data.caseName
    local case = caseName and u.Cases[caseName]
    if not case or not case.Price then
        ply:ChatPrint("[Unbox] Unknown case.")
        return
    end

    local caseCount = math.Clamp(math.floor(tonumber(data.caseCount) or 1), 1, 5)
    local maxPlayers = math.Clamp(math.floor(tonumber(data.maxPlayers) or 2), 2, 4)
    local entryFee = case.Price * caseCount

    local ok, err = u:ChargeWager(ply, entryFee)
    if not ok then
        ply:ChatPrint("[Unbox] " .. err)
        return
    end

    local id = nextBattleId
    nextBattleId = nextBattleId + 1
    u.CaseBattleLobbies[id] = {
        caseName = caseName, caseCount = caseCount, maxPlayers = maxPlayers,
        entryFee = entryFee, players = { ply },
    }
    BroadcastBattles()
end)

thread.Hook("BCORE:UnboxCaseBattleJoin", function(ply, data)
    if not u:GamblingIsEnabled(ply, u.EnableCaseBattles, "Case Battles") then return end
    local id = (data or {}).id
    local lobby = id and u.CaseBattleLobbies[id]
    if not lobby then
        ply:ChatPrint("[Unbox] That battle no longer exists.")
        return
    end
    for _, p in ipairs(lobby.players) do
        if p == ply then
            ply:ChatPrint("[Unbox] You're already in that battle.")
            return
        end
    end
    if #lobby.players >= lobby.maxPlayers then
        ply:ChatPrint("[Unbox] That battle is full.")
        return
    end

    local ok, err = u:ChargeWager(ply, lobby.entryFee)
    if not ok then
        ply:ChatPrint("[Unbox] " .. err)
        return
    end

    table.insert(lobby.players, ply)
    if #lobby.players >= lobby.maxPlayers then
        ResolveBattle(id)
    else
        BroadcastBattles()
    end
end)

thread.Hook("BCORE:UnboxCaseBattleCancel", function(ply, data)
    local id = (data or {}).id
    local lobby = id and u.CaseBattleLobbies[id]
    if not lobby or lobby.players[1] ~= ply or #lobby.players > 1 then return end

    u:PayWager(ply, lobby.entryFee)
    u.CaseBattleLobbies[id] = nil
    BroadcastBattles()
end)

hook.Add("PlayerDisconnected", "BCORE.Unbox.CaseBattleCleanupOnDisconnect", function(ply)
    for id, lobby in pairs(u.CaseBattleLobbies) do
        if #lobby.players == 1 and lobby.players[1] == ply then
            u.CaseBattleLobbies[id] = nil
        end
    end
end)

thread.Hook("BCORE:UnboxCaseBattleRequestLobbies", function(ply)
    BroadcastBattles()
end)
