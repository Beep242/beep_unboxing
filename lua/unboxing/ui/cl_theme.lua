-- Shared visual/formatting helpers for beep_unboxing, so new pages (Trade-In, Gambling) and the
-- existing ones stop each reinventing the same money-formatter and rarity-color table (found
-- during the rework audit: cl_dash.lua/cl_shop.lua/cl_inventory.lua/cl_unbox.lua each had their
-- own near-identical copy of both). Built on beep-framework's shared BUi:PaintCardShell/
-- BUi:FormatMoneyFull (libs/ui/cl_bui_shell.lua) - the same real house-style recipe the server
-- config panel now also draws from, instead of a third bespoke implementation.
local colors = BCORE.Unbox.config.sh.Colors

-- Thin delegate - was beep_unboxing's own hand-rolled digit-by-digit comma inserter
-- (cl_dash.lua), behaviorally identical to the shared one now that it exists.
function BCORE.Unbox:FormatMoney(n)
    return BUi:FormatMoneyFull(n)
end

-- Real, config-driven rarity colors (BCORE.Config, category "Appearance") - these used to be a
-- hardcoded table copy-pasted across cl_dash.lua/cl_shop.lua/cl_inventory.lua/cl_unbox.lua (one
-- with capitalized keys, two with lowercase - already a real inconsistency), matching neither
-- BCORE.Unbox.RarityWeights/RarityPriceMultipliers' own rarity list nor each other's casing.
-- This is the one place that table now lives; every rarity mentioned in RarityWeights/
-- RarityPriceMultipliers should have a matching entry here.
BCORE.Unbox.RarityColors = BCORE.Unbox.RarityColors or {
    common    = Color(190, 190, 190),
    uncommon  = Color(0,   200, 80),
    rare      = Color(30,  120, 255),
    epic      = Color(175, 30,  255),
    legendary = Color(255, 195, 0),
}

function BCORE.Unbox:RarityColor(rarity)
    return self.RarityColors[string.lower(rarity or "common")] or Color(190, 190, 190)
end

if BCORE and BCORE.RegisterConfig then
    local defaultRarityColors = {}
    for _, r in ipairs({ "common", "uncommon", "rare", "epic", "legendary" }) do
        defaultRarityColors[#defaultRarityColors + 1] = { rarity = r, color = BCORE.Unbox.RarityColors[r] }
    end

    BCORE:RegisterConfig("beep_unboxing", "RarityColors", {
        label = "Rarity Colors",
        category = "Appearance",
        description = "The color shown for each rarity across every Unbox page (cards, tooltips, trade-in, gambling).",
        type = "records",
        fields = {
            { key = "rarity", label = "Rarity", type = "string", default = "" },
            { key = "color", label = "Color", type = "color", default = Color(190, 190, 190) },
        },
        default = defaultRarityColors,
    })

    local function SyncRarityColors()
        local records = BCORE:GetConfig("beep_unboxing", "RarityColors")
        if not records then return end
        local rebuilt = {}
        for _, rec in ipairs(records) do
            if rec.rarity and rec.rarity ~= "" then
                rebuilt[string.lower(rec.rarity)] = rec.color or Color(190, 190, 190)
            end
        end
        if next(rebuilt) then BCORE.Unbox.RarityColors = rebuilt end
    end

    SyncRarityColors()
    hook.Add("BCORE.Config.Synced", "BCORE.Unbox.RarityColorsSynced", SyncRarityColors)
    hook.Add("BCORE.Config.ValueChanged", "BCORE.Unbox.RarityColorsChanged", function(addonId)
        if addonId == "beep_unboxing" then SyncRarityColors() end
    end)
end

--[[
    A rarity-tinted item/case card shell, built on the shared BUi:PaintCardShell - the ONE new
    piece of card-painting code this rework adds (the existing Dash/Shop/Inventory card paint
    closures are left as-is; this is for the new Trade-In/Gambling UI, which needed a card look
    from scratch anyway). Call from your own :On("Paint", function(s,w,h) ... end):
        pnl:On("Paint", function(s, w, h) BCORE.Unbox:PaintCard(w, h, rarityColor) end)
    opts (optional, passed straight through to PaintCardShell): radius, rotate, headerStrip.
]]
function BCORE.Unbox:PaintCard(w, h, rarityColor, opts)
    opts = opts or {}
    local merged = { radius = opts.radius, rotate = opts.rotate, headerStrip = opts.headerStrip }
    merged.colors = { highlight = rarityColor, highlightAlt = rarityColor }
    BUi:PaintCardShell(w, h, merged)
end

--[[
    A dark-themed "label  -  N  +" stepper row - replaces the native DNumSlider Case Battles used
    to use (and Mines now would have used too). A real, reproduced visual bug: DNumSlider is a
    stock derma control with NO styling override anywhere - it renders in GMod's default light
    grey skin, a jarring light rectangle sitting on top of this addon's dark theme, unlike every
    other control here (buttons/text entries/combos all have real Paint overrides). This is a
    plain DPanel row with two small +/- buttons instead, matching the same button language every
    other gambling page already uses.

    Returns the row panel and a getter function returning the current value.
]]
function BCORE.Unbox:MakeStepper(parent, label, min, max, default, onChange)
    local row = BUi.Create("DPanel", parent)
    row:Dock(TOP); row:DockMargin(0, 6, 0, 0); row:SetTall(BUi:Scale(26)); row:SetPaintBackground(false)

    local value = math.Clamp(default or min, min, max)
    local valueLabel

    local lbl = BUi.Create("DPanel", row)
    lbl:Dock(LEFT); lbl:SetWide(BUi:Scale(150)); lbl:SetPaintBackground(false)
    lbl:On("Paint", function(_, w, h)
        draw.SimpleText(label, "BCORE.Unboxs.13", 0, h / 2, ColorAlpha(colors.cwhite, 190), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
    end)

    local function StepBtn(sign)
        local btn = BUi.Create("DButton", row)
        btn:Dock(LEFT); btn:SetWide(BUi:Scale(26)); btn:SetText("")
        btn:ClearPaint():On("Paint", function(s, w, h)
            draw.RoundedBox(4, 0, 0, w, h, colors.light)
            draw.SimpleText(sign > 0 and "+" or "-", "BCORE.Unboxb.15", w / 2, h / 2, color_white, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        end)
        btn:FadeHover(ColorAlpha(colors.tert, 90), 4, 6)
        return btn
    end

    local down = StepBtn(-1)

    valueLabel = BUi.Create("DPanel", row)
    valueLabel:Dock(LEFT); valueLabel:SetWide(BUi:Scale(34)); valueLabel:SetPaintBackground(false)
    valueLabel:On("Paint", function(_, w, h)
        draw.SimpleText(tostring(value), "BCORE.Unboxb.14", w / 2, h / 2, color_white, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    end)

    local up = StepBtn(1)

    down:On("DoClick", function()
        value = math.max(min, value - 1)
        if onChange then onChange(value) end
    end)
    up:On("DoClick", function()
        value = math.min(max, value + 1)
        if onChange then onChange(value) end
    end)

    return row, function() return value end
end

--[[
    A dark-themed, click-and-drag horizontal slider - for a wide numeric range where a stepper
    (MakeStepper above) would need too many clicks (Dice's own "roll under" 1-99 threshold is
    exactly this case). Same reasoning as MakeStepper: this replaces a native DNumSlider, which
    has no styling override anywhere in this codebase and renders in GMod's default light grey
    skin, clashing with this addon's dark theme.

    Returns the row panel and a getter function returning the current value.
]]
function BCORE.Unbox:MakeSlider(parent, label, min, max, default, onChange)
    local row = BUi.Create("DPanel", parent)
    row:Dock(TOP); row:DockMargin(0, 6, 0, 0); row:SetTall(BUi:Scale(38)); row:SetPaintBackground(false)

    local value = math.Clamp(default or min, min, max)
    local dragging = false

    local track = BUi.Create("DPanel", row)
    track:Dock(BOTTOM); track:SetTall(BUi:Scale(14))

    local function ValueFromX(s, mx)
        local x = mx - s:LocalToScreen(0, 0)
        local frac = math.Clamp(x / s:GetWide(), 0, 1)
        return math.floor(min + frac * (max - min) + 0.5)
    end

    track:ClearPaint():On("Paint", function(s, w, h)
        draw.RoundedBox(4, 0, 0, w, h, colors.light)
        local frac = (value - min) / math.max(1, max - min)
        draw.RoundedBox(4, 0, 0, w * frac, h, colors.tert)
        local handleX = math.Clamp(w * frac, BUi:Scale(3), w - BUi:Scale(3))
        draw.RoundedBox(3, handleX - BUi:Scale(3), -BUi:Scale(2), BUi:Scale(6), h + BUi:Scale(4), color_white)
    end)
    track:On("OnMousePressed", function(s)
        dragging = true
        local x = gui.MouseX()
        value = ValueFromX(s, x)
        if onChange then onChange(value) end
    end)
    track:On("OnMouseReleased", function() dragging = false end)
    track:On("Think", function(s)
        if dragging and input.IsMouseDown(MOUSE_LEFT) then
            value = ValueFromX(s, gui.MouseX())
            if onChange then onChange(value) end
        elseif dragging then
            dragging = false
        end
    end)

    local labelRow = BUi.Create("DPanel", row)
    labelRow:Dock(TOP); labelRow:SetTall(BUi:Scale(18)); labelRow:SetPaintBackground(false)
    labelRow:On("Paint", function(_, w, h)
        draw.SimpleText(label, "BCORE.Unboxs.13", 0, h / 2, ColorAlpha(colors.cwhite, 190), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        draw.SimpleText(tostring(value), "BCORE.Unboxb.13", w, h / 2, color_white, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
    end)

    return row, function() return value end
end
