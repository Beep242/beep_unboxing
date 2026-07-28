local colors = BCORE.Unbox.config.sh.Colors
local thread = BCORE.netstream

local wagerText = "100"
local state = { entries = {}, endsAt = 0, active = false }

function BCORE.Unbox:BuildJackpotPage(parent)
    -- Dock(FILL) against whatever size the hub (cl_gambling.lua) actually gives this cell,
    -- rather than a fixed SetSize/SetPos - the same one-page grid every other game's own
    -- builder now fits into instead of assuming it owns the whole page.
    local card = BUi.Create("DPanel", parent)
    card:Dock(FILL); card:DockMargin(BUi:Scale(10), BUi:Scale(10), BUi:Scale(10), BUi:Scale(10))
    card:ClearPaint():On("Paint", function(s, w, h)
        BCORE.Unbox:PaintCard(w, h, colors.tert)
    end)
    card:DockPadding(BUi:Scale(18), BUi:Scale(18), BUi:Scale(18), BUi:Scale(18))

    local header = BUi.Create("DPanel", card)
    header:Dock(TOP); header:SetTall(BUi:Scale(60)); header:SetPaintBackground(false)
    header:On("Paint", function(_, w, h)
        local total = 0
        for _, e in ipairs(state.entries) do total = total + e.amount end
        draw.SimpleText("JACKPOT", "BCORE.Unboxb.20", 0, 4, color_white, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
        draw.SimpleText("Pot: " .. BCORE.Unbox:FormatMoney(total), "BCORE.Unboxb.18", 0, 32,
            colors.moneygreen, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
        if state.active then
            local left = math.max(0, math.ceil(state.endsAt - CurTime()))
            draw.SimpleText(left .. "s left", "BCORE.Unboxs.16", w, 32, ColorAlpha(colors.cwhite, 200), TEXT_ALIGN_RIGHT, TEXT_ALIGN_TOP)
        else
            draw.SimpleText("Waiting for entries...", "BCORE.Unboxs.14", w, 32, ColorAlpha(colors.cwhite, 150), TEXT_ALIGN_RIGHT, TEXT_ALIGN_TOP)
        end
    end)

    local entryList = BUi.Create("BUi.Scroll", card)
    entryList:Dock(FILL); entryList:DockMargin(0, 8, 0, 8)

    local wagerRow = BUi.Create("DPanel", card)
    wagerRow:Dock(BOTTOM); wagerRow:SetTall(BUi:Scale(40)); wagerRow:SetPaintBackground(false)

    local wagerEntry = BUi.Create("DTextEntry", wagerRow)
    wagerEntry:Dock(LEFT); wagerEntry:SetWide(BUi:Scale(140)); wagerEntry:ReadyTextbox()
    wagerEntry:SetFont("BCORE.Unboxs.16"); wagerEntry:SetTextColor(color_white); wagerEntry:SetCursorColor(colors.tert)
    wagerEntry:SetPaintBackground(false); wagerEntry:SetValue(wagerText)
    wagerEntry.OnChange = function(s) wagerText = s:GetValue():gsub("[^%d]", "") end
    wagerEntry.PaintOver = function(s, w, h)
        draw.RoundedBox(6, 0, 0, w, h, ColorAlpha(colors.bg, 200))
        draw.RoundedBox(6, 0, h - 1, w, 1, ColorAlpha(colors.cwhite, 40))
    end

    local joinBtn = BUi.Create("DButton", wagerRow)
    joinBtn:Dock(FILL); joinBtn:DockMargin(8, 0, 0, 0); joinBtn:SetText("")
    joinBtn:ClearPaint():On("Paint", function(s, w, h)
        draw.RoundedBox(6, 0, 0, w, h, colors.tert)
        draw.SimpleText("ADD TO POT", "BCORE.Unboxb.14", w / 2, h / 2, color_white, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    end)
    joinBtn:FadeHover(ColorAlpha(color_white, 25), 6, 8)
    joinBtn:On("DoClick", function()
        local wager = tonumber(wagerText) or 0
        if wager <= 0 then return end
        thread.Start("BCORE:UnboxJackpotJoin", { amount = wager })
    end)

    local function RefreshEntries()
        if not IsValid(entryList) then return end
        entryList:Clear()
        local total = 0
        for _, e in ipairs(state.entries) do total = total + e.amount end
        for _, e in ipairs(state.entries) do
            local pct = total > 0 and (e.amount / total * 100) or 0
            local row = BUi.Create("DPanel", entryList)
            row:Dock(TOP); row:DockMargin(0, 0, 0, 4); row:SetTall(BUi:Scale(28)); row:SetPaintBackground(false)
            row:On("Paint", function(_, w, h)
                draw.RoundedBox(4, 0, 2, w, h - 4, ColorAlpha(colors.light, 150))
                draw.RoundedBox(4, 0, 2, w * (pct / 100), h - 4, ColorAlpha(colors.tert, 120))
                draw.SimpleText(e.name, "BCORE.Unboxs.13", 8, h / 2, color_white, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
                draw.SimpleText(BCORE.Unbox:FormatMoney(e.amount) .. string.format("  (%.0f%%)", pct), "BCORE.Unbox.12",
                    w - 8, h / 2, ColorAlpha(colors.cwhite, 200), TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
            end)
        end
    end

    thread.Hook("BCORE:UnboxJackpotState", function(data)
        state = data or state
        RefreshEntries()
    end)

    thread.Hook("BCORE:UnboxJackpotResult", function(data)
        local won = data.winnerName == LocalPlayer():Nick()
        BCORE.Unbox:Toast(
            "JACKPOT WON",
            data.winnerName .. " won " .. BCORE.Unbox:FormatMoney(data.payout) .. " from a " .. BCORE.Unbox:FormatMoney(data.pot) .. " pot",
            won and Color(80, 220, 100) or colors.tert
        )
    end)

    thread.Start("BCORE:UnboxJackpotRequestState", {})
    RefreshEntries()
end
