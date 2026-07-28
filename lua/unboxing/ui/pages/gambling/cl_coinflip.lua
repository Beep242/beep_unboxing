local colors = BCORE.Unbox.config.sh.Colors
local thread = BCORE.netstream

local wagerText = "100"
local lobbies = {}

-- Stacked vertically (create form on top, lobby list filling the rest below) rather than
-- side-by-side - this now shares the same uniform cell size every other gambling page fits into
-- on the one-page grid (cl_gambling.lua), instead of assuming it owns a much wider standalone tab.
function BCORE.Unbox:BuildCoinflipPage(parent)
    local createCard = BUi.Create("DPanel", parent)
    createCard:Dock(TOP); createCard:SetTall(BUi:Scale(110)); createCard:SetPaintBackground(false)

    local title = BUi.Create("DPanel", createCard)
    title:Dock(TOP); title:SetTall(BUi:Scale(22)); title:SetPaintBackground(false)
    title:On("Paint", function(_, w, h)
        draw.SimpleText("CREATE LOBBY", "BCORE.Unboxb.14", 0, h / 2, ColorAlpha(colors.cwhite, 200), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
    end)

    local wagerEntry = BUi.Create("DTextEntry", createCard)
    wagerEntry:Dock(TOP); wagerEntry:DockMargin(0, 6, 0, 0); wagerEntry:SetTall(BUi:Scale(26)); wagerEntry:ReadyTextbox()
    wagerEntry:SetFont("BCORE.Unboxs.14"); wagerEntry:SetTextColor(color_white); wagerEntry:SetCursorColor(colors.tert)
    wagerEntry:SetPaintBackground(false); wagerEntry:SetValue(wagerText)
    wagerEntry.OnChange = function(s) wagerText = s:GetValue():gsub("[^%d]", "") end
    wagerEntry.PaintOver = function(s, w, h)
        draw.RoundedBox(6, 0, 0, w, h, ColorAlpha(colors.bg, 200))
        draw.RoundedBox(6, 0, h - 1, w, 1, ColorAlpha(colors.cwhite, 40))
    end

    local createBtn = BUi.Create("DButton", createCard)
    createBtn:Dock(TOP); createBtn:DockMargin(0, 6, 0, 0); createBtn:SetTall(BUi:Scale(30)); createBtn:SetText("")
    createBtn:ClearPaint():On("Paint", function(s, w, h)
        draw.RoundedBox(6, 0, 0, w, h, colors.tert)
        draw.SimpleText("CREATE COINFLIP", "BCORE.Unboxb.12", w / 2, h / 2, color_white, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    end)
    createBtn:FadeHover(ColorAlpha(color_white, 25), 6, 8)
    createBtn:On("DoClick", function()
        local wager = tonumber(wagerText) or 0
        if wager <= 0 then return end
        thread.Start("BCORE:UnboxCoinflipCreate", { wager = wager })
    end)

    local listPanel = BUi.Create("DPanel", parent)
    listPanel:Dock(FILL); listPanel:DockMargin(0, 8, 0, 0); listPanel:SetPaintBackground(false)

    local listTitle = BUi.Create("DPanel", listPanel)
    listTitle:Dock(TOP); listTitle:SetTall(BUi:Scale(22)); listTitle:SetPaintBackground(false)
    listTitle:On("Paint", function(_, w, h)
        draw.SimpleText("OPEN LOBBIES", "BCORE.Unboxb.14", 0, h / 2, ColorAlpha(colors.cwhite, 200), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
    end)

    local scroll = BUi.Create("BUi.Scroll", listPanel)
    scroll:Dock(FILL); scroll:DockMargin(0, 6, 0, 0)

    local function RefreshList()
        if not IsValid(scroll) then return end
        scroll:Clear()
        if #lobbies == 0 then
            local empty = BUi.Create("DPanel", scroll)
            empty:Dock(TOP); empty:SetTall(BUi:Scale(26)); empty:SetPaintBackground(false)
            empty:On("Paint", function(_, w, h)
                draw.SimpleText("No open lobbies - create one!", "BCORE.Unbox.13", 0, h / 2,
                    ColorAlpha(colors.cwhite, 150), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
            end)
            return
        end
        for _, lobby in ipairs(lobbies) do
            local row = BUi.Create("DPanel", scroll)
            row:Dock(TOP); row:DockMargin(0, 0, 0, 6); row:SetTall(BUi:Scale(42))
            row:ClearPaint():Background(colors.light, 6):On("Paint", function(s, w, h)
                draw.RoundedBox(6, 1, 1, w - 2, h - 2, colors.sec)
                draw.SimpleText(lobby.creatorName, "BCORE.Unboxs.13", 10, h / 2 - 8, color_white, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
                draw.SimpleText(BCORE.Unbox:FormatMoney(lobby.wager), "BCORE.Unboxb.12", 10, h / 2 + 8,
                    colors.moneygreen, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
            end)
            local joinBtn = BUi.Create("DButton", row)
            joinBtn:Dock(RIGHT); joinBtn:DockMargin(0, 7, 8, 7); joinBtn:SetWide(BUi:Scale(70)); joinBtn:SetText("")
            joinBtn:ClearPaint():On("Paint", function(s, w, h)
                draw.RoundedBox(5, 0, 0, w, h, colors.tert)
                draw.SimpleText("JOIN", "BCORE.Unboxb.12", w / 2, h / 2, color_white, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
            end)
            joinBtn:FadeHover(ColorAlpha(color_white, 25), 5, 6)
            joinBtn:On("DoClick", function()
                thread.Start("BCORE:UnboxCoinflipJoin", { id = lobby.id })
            end)
        end
    end

    thread.Hook("BCORE:UnboxCoinflipLobbies", function(data)
        lobbies = (data or {}).lobbies or {}
        RefreshList()
    end)

    thread.Hook("BCORE:UnboxCoinflipResult", function(data)
        local won = data.winnerName == LocalPlayer():Nick()
        BCORE.Unbox:Toast(
            data.heads and "HEADS!" or "TAILS!",
            data.winnerName .. " won " .. BCORE.Unbox:FormatMoney(data.payout),
            won and Color(80, 220, 100) or Color(220, 70, 70)
        )
    end)

    thread.Start("BCORE:UnboxCoinflipRequestLobbies", {})
    RefreshList()
end
