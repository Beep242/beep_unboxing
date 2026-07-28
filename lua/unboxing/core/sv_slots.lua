-- Slots: classic 3-reel spin, one wager, instant resolve - the simplest of all seven games,
-- closest in shape to Dice (single netstream request, single response, no round state at all).
local u = BCORE.Unbox
local thread = BCORE.netstream

-- Weight = how common a symbol is (higher = more common, same convention u.RarityWeights
-- already uses); mult = payout multiplier for landing THREE of this symbol. Config-driven would
-- be a natural follow-up (matching every other number in this whole gambling system), but the
-- symbol table itself doubles as client-visual data (real symbol glyphs) that a generic
-- BCORE.Config records entry can't represent cleanly - left as a real, documented constant here
-- for now rather than half-wiring it through config.
u.SlotSymbols = u.SlotSymbols or {
    { id = "seven", glyph = "7", weight = 2, mult = 25 },
    { id = "bar", glyph = "BAR", weight = 5, mult = 10 },
    { id = "bell", glyph = "BELL", weight = 8, mult = 5 },
    { id = "cherry", glyph = "CHERRY", weight = 15, mult = 2 },
}

local function RollSymbol()
    local total = 0
    for _, s in ipairs(u.SlotSymbols) do total = total + s.weight end
    local roll = math.random() * total
    local acc = 0
    for _, s in ipairs(u.SlotSymbols) do
        acc = acc + s.weight
        if roll <= acc then return s end
    end
    return u.SlotSymbols[#u.SlotSymbols]
end

thread.Hook("BCORE:UnboxSlotsSpin", function(ply, data)
    if not u:GamblingIsEnabled(ply, u.EnableSlots, "Slots") then return end
    local wager = tonumber((data or {}).wager) or 0

    local ok, err = u:ChargeWager(ply, wager)
    if not ok then
        ply:ChatPrint("[Unbox] " .. err)
        return
    end

    local reels = { RollSymbol(), RollSymbol(), RollSymbol() }

    local payout = 0
    if reels[1].id == reels[2].id and reels[2].id == reels[3].id then
        payout = u:ApplyHouseEdge(wager * reels[1].mult)
    elseif reels[1].id == reels[2].id or reels[2].id == reels[3].id or reels[1].id == reels[3].id then
        -- Any two matching - a small consolation payout so a spin only rarely nets a full loss,
        -- a real, deliberately generous-feeling design choice for a house-edge game like this.
        payout = u:ApplyHouseEdge(math.floor(wager * 0.5))
    end

    if payout > 0 then u:PayWager(ply, payout) end

    u:LogGambleRound("slots", { ply }, string.format("wager=%d reels=%s,%s,%s payout=%d",
        wager, reels[1].id, reels[2].id, reels[3].id, payout))

    thread.Start(ply, "BCORE:UnboxSlotsResult", {
        symbols = { reels[1].id, reels[2].id, reels[3].id },
        wager = wager, payout = payout,
    })
end)
