local colors = BCORE.Unbox.config.sh.Colors
local thread = BCORE.netstream

local selectedCase = nil
local caseCount = 1
local maxPlayers = 2
local lobbies = {}

local function AvailableCases()
    local data = LocalPlayer().BCORE_UNBOX_DATA or {}
    return data.caseDefs or {}
end

-- Stacked vertically (create form on top, battle list filling the rest below) rather than
-- side-by-side - this now shares the same uniform cell size every other gambling page fits into
-- on the one-page grid (cl_gambling.lua), instead of assuming it owns a much wider standalone tab.
function BCORE.Unbox:BuildCaseBattlesPage(parent)
    local createCard = BUi.Create("DPanel", parent)
    createCard:Dock(TOP); createCard:SetTall(BUi:Scale(158)); createCard:SetPaintBackground(false)

    local title = BUi.Create("DPanel", createCard)
    title:Dock(TOP); title:SetTall(BUi:Scale(20)); title:SetPaintBackground(false)
    title:On("Paint", function(_, w, h)
        draw.SimpleText("CREATE BATTLE", "BCORE.Unboxb.14", 0, h / 2, ColorAlpha(colors.cwhite, 200), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
    end)

    local caseCombo = BUi.Create("BUi.Combo", createCard)
    caseCombo:Dock(TOP); caseCombo:DockMargin(0, 6, 0, 0); caseCombo:SetTall(BUi:Scale(26))
    for key, cdef in SortedPairsByMemberValue(AvailableCases(), "Name") do
        caseCombo:AddChoice((cdef.Name or key) .. "  (" .. BCORE.Unbox:FormatMoney(cdef.Price or 0) .. ")", key)
    end
    -- BUi.Combo's own OnSelect is called as self:OnSelect(text, data) (cl_combo.lua) - a method
    -- call, so the real callback signature is (self, text, data), matching every other
    -- BUi.Combo.OnSelect assignment in this codebase (see cl_config.lua's own CreateComboFor
    -- callers), not (self, index, text, data) the way a raw native DComboBox's OnSelect works.
    caseCombo.OnSelect = function(_, _, data) selectedCase = data end

    BCORE.Unbox:MakeStepper(createCard, "Cases per player", 1, 5, caseCount, function(v) caseCount = v end)
    BCORE.Unbox:MakeStepper(createCard, "Max players", 2, 4, maxPlayers, function(v) maxPlayers = v end)

    local createBtn = BUi.Create("DButton", createCard)
    createBtn:Dock(TOP); createBtn:DockMargin(0, 6, 0, 0); createBtn:SetTall(BUi:Scale(28)); createBtn:SetText("")
    createBtn:ClearPaint():On("Paint", function(s, w, h)
        draw.RoundedBox(6, 0, 0, w, h, colors.tert)
        draw.SimpleText("CREATE BATTLE", "BCORE.Unboxb.12", w / 2, h / 2, color_white, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    end)
    createBtn:FadeHover(ColorAlpha(color_white, 25), 6, 8)
    createBtn:On("DoClick", function()
        if not selectedCase then
            local _, firstKey = next(AvailableCases())
            selectedCase = firstKey
        end
        if not selectedCase then return end
        thread.Start("BCORE:UnboxCaseBattleCreate", { caseName = selectedCase, caseCount = caseCount, maxPlayers = maxPlayers })
    end)

    local listPanel = BUi.Create("DPanel", parent)
    listPanel:Dock(FILL); listPanel:DockMargin(0, 8, 0, 0); listPanel:SetPaintBackground(false)

    local listTitle = BUi.Create("DPanel", listPanel)
    listTitle:Dock(TOP); listTitle:SetTall(BUi:Scale(22)); listTitle:SetPaintBackground(false)
    listTitle:On("Paint", function(_, w, h)
        draw.SimpleText("OPEN BATTLES", "BCORE.Unboxb.14", 0, h / 2, ColorAlpha(colors.cwhite, 200), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
    end)

    local scroll = BUi.Create("BUi.Scroll", listPanel)
    scroll:Dock(FILL); scroll:DockMargin(0, 6, 0, 0)

    local function RefreshList()
        if not IsValid(scroll) then return end
        scroll:Clear()
        local items = AvailableCases()
        if #lobbies == 0 then
            local empty = BUi.Create("DPanel", scroll)
            empty:Dock(TOP); empty:SetTall(BUi:Scale(26)); empty:SetPaintBackground(false)
            empty:On("Paint", function(_, w, h)
                draw.SimpleText("No open battles - create one!", "BCORE.Unbox.13", 0, h / 2,
                    ColorAlpha(colors.cwhite, 150), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
            end)
            return
        end
        for _, lobby in ipairs(lobbies) do
            local cdef = items[lobby.caseName] or {}
            local row = BUi.Create("DPanel", scroll)
            row:Dock(TOP); row:DockMargin(0, 0, 0, 6); row:SetTall(BUi:Scale(54))
            row:ClearPaint():Background(colors.light, 6):On("Paint", function(s, w, h)
                draw.RoundedBox(6, 1, 1, w - 2, h - 2, colors.sec)
                draw.SimpleText((cdef.Name or lobby.caseName) .. " x" .. lobby.caseCount, "BCORE.Unboxs.13",
                    10, h / 2 - 12, color_white, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
                draw.SimpleText(table.concat(lobby.players, ", ") .. "  (" .. #lobby.players .. "/" .. lobby.maxPlayers .. ")",
                    "BCORE.Unbox.11", 10, h / 2 + 5, ColorAlpha(colors.cwhite, 180), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
                draw.SimpleText(BCORE.Unbox:FormatMoney(lobby.entryFee), "BCORE.Unboxb.12", 10, h / 2 + 20,
                    colors.moneygreen, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
            end)
            local joinBtn = BUi.Create("DButton", row)
            joinBtn:Dock(RIGHT); joinBtn:DockMargin(0, 11, 8, 11); joinBtn:SetWide(BUi:Scale(70)); joinBtn:SetText("")
            joinBtn:ClearPaint():On("Paint", function(s, w, h)
                draw.RoundedBox(5, 0, 0, w, h, colors.tert)
                draw.SimpleText("JOIN", "BCORE.Unboxb.12", w / 2, h / 2, color_white, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
            end)
            joinBtn:FadeHover(ColorAlpha(color_white, 25), 5, 6)
            joinBtn:On("DoClick", function()
                thread.Start("BCORE:UnboxCaseBattleJoin", { id = lobby.id })
            end)
        end
    end

    thread.Hook("BCORE:UnboxCaseBattleLobbies", function(data)
        lobbies = (data or {}).lobbies or {}
        RefreshList()
    end)

    thread.Hook("BCORE:UnboxCaseBattleResult", function(data)
        local mine = nil
        for _, p in ipairs(data.players) do
            if p.name == LocalPlayer():Nick() then mine = p end
        end
        local won = data.winnerName == LocalPlayer():Nick()
        BCORE.Unbox:Toast(
            won and "YOU WON THE BATTLE" or "Battle finished",
            data.winnerName .. " won " .. BCORE.Unbox:FormatMoney(data.payout) .. (mine and (" - you opened " .. BCORE.Unbox:FormatMoney(mine.totalValue)) or ""),
            won and Color(80, 220, 100) or colors.tert
        )
    end)

    thread.Start("BCORE:UnboxCaseBattleRequestLobbies", {})
    RefreshList()
end
