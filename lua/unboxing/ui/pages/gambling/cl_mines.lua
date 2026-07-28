local colors = BCORE.Unbox.config.sh.Colors
local thread = BCORE.netstream

local GRID_SIZE = 25
local GRID_COLS = 5

local mineCount = 3
local wagerText = "100"
local active = false
local wager = 0
local multiplier = 1
local tileState = {} -- [i] = "safe" | "mine" | nil (unrevealed)

function BCORE.Unbox:BuildMinesPage(parent)
    local setupRow = BUi.Create("DPanel", parent)
    setupRow:Dock(TOP); setupRow:SetTall(BUi:Scale(100)); setupRow:SetPaintBackground(false)

    BCORE.Unbox:MakeStepper(setupRow, "Mines", 1, 24, mineCount, function(v) mineCount = v end)

    local wagerRow = BUi.Create("DPanel", setupRow)
    wagerRow:Dock(TOP); wagerRow:DockMargin(0, 8, 0, 0); wagerRow:SetTall(BUi:Scale(28)); wagerRow:SetPaintBackground(false)

    local wagerEntry = BUi.Create("DTextEntry", wagerRow)
    wagerEntry:Dock(LEFT); wagerEntry:SetWide(BUi:Scale(140)); wagerEntry:ReadyTextbox()
    wagerEntry:SetFont("BCORE.Unboxs.14"); wagerEntry:SetTextColor(color_white); wagerEntry:SetCursorColor(colors.tert)
    wagerEntry:SetPaintBackground(false); wagerEntry:SetValue(wagerText)
    wagerEntry.OnChange = function(s) wagerText = s:GetValue():gsub("[^%d]", "") end
    wagerEntry.PaintOver = function(s, w, h)
        draw.RoundedBox(6, 0, 0, w, h, ColorAlpha(colors.bg, 200))
        draw.RoundedBox(6, 0, h - 1, w, 1, ColorAlpha(colors.cwhite, 40))
    end

    local actionBtn = BUi.Create("DButton", wagerRow)
    actionBtn:Dock(FILL); actionBtn:DockMargin(8, 0, 0, 0); actionBtn:SetText("")

    local gridPanel = BUi.Create("DPanel", parent)
    gridPanel:Dock(FILL); gridPanel:DockMargin(0, 8, 0, 0); gridPanel:SetPaintBackground(false)

    local statusRow = BUi.Create("DPanel", gridPanel)
    statusRow:Dock(TOP); statusRow:SetTall(BUi:Scale(20)); statusRow:SetPaintBackground(false)
    statusRow:On("Paint", function(_, w, h)
        if active then
            draw.SimpleText(string.format("Multiplier: %.2fx   Potential: %s", multiplier, BCORE.Unbox:FormatMoney(wager * multiplier)),
                "BCORE.Unboxs.13", 0, h / 2, colors.moneygreen, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        else
            draw.SimpleText("Pick a mine count and start a round.", "BCORE.Unbox.13", 0, h / 2,
                ColorAlpha(colors.cwhite, 150), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        end
    end)

    local tileHolder = BUi.Create("DPanel", gridPanel)
    tileHolder:Dock(FILL); tileHolder:DockMargin(0, 6, 0, 0); tileHolder:SetPaintBackground(false)

    local tileBtns = {}

    local function TileColor(i)
        local st = tileState[i]
        if st == "mine" then return Color(200, 60, 60) end
        if st == "safe" then return Color(70, 180, 90) end
        return colors.light
    end

    local function BuildGrid()
        tileHolder:Clear()
        tileBtns = {}
        local gap = BUi:Scale(6)
        tileHolder.PerformLayout = function(s, w, h)
            local cell = math.min((w - gap * (GRID_COLS - 1)) / GRID_COLS, (h - gap * (GRID_COLS - 1)) / GRID_COLS)
            for i = 1, GRID_SIZE do
                local col = (i - 1) % GRID_COLS
                local row = math.floor((i - 1) / GRID_COLS)
                local btn = tileBtns[i]
                if IsValid(btn) then
                    btn:SetSize(cell, cell)
                    btn:SetPos(col * (cell + gap), row * (cell + gap))
                end
            end
        end
        for i = 1, GRID_SIZE do
            local btn = BUi.Create("DButton", tileHolder)
            btn:SetText("")
            btn:ClearPaint():On("Paint", function(s, w, h)
                draw.RoundedBox(4, 0, 0, w, h, TileColor(i))
                if tileState[i] == "mine" then
                    draw.SimpleText("X", "BCORE.Unboxb.16", w / 2, h / 2, color_white, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
                elseif tileState[i] == "safe" then
                    draw.SimpleText("✓", "BCORE.Unboxb.16", w / 2, h / 2, color_white, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
                end
            end)
            btn:FadeHover(ColorAlpha(color_white, tileState[i] and 0 or 20), 4, 4)
            btn:On("DoClick", function()
                if not active or tileState[i] then return end
                thread.Start("BCORE:UnboxMinesReveal", { tile = i })
            end)
            tileBtns[i] = btn
        end
        tileHolder:InvalidateLayout(true)
    end
    BuildGrid()

    local function ResetState()
        active = false
        multiplier = 1
        tileState = {}
    end

    local function RefreshActionBtn()
        actionBtn:ClearPaint():On("Paint", function(s, w, h)
            local label = active and string.format("CASH OUT %.2fx", multiplier) or "START ROUND"
            draw.RoundedBox(6, 0, 0, w, h, active and Color(80, 180, 90) or colors.tert)
            draw.SimpleText(label, "BCORE.Unboxb.13", w / 2, h / 2, color_white, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        end)
    end
    RefreshActionBtn()

    actionBtn:On("DoClick", function()
        if active then
            thread.Start("BCORE:UnboxMinesCashout", {})
            return
        end
        local w = tonumber(wagerText) or 0
        if w <= 0 then return end
        thread.Start("BCORE:UnboxMinesStart", { mineCount = mineCount, wager = w })
    end)

    thread.Hook("BCORE:UnboxMinesStarted", function(data)
        active = true
        wager = data.wager
        multiplier = 1
        tileState = {}
        RefreshActionBtn()
    end)

    thread.Hook("BCORE:UnboxMinesRevealResult", function(data)
        tileState[data.tile] = "safe"
        multiplier = data.multiplier
        RefreshActionBtn()
    end)

    thread.Hook("BCORE:UnboxMinesResult", function(data)
        for _, i in ipairs(data.allMines or {}) do tileState[i] = "mine" end
        BCORE.Unbox:Toast("Boom!", "You hit a mine and lost your wager.", Color(220, 70, 70))
        timer.Simple(1.4, function()
            ResetState()
            RefreshActionBtn()
        end)
    end)

    thread.Hook("BCORE:UnboxMinesCashedOut", function(data)
        BCORE.Unbox:Toast("Cashed out!", string.format("%.2fx - +%s", data.multiplier, BCORE.Unbox:FormatMoney(data.payout)), Color(80, 220, 100))
        ResetState()
        RefreshActionBtn()
    end)
end
