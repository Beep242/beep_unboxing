local colors = BCORE.Unbox.config.sh.Colors
local thread = BCORE.netstream

local wagerText = "100"
local reels = { "?", "?", "?" }
local lastPayout = nil
local spinning = false

local GLYPHS = { seven = "7", bar = "BAR", bell = "BELL", cherry = "CHERRY" }

function BCORE.Unbox:BuildSlotsPage(parent)
    local reelPanel = BUi.Create("DPanel", parent)
    reelPanel:Dock(TOP); reelPanel:SetTall(BUi:Scale(120)); reelPanel:SetPaintBackground(false)
    reelPanel:On("Paint", function(_, w, h)
        local slotW = (w - BUi:Scale(16)) / 3
        for i = 1, 3 do
            local x = (i - 1) * (slotW + BUi:Scale(8))
            draw.RoundedBox(6, x, 0, slotW, h, colors.light)
            draw.RoundedBox(6, x + 1, 1, slotW - 2, h - 2, colors.sec)
            local glyph = GLYPHS[reels[i]] or reels[i] or "?"
            draw.SimpleText(glyph, "BCORE.Unboxb.22", x + slotW / 2, h / 2, color_white, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        end
    end)

    local resultRow = BUi.Create("DPanel", parent)
    resultRow:Dock(TOP); resultRow:DockMargin(0, 8, 0, 0); resultRow:SetTall(BUi:Scale(24)); resultRow:SetPaintBackground(false)
    resultRow:On("Paint", function(_, w, h)
        if not lastPayout then return end
        local won = lastPayout > 0
        draw.SimpleText(won and ("WIN +" .. BCORE.Unbox:FormatMoney(lastPayout)) or "No match",
            "BCORE.Unboxb.14", w / 2, h / 2, won and Color(80, 220, 100) or Color(220, 70, 70),
            TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    end)

    local wagerRow = BUi.Create("DPanel", parent)
    wagerRow:Dock(TOP); wagerRow:DockMargin(0, 8, 0, 0); wagerRow:SetTall(BUi:Scale(30)); wagerRow:SetPaintBackground(false)

    local wagerEntry = BUi.Create("DTextEntry", wagerRow)
    wagerEntry:Dock(LEFT); wagerEntry:SetWide(BUi:Scale(140)); wagerEntry:ReadyTextbox()
    wagerEntry:SetFont("BCORE.Unboxs.14"); wagerEntry:SetTextColor(color_white); wagerEntry:SetCursorColor(colors.tert)
    wagerEntry:SetPaintBackground(false); wagerEntry:SetValue(wagerText)
    wagerEntry.OnChange = function(s) wagerText = s:GetValue():gsub("[^%d]", "") end
    wagerEntry.PaintOver = function(s, w, h)
        draw.RoundedBox(6, 0, 0, w, h, ColorAlpha(colors.bg, 200))
        draw.RoundedBox(6, 0, h - 1, w, 1, ColorAlpha(colors.cwhite, 40))
    end

    local spinBtn = BUi.Create("DButton", wagerRow)
    spinBtn:Dock(FILL); spinBtn:DockMargin(8, 0, 0, 0); spinBtn:SetText("")
    spinBtn:ClearPaint():On("Paint", function(s, w, h)
        draw.RoundedBox(6, 0, 0, w, h, colors.tert)
        draw.SimpleText(spinning and "SPINNING..." or "SPIN", "BCORE.Unboxb.14", w / 2, h / 2, color_white, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    end)
    spinBtn:FadeHover(ColorAlpha(color_white, 25), 6, 8)
    spinBtn:On("DoClick", function()
        if spinning then return end
        local wager = tonumber(wagerText) or 0
        if wager <= 0 then return end
        spinning = true
        thread.Start("BCORE:UnboxSlotsSpin", { wager = wager })
    end)

    local payTable = BUi.Create("DPanel", parent)
    payTable:Dock(FILL); payTable:DockMargin(0, 10, 0, 0); payTable:SetPaintBackground(false)
    payTable:On("Paint", function(_, w, h)
        draw.SimpleText("PAYOUTS (3 of a kind)", "BCORE.Unboxb.12", 0, 0, ColorAlpha(colors.cwhite, 180), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
        local rows = { { "7", "25x" }, { "BAR", "10x" }, { "BELL", "5x" }, { "CHERRY", "2x" } }
        for i, r in ipairs(rows) do
            local y = BUi:Scale(22) + (i - 1) * BUi:Scale(20)
            draw.SimpleText(r[1], "BCORE.Unbox.12", 0, y, ColorAlpha(colors.cwhite, 160), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
            draw.SimpleText(r[2], "BCORE.Unboxb.12", w, y, colors.moneygreen, TEXT_ALIGN_RIGHT, TEXT_ALIGN_TOP)
        end
        draw.SimpleText("Any 2 matching pays 0.5x", "BCORE.Unbox.11", 0, BUi:Scale(22) + 4 * BUi:Scale(20) + 6,
            ColorAlpha(colors.cwhite, 130), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
    end)

    thread.Hook("BCORE:UnboxSlotsResult", function(data)
        spinning = false
        reels = data.symbols or reels
        lastPayout = data.payout or 0
    end)
end
