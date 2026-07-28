local colors = BCORE.Unbox.config.sh.Colors
local thread = BCORE.netstream

local wagerText = "100"
local state = { state = "betting", multiplier = 1, endsAt = 0, bettors = {} }
local lastCrashPoint = nil
local myCashOutAt = nil

local function MyBet()
    local name = LocalPlayer():Nick()
    for _, b in ipairs(state.bettors) do
        if b.name == name then return b end
    end
    return nil
end

function BCORE.Unbox:BuildCrashPage(parent)
    -- Dock(FILL) against whatever size the hub (cl_gambling.lua) actually gives this cell,
    -- rather than a fixed SetSize/SetPos - the same one-page grid every other game's own
    -- builder now fits into instead of assuming it owns the whole page.
    local card = BUi.Create("DPanel", parent)
    card:Dock(FILL); card:DockMargin(BUi:Scale(10), BUi:Scale(10), BUi:Scale(10), BUi:Scale(10))
    card:ClearPaint():On("Paint", function(s, w, h)
        BCORE.Unbox:PaintCard(w, h, colors.tert)
    end)
    card:DockPadding(BUi:Scale(18), BUi:Scale(18), BUi:Scale(18), BUi:Scale(18))

    local display = BUi.Create("DPanel", card)
    display:Dock(TOP); display:SetTall(BUi:Scale(140)); display:SetPaintBackground(false)
    display:On("Paint", function(_, w, h)
        local mult = state.multiplier or 1
        local clr = color_white
        local big
        if state.state == "betting" then
            local left = math.max(0, math.ceil(state.endsAt - CurTime()))
            big = "BETTING - " .. left .. "s"
            clr = ColorAlpha(colors.cwhite, 220)
        elseif state.state == "running" then
            big = string.format("%.2fx", mult)
            clr = Color(80, 220, 100)
        else
            big = lastCrashPoint and string.format("CRASHED @ %.2fx", lastCrashPoint) or "CRASHED"
            clr = Color(220, 70, 70)
        end
        draw.SimpleText(big, "BCORE.Unboxb.32", w / 2, h / 2 - 10, clr, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)

        -- Bar fills toward the top of a nominal 0-10x visual range - purely a "climbing" cue, not
        -- a literal-scale graph (a real crash multiplier is unbounded, a fixed axis isn't).
        local frac = math.Clamp((mult - 1) / 9, 0, 1)
        draw.RoundedBox(4, 0, h - 14, w, 10, ColorAlpha(colors.light, 150))
        draw.RoundedBox(4, 0, h - 14, w * frac, 10, ColorAlpha(clr, 200))
    end)

    local betRow = BUi.Create("DPanel", card)
    betRow:Dock(TOP); betRow:DockMargin(0, 10, 0, 0); betRow:SetTall(BUi:Scale(40)); betRow:SetPaintBackground(false)

    local wagerEntry = BUi.Create("DTextEntry", betRow)
    wagerEntry:Dock(LEFT); wagerEntry:SetWide(BUi:Scale(140)); wagerEntry:ReadyTextbox()
    wagerEntry:SetFont("BCORE.Unboxs.16"); wagerEntry:SetTextColor(color_white); wagerEntry:SetCursorColor(colors.tert)
    wagerEntry:SetPaintBackground(false); wagerEntry:SetValue(wagerText)
    wagerEntry.OnChange = function(s) wagerText = s:GetValue():gsub("[^%d]", "") end
    wagerEntry.PaintOver = function(s, w, h)
        draw.RoundedBox(6, 0, 0, w, h, ColorAlpha(colors.bg, 200))
        draw.RoundedBox(6, 0, h - 1, w, 1, ColorAlpha(colors.cwhite, 40))
    end

    local actionBtn = BUi.Create("DButton", betRow)
    actionBtn:Dock(FILL); actionBtn:DockMargin(8, 0, 0, 0); actionBtn:SetText("")
    actionBtn:ClearPaint():On("Paint", function(s, w, h)
        local mine = MyBet()
        local label, bg = "PLACE BET", colors.tert
        if state.state == "betting" then
            if mine then label, bg = "BET PLACED", colors.light end
        elseif state.state == "running" then
            if mine and not mine.cashedOutAt then
                label, bg = string.format("CASH OUT @ %.2fx", state.multiplier or 1), Color(80, 180, 90)
            elseif mine and mine.cashedOutAt then
                label, bg = string.format("CASHED OUT @ %.2fx", mine.cashedOutAt), colors.light
            else
                label, bg = "ROUND IN PROGRESS", colors.light
            end
        else
            label, bg = "WAIT FOR NEXT ROUND", colors.light
        end
        draw.RoundedBox(6, 0, 0, w, h, bg)
        draw.SimpleText(label, "BCORE.Unboxb.14", w / 2, h / 2, color_white, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    end)
    actionBtn:On("DoClick", function()
        local mine = MyBet()
        if state.state == "betting" and not mine then
            local wager = tonumber(wagerText) or 0
            if wager <= 0 then return end
            thread.Start("BCORE:UnboxCrashBet", { wager = wager })
        elseif state.state == "running" and mine and not mine.cashedOutAt then
            thread.Start("BCORE:UnboxCrashCashOut", {})
        end
    end)

    local listTitle = BUi.Create("DPanel", card)
    listTitle:Dock(TOP); listTitle:DockMargin(0, 12, 0, 0); listTitle:SetTall(BUi:Scale(20)); listTitle:SetPaintBackground(false)
    listTitle:On("Paint", function(_, w, h)
        draw.SimpleText("IN THIS ROUND", "BCORE.Unboxb.13", 0, h / 2, ColorAlpha(colors.cwhite, 180), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
    end)

    local betList = BUi.Create("BUi.Scroll", card)
    betList:Dock(FILL); betList:DockMargin(0, 6, 0, 0)

    local function RefreshBets()
        if not IsValid(betList) then return end
        betList:Clear()
        for _, b in ipairs(state.bettors) do
            local row = BUi.Create("DPanel", betList)
            row:Dock(TOP); row:DockMargin(0, 0, 0, 4); row:SetTall(BUi:Scale(24)); row:SetPaintBackground(false)
            row:On("Paint", function(_, w, h)
                local status = b.cashedOutAt and string.format("cashed out @ %.2fx", b.cashedOutAt) or
                    (state.state == "crashed" and "lost" or "in")
                local clr = b.cashedOutAt and Color(80, 220, 100) or (state.state == "crashed" and Color(220, 70, 70) or ColorAlpha(colors.cwhite, 200))
                draw.SimpleText(b.name .. "  " .. BCORE.Unbox:FormatMoney(b.wager), "BCORE.Unbox.13",
                    0, h / 2, ColorAlpha(colors.cwhite, 220), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
                draw.SimpleText(status, "BCORE.Unbox.13", w, h / 2, clr, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
            end)
        end
    end

    thread.Hook("BCORE:UnboxCrashState", function(data)
        state = data or state
        RefreshBets()
    end)

    thread.Hook("BCORE:UnboxCrashCrashed", function(data)
        lastCrashPoint = data.crashPoint
    end)

    thread.Hook("BCORE:UnboxCrashCashedOut", function(data)
        BCORE.Unbox:Toast("Cashed out!", string.format("%.2fx - +%s", data.multiplier, BCORE.Unbox:FormatMoney(data.payout)), Color(80, 220, 100))
    end)

    thread.Start("BCORE:UnboxCrashRequestState", {})
    RefreshBets()
end
