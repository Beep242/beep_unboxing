local colors = BCORE.Unbox.config.sh.Colors
local thread = BCORE.netstream

local threshold = 50
local wagerText = "100"
local lastResult = nil

function BCORE.Unbox:BuildDicePage(parent)
    -- Dock(FILL) against whatever size the hub (cl_gambling.lua) actually gives this cell,
    -- rather than a fixed SetSize/SetPos - the same one-page grid every other game's own
    -- builder now fits into instead of assuming it owns the whole page.
    local card = BUi.Create("DPanel", parent)
    card:Dock(FILL); card:DockMargin(BUi:Scale(10), BUi:Scale(10), BUi:Scale(10), BUi:Scale(10))
    card:ClearPaint():On("Paint", function(s, w, h)
        BCORE.Unbox:PaintCard(w, h, colors.tert)
    end)
    card:DockPadding(BUi:Scale(18), BUi:Scale(18), BUi:Scale(18), BUi:Scale(18))

    local title = BUi.Create("DPanel", card)
    title:Dock(TOP); title:SetTall(BUi:Scale(30)); title:SetPaintBackground(false)
    title:On("Paint", function(_, w, h)
        draw.SimpleText("DICE - Roll Under", "BCORE.Unboxb.18", 0, h / 2, color_white, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
    end)

    local wagerRow = BUi.Create("DPanel", card)
    wagerRow:Dock(TOP); wagerRow:DockMargin(0, 10, 0, 0); wagerRow:SetTall(BUi:Scale(50))
    wagerRow:SetPaintBackground(false)
    wagerRow:On("Paint", function(_, w, h)
        draw.SimpleText("WAGER", "BCORE.Unboxs.12", 0, 6, ColorAlpha(colors.cwhite, 150), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
    end)
    local wagerEntry = BUi.Create("DTextEntry", wagerRow)
    wagerEntry:Dock(BOTTOM); wagerEntry:SetTall(BUi:Scale(28)); wagerEntry:ReadyTextbox()
    wagerEntry:SetFont("BCORE.Unboxs.16"); wagerEntry:SetTextColor(color_white); wagerEntry:SetCursorColor(colors.tert)
    wagerEntry:SetPaintBackground(false); wagerEntry:SetValue(wagerText)
    wagerEntry.OnChange = function(s) wagerText = s:GetValue():gsub("[^%d]", "") end
    wagerEntry.PaintOver = function(s, w, h)
        draw.RoundedBox(6, 0, 0, w, h, ColorAlpha(colors.bg, 200))
        draw.RoundedBox(6, 0, h - 1, w, 1, ColorAlpha(colors.cwhite, 40))
    end

    BCORE.Unbox:MakeSlider(card, "Roll Under", 1, 99, threshold, function(v) threshold = v end)

    local oddsRow = BUi.Create("DPanel", card)
    oddsRow:Dock(TOP); oddsRow:DockMargin(0, 6, 0, 0); oddsRow:SetTall(BUi:Scale(24))
    oddsRow:SetPaintBackground(false)
    oddsRow:On("Paint", function(_, w, h)
        local mult = 100 / math.max(1, threshold)
        draw.SimpleText(string.format("Win Chance: %d%%   Payout: %.2fx", threshold, mult), "BCORE.Unbox.13",
            0, h / 2, ColorAlpha(colors.cwhite, 170), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
    end)

    local resultRow = BUi.Create("DPanel", card)
    resultRow:Dock(TOP); resultRow:DockMargin(0, 10, 0, 0); resultRow:SetTall(BUi:Scale(30))
    resultRow:SetPaintBackground(false)
    resultRow:On("Paint", function(_, w, h)
        if not lastResult then return end
        local clr = lastResult.won and Color(80, 220, 100) or Color(220, 70, 70)
        local txt = string.format("Rolled %d - %s%s", lastResult.roll,
            lastResult.won and "WIN " or "LOSE",
            lastResult.won and ("+" .. BCORE.Unbox:FormatMoney(lastResult.payout)) or "")
        draw.SimpleText(txt, "BCORE.Unboxb.15", 0, h / 2, clr, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
    end)

    local rollBtn = BUi.Create("DButton", card)
    rollBtn:Dock(BOTTOM); rollBtn:SetTall(BUi:Scale(40)); rollBtn:SetText("")
    rollBtn:ClearPaint():On("Paint", function(s, w, h)
        draw.RoundedBox(6, 0, 0, w, h, colors.tert)
        draw.SimpleText("ROLL", "BCORE.Unboxb.16", w / 2, h / 2, color_white, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    end)
    rollBtn:FadeHover(ColorAlpha(color_white, 25), 6, 8)
    rollBtn:On("DoClick", function()
        local wager = tonumber(wagerText) or 0
        if wager <= 0 then return end
        thread.Start("BCORE:UnboxDicePlay", { threshold = threshold, wager = wager })
    end)

    thread.Hook("BCORE:UnboxDiceResult", function(data)
        lastResult = data
        BCORE.Unbox:Toast(data.won and "You won!" or "You lost", data.won and ("+" .. BCORE.Unbox:FormatMoney(data.payout)) or "", data.won and Color(80, 220, 100) or Color(220, 70, 70))
    end)
end
