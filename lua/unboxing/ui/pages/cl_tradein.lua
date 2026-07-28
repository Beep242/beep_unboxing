local colors = BCORE.Unbox.config.sh.Colors
local thread  = BCORE.netstream
local IC      = BCORE.Unbox.Icons

-- Real, config-driven wager/percent readouts, but scrap/trade-up counts are purely local UI
-- state (selected[itemKey] = count queued for the current mode) - reset whenever the mode
-- switches or a request completes, since the server is re-synced (BCORE:UnboxSendData) right
-- after anyway.
local mode = "scrap" -- "scrap" | "tradeup"
local selected = {}

local function OwnedInventory()
    local data = LocalPlayer().BCORE_UNBOX_DATA or {}
    return data.inventory or {}, data.items or {}
end

local function TotalSelected()
    local n = 0
    for _, c in pairs(selected) do n = n + c end
    return n
end

local function SelectedRarity(items)
    local rarity = nil
    for key, c in pairs(selected) do
        if c > 0 then
            local r = string.lower((items[key] or {}).rarity or "common")
            if rarity and r ~= rarity then return nil end -- mixed rarities, invalid for trade-up
            rarity = r
        end
    end
    return rarity
end

local function ScrapPayoutPreview(items)
    local pct = (BCORE.Unbox.ScrapPercent or 40) / 100
    local total = 0
    for key, c in pairs(selected) do
        local item = items[key]
        if item then total = total + math.floor((item.basePrice or 0) * pct) * c end
    end
    return total
end

function BCORE.Unbox:TradeIn()
    local page = BCORE.Unbox:CreatePage("Trade-In", IC.tradein)

    local header = BUi.Create("DPanel", page)
    header:Stick(TOP, 0, 8, 8, 0, 0); header:SetTall(BUi:Scale(56))
    header:SetPaintBackground(false)

    local modeScrap = BUi.Create("DButton", header)
    modeScrap:Stick(LEFT, 0, 0, 0, 0, 0); modeScrap:SetWide(BUi:Scale(200)); modeScrap:SetText("SCRAP FOR CASH")
    modeScrap:SetFont("BCORE.Unboxb.15"); modeScrap:SetTextColor(color_white)

    local modeTradeUp = BUi.Create("DButton", header)
    modeTradeUp:Dock(LEFT); modeTradeUp:DockMargin(8, 0, 0, 0); modeTradeUp:SetWide(BUi:Scale(200)); modeTradeUp:SetText("TRADE UP")
    modeTradeUp:SetFont("BCORE.Unboxb.15"); modeTradeUp:SetTextColor(color_white)

    local body = BUi.Create("DPanel", page)
    body:Stick(FILL, 0, 8, 8, 8, 8); body:SetPaintBackground(false)

    local grid = BUi.Create("BUi.Scroll", body)
    grid:Stick(FILL, 0, 0, 0, BUi:Scale(280), 0)
    local layout = BUi.Create("DIconLayout", grid)
    layout:Dock(FILL); layout:SetSpaceX(BUi:Scale(10)); layout:SetSpaceY(BUi:Scale(10))

    local side = BUi.Create("DPanel", body)
    side:Stick(RIGHT, 0, 0, 0, 0, 0); side:SetWide(BUi:Scale(260))
    side:ClearPaint():On("Paint", function(s, w, h)
        BCORE.Unbox:PaintCard(w, h, colors.tert)
    end)
    side:DockPadding(BUi:Scale(14), BUi:Scale(14), BUi:Scale(14), BUi:Scale(14))

    local sideTitle = BUi.Create("DPanel", side)
    sideTitle:Dock(TOP); sideTitle:SetTall(BUi:Scale(26)); sideTitle:ClearPaint()
    -- Set once here (reads `mode` live via closure each frame) rather than re-added inside
    -- RefreshSide below - :On("Paint", ...) CHAINS handlers rather than replacing them, and
    -- RefreshSide runs on every selection change, which would otherwise stack a fresh duplicate
    -- Paint handler on every single click.
    sideTitle:On("Paint", function(_, w, h)
        draw.SimpleText(mode == "scrap" and "SELECTED FOR SCRAP" or "SELECTED FOR TRADE-UP",
            "BCORE.Unboxb.15", 0, h / 2, color_white, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
    end)

    local sideList = BUi.Create("BUi.Scroll", side)
    sideList:Dock(FILL); sideList:DockMargin(0, 6, 0, 6)

    local confirmBtn = BUi.Create("DButton", side)
    confirmBtn:Dock(BOTTOM); confirmBtn:SetTall(BUi:Scale(40)); confirmBtn:SetText("")
    confirmBtn:SetFont("BCORE.Unboxb.16"); confirmBtn:SetTextColor(color_white)

    local RefreshGrid, RefreshSide

    local function SetMode(m)
        mode = m
        selected = {}
        RefreshGrid()
        RefreshSide()
    end

    BUi:StyleTabButton(modeScrap, function() return mode == "scrap" end)
    BUi:StyleTabButton(modeTradeUp, function() return mode == "tradeup" end)
    modeScrap:On("DoClick", function() SetMode("scrap") end)
    modeTradeUp:On("DoClick", function() SetMode("tradeup") end)

    RefreshSide = function()
        if not IsValid(side) then return end
        local inv, items = OwnedInventory()

        sideList:Clear()
        local any = false
        for key, c in pairs(selected) do
            if c > 0 then
                any = true
                local item = items[key] or {}
                local row = BUi.Create("DPanel", sideList)
                row:Dock(TOP); row:DockMargin(0, 0, 0, 6); row:SetTall(BUi:Scale(24))
                row:SetPaintBackground(false)
                row:On("Paint", function(_, w, h)
                    draw.SimpleText((item.name or key) .. "  x" .. c, "BCORE.Unbox.13",
                        0, h / 2, ColorAlpha(colors.cwhite, 200), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
                end)
            end
        end
        if not any then
            local empty = BUi.Create("DPanel", sideList)
            empty:Dock(TOP); empty:SetTall(BUi:Scale(24)); empty:SetPaintBackground(false)
            empty:On("Paint", function(_, w, h)
                draw.SimpleText("Click items to select them.", "BCORE.Unbox.13",
                    0, h / 2, ColorAlpha(colors.cwhite, 130), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
            end)
        end

        if mode == "scrap" then
            local payout = ScrapPayoutPreview(items)
            confirmBtn:SetText("")
            confirmBtn:ClearPaint():On("Paint", function(s, w, h)
                draw.RoundedBox(6, 0, 0, w, h, payout > 0 and colors.tert or colors.light)
                draw.SimpleText(payout > 0 and ("SCRAP FOR " .. BCORE.Unbox:FormatMoney(payout)) or "SELECT ITEMS",
                    "BCORE.Unboxb.15", w / 2, h / 2, color_white, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
            end)
            confirmBtn.DoClick = function()
                if payout <= 0 then return end
                thread.Start("BCORE:UnboxScrapItems", { counts = table.Copy(selected) })
                selected = {}
                RefreshGrid(); RefreshSide()
            end
        else
            local required = BCORE.Unbox.TradeUpItemsRequired or 5
            local total = TotalSelected()
            local rarity = SelectedRarity(items)
            local valid = total == required and rarity ~= nil
            confirmBtn:ClearPaint():On("Paint", function(s, w, h)
                draw.RoundedBox(6, 0, 0, w, h, valid and colors.tert or colors.light)
                local label
                if not rarity and total > 0 then
                    label = "MIXED RARITIES"
                elseif total < required then
                    label = total .. " / " .. required .. " SELECTED"
                elseif total > required then
                    label = "TOO MANY (" .. total .. " / " .. required .. ")"
                else
                    label = "TRADE UP"
                end
                draw.SimpleText(label, "BCORE.Unboxb.14", w / 2, h / 2, color_white, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
            end)
            confirmBtn.DoClick = function()
                if not valid then return end
                local keys = {}
                for key, c in pairs(selected) do
                    for i = 1, c do keys[#keys + 1] = key end
                end
                thread.Start("BCORE:UnboxTradeUpItems", { keys = keys })
                selected = {}
                RefreshGrid(); RefreshSide()
            end
        end
    end

    RefreshGrid = function()
        if not IsValid(layout) then return end
        layout:Clear()
        local inv, items = OwnedInventory()

        for key, owned in SortedPairs(inv) do
            if owned <= 0 then continue end
            local item = items[key] or {}
            local rarityColor = BCORE.Unbox:RarityColor(item.rarity)

            local card = BUi.Create("DButton", layout)
            card:SetSize(BUi:Scale(120), BUi:Scale(120))
            card:SetText("")
            card:ClearPaint():On("Paint", function(s, w, h)
                BCORE.Unbox:PaintCard(w, h, rarityColor)
                local c = selected[key] or 0
                draw.SimpleText(item.name or key, "BCORE.Unboxs.13", w / 2, h - BUi:Scale(34),
                    color_white, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
                draw.SimpleText("Owned: " .. owned, "BCORE.Unbox.11", w / 2, h - BUi:Scale(18),
                    ColorAlpha(colors.cwhite, 170), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
                if c > 0 then
                    draw.RoundedBox(20, w - BUi:Scale(26), BUi:Scale(6), BUi:Scale(20), BUi:Scale(20), colors.tert)
                    draw.SimpleText(tostring(c), "BCORE.Unboxb.13", w - BUi:Scale(16), BUi:Scale(16),
                        color_white, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
                end
            end)
            card:FadeHover(ColorAlpha(color_white, 20), 6, 6)

            -- Left click selects one more (capped at owned count); right click deselects one -
            -- mirrors the "click to toggle/adjust, no separate +/- buttons needed" simplicity
            -- beep-inventory's own multi-select already established, adapted for a count-based
            -- (not per-instance) inventory model.
            card:On("DoClick", function()
                local c = selected[key] or 0
                if c < owned then selected[key] = c + 1 end
                RefreshSide()
            end)
            card:On("DoRightClick", function()
                local c = selected[key] or 0
                if c > 0 then selected[key] = (c - 1 > 0) and (c - 1) or nil end
                RefreshSide()
            end)
        end
    end

    RefreshGrid()
    RefreshSide()

    -- Exposed so cl_main.lua's own single, central "BCORE:UnboxSendData" hook can refresh this
    -- page too (netstream.Hook only ever keeps ONE callback per message name - see that file's
    -- own comment about the exact duplicate-hook bug this avoids repeating).
    function BCORE.Unbox:RefreshTradeIn()
        RefreshGrid()
        RefreshSide()
    end
end
