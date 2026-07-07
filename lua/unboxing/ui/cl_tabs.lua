BCORE.Unbox.Tabs = BCORE.Unbox.Tabs or {}
local colors = BCORE.Unbox.config.sh.Colors

function BCORE.Unbox:CreateButton(text, iconUrl, idet, func)
    local btn = BUi.Create("DButton", BCORE.Unbox.topbar)
    btn:Stick(LEFT, 0, 6, 10, 0, 10)
    btn:SetText("")
    btn:SetWide(BCORE.Unbox.frame:GetWide() * .092)
    btn.tab = idet

    -- tabanim: click ripple pulse (existing pattern)
    btn:SetupTransition("tabanim", 0.6, function(s)
        return BUi.Doclick(s) and math.min(s.tabanim+10,255) or math.max(s.tabanim-10,0)
    end)
    -- hov: smooth hover glow
    btn:SetupTransition("hov", 8, BUi.HoverFunc)

    btn:ClearPaint():On("Paint", function(s, w, h)
        local active = BCORE.Unbox.CurrentTab == idet

        if active then
            -- animated shimmer border
            local rot = (CurTime() * 38) % 360
            BUi.masks.Start()
            surface.SetMaterial(BUi.Grad["Right"])
            surface.SetDrawColor(colors.tert)
            surface.DrawTexturedRectRotated(w/2, h/2, w, h*2, rot)
            BUi.masks.Source()
            draw.RoundedBox(8, 0, 0, w, h, color_white)
            BUi.masks.End()

            draw.RoundedBox(8, 0, 0, w, h, colors.accent)

            -- tert→stert dual wash
            BUi.masks.Start()
            surface.SetMaterial(BUi.Grad["Right"])
            surface.SetDrawColor(ColorAlpha(colors.tert, 90))
            surface.DrawTexturedRect(0, 0, w, h)
            surface.SetMaterial(BUi.Grad["Left"])
            surface.SetDrawColor(ColorAlpha(colors.stert, 60))
            surface.DrawTexturedRect(0, 0, w, h)
            BUi.masks.Source()
            draw.RoundedBox(8, 0, 0, w, h, color_white)
            BUi.masks.End()

            draw.RoundedBox(8, 1, 1, w-2, h-2, ColorAlpha(colors.bg, 215))

            -- bottom indicator bar
            draw.RoundedBox(4, w*.18, h-4, w*.64, 3, colors.tert)
        else
            draw.RoundedBox(8, 0, 0, w, h, colors.light)
            draw.RoundedBox(8, 1, 1, w-2, h-2, colors.sec)
            if s.hov > 0.01 then
                draw.RoundedBox(8, 1, 1, w-2, h-2,
                    Color(colors.tert.r, colors.tert.g, colors.tert.b, s.hov * 22))
            end
        end

        -- icon (centred in upper portion)
        local iconSz = h * .36
        local iconX  = w/2 - iconSz/2
        local iconY  = h * .17
        BUi.DrawImgur(iconX, iconY, iconSz, iconSz, iconUrl, color_white)

        -- label
        draw.SimpleText(text, "BCORE.Unboxs.13", w/2, h * .72,
            active and color_white or ColorAlpha(colors.cwhite, 185),
            TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    end)

    btn.DoClick = func or function()
        BCORE.Unbox:SelectPage(btn.tab)
        btn.tabanim = 0
    end

    return btn
end

function BCORE.Unbox:CreatePage(tName, iconUrl)
    if BCORE.Unbox.Tabs[tName] then
        BCORE.Unbox.Tabs[tName]:Remove()
        BCORE.Unbox.Tabs[tName] = nil
    end

    local page = BUi.Create("DPanel", BCORE.Unbox.frame)
    BCORE.Unbox.Tabs[tName] = page
    page:SetVisible(false)
    page:Stick(FILL)
    page:ClearPaint()

    BCORE.Unbox:CreateButton(tName, iconUrl, tName)

    return page
end

function BCORE.Unbox:SelectPage(tName)
    for k, v in pairs(BCORE.Unbox.Tabs) do
        if not IsValid(v) then continue end
        BCORE.Unbox.CurrentTab = k == tName and k or BCORE.Unbox.CurrentTab
        v:SetVisible(k == tName)
        if v:IsVisible() then
            v:SetAlpha(0)
            v:AlphaTo(255, 0.2, 0)
        end
    end
end