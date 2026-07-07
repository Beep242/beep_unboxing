local colors = BCORE.Unbox.config.sh.Colors
local thread  = BCORE.netstream

--------------------------------------------------------------------------------
-- FONTS
--------------------------------------------------------------------------------
for i = 1, 200 do
    BUi:CreateFont("BCORE.Unbox."  .. i, "Montserrat", i, 500)
    BUi:CreateFont("BCORE.Unboxs." .. i, "Montserrat", i, 600)
    BUi:CreateFont("BCORE.Unboxb." .. i, "Montserrat", i, 1024)
end

--------------------------------------------------------------------------------
-- ICON TABLE  — replace every PLACEHOLDER_* with your own Imgur URL
--------------------------------------------------------------------------------
BCORE.Unbox.Icons = {
    exit      = "https://invisibalfan-ui.github.io/bui_images/images/0cjxwbc.png",
    search    = "https://invisibalfan-ui.github.io/bui_images/images/mkp8lur.png",
    home      = "https://invisibalfan-ui.github.io/bui_images/images/mkp8lur.png",
    shop      = "https://invisibalfan-ui.github.io/bui_images/images/mkp8lur.png",
    inventory = "https://invisibalfan-ui.github.io/bui_images/images/mkp8lur.png",
    settings  = "https://invisibalfan-ui.github.io/bui_images/images/mkp8lur.png",
    case      = "https://invisibalfan-ui.github.io/bui_images/images/mkp8lur.png",
    coin      = "https://invisibalfan-ui.github.io/bui_images/images/mkp8lur.png",
    bag       = "https://invisibalfan-ui.github.io/bui_images/images/mkp8lur.png",
    star      = "https://invisibalfan-ui.github.io/bui_images/images/mkp8lur.png",
}
local IC = BCORE.Unbox.Icons

--------------------------------------------------------------------------------
-- DATA SYNC
--------------------------------------------------------------------------------
thread.Hook("BCORE:UnboxSendData", function(data)
    LocalPlayer().BCORE_UNBOX_DATA = data or {}
    if not IsValid(BCORE.Unbox.frame) then return end
    BCORE.Unbox:RefreshShop()
    BCORE.Unbox:RefreshInventory()
    BCORE.Unbox:RefreshDash()
end)

--------------------------------------------------------------------------------
-- TOAST NOTIFICATIONS
--------------------------------------------------------------------------------
BCORE.Unbox.Toasts = BCORE.Unbox.Toasts or {}

function BCORE.Unbox:Toast(title, subtitle, clr)
    if not IsValid(BCORE.Unbox.frame) then return end
    clr = clr or colors.tert

    for i = #BCORE.Unbox.Toasts, 1, -1 do
        if not IsValid(BCORE.Unbox.Toasts[i]) then
            table.remove(BCORE.Unbox.Toasts, i)
        end
    end

    local TW, TH = BUi:Scale(268), BUi:Scale(56)
    local GAP    = BUi:Scale(6)
    local idx    = #BCORE.Unbox.Toasts + 1
    local fw     = BCORE.Unbox.frame:GetWide()
    local endX   = fw - TW - BUi:Scale(10)
    local yPos   = BUi:Scale(10) + (idx - 1) * (TH + GAP)

    local t = BUi.Create("DPanel", BCORE.Unbox.frame)
    t:SetSize(TW, TH)
    t:SetPos(fw + 20, yPos)
    t:SetZPos(9999)
    t:ClearPaint():Background(colors.light, 8):On("Paint", function(s, w, h)
        draw.RoundedBox(8, 1, 1, w-2, h-2, colors.sec)
        draw.RoundedBox(4, 1, 1, 3, h-2, clr)
        BUi.masks.Start()
        surface.SetMaterial(BUi.Grad["Right"])
        surface.SetDrawColor(ColorAlpha(clr, 20))
        surface.DrawTexturedRect(0, 0, w, h)
        BUi.masks.Source()
        draw.RoundedBox(8, 0, 0, w, h, color_white)
        BUi.masks.End()
        local ty = subtitle and h/2 - 9 or h/2
        draw.SimpleText(title, "BCORE.Unboxs.16", 14, ty,
            color_white, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        if subtitle and subtitle ~= "" then
            draw.SimpleText(subtitle, "BCORE.Unboxs.12", 14, h/2+9,
                ColorAlpha(colors.cwhite, 175), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        end
    end)

    t:MoveTo(endX, yPos, 0.2, 0, -1)
    table.insert(BCORE.Unbox.Toasts, t)

    timer.Simple(3.5, function()
        if not IsValid(t) then return end
        t:MoveTo(fw + 20, yPos, 0.2, 0, -1)
        timer.Simple(0.22, function()
            if IsValid(t) then t:Remove() end
            table.RemoveByValue(BCORE.Unbox.Toasts, t)
        end)
    end)
end

--------------------------------------------------------------------------------
-- OPEN / CLOSE
--------------------------------------------------------------------------------
function BCORE.Unbox:Open()
    if IsValid(BCORE.Unbox.frame) then
        local f = BCORE.Unbox.frame
        local px, py = f:GetPos()
        f:MoveTo(px, py + BUi:Scale(22), 0.18, 0, 1)
        f:AlphaTo(0, 0.18, 0, function() if IsValid(f) then f:Remove() end end)
        return
    end

    BCORE.Unbox.Tabs   = {}
    BCORE.Unbox.Toasts = {}

    -- FRAME ---------------------------------------------------------------
    local frame = BUi.Create("EditablePanel")
    BCORE.Unbox.frame = frame
    frame:SetSize(BUi:Scale(1420), BUi:Scale(850))
    frame:Center()
    frame:MakePopup()
    frame:ClearPaint():Shadow(255):Background(colors.light, 16)
    frame:On("Paint", function(s, w, h)
        draw.RoundedBox(16, 1, 1, w-2, h-2, colors.bg)
    end)

    local ox, oy = frame:GetPos()
    frame:SetAlpha(0)
    frame:SetPos(ox, oy + BUi:Scale(30))
    frame:AlphaTo(255, 0.22, 0)
    frame:MoveTo(ox, oy, 0.22, 0, -1)

    -- TOPBAR --------------------------------------------------------------
    local topbar = BUi.Create("DPanel", frame)
    BCORE.Unbox.topbar = topbar
    topbar:Stick(TOP, 0, 10, 10, 10, 0)
    topbar:SetTall(frame:GetTall() * .08)
    topbar:ClearPaint():Background(colors.light, 14):On("Paint", function(s, w, h)
        draw.RoundedBox(14, 1, 1, w-2, h-2, colors.sec)
    end)

    -- EXIT ----------------------------------------------------------------
    local exit = BUi.Create("DButton", topbar)
    topbar.exit = exit
    exit:Stick(RIGHT, 10)
    exit:SetWide(BUi:Scale(50))
    exit:SetText("")
    exit:ClearPaint():Background(Color(56,56,56,200), 5):FadeIn(0.5)
    exit:On("Paint", function(s, w, h)
        draw.RoundedBox(5, 1, 1, w-2, h-2, colors.accent)
        BUi.DrawImgur(0, 0, w, h, IC.exit, color_white)
    end)
    exit:FadeHover(Color(130, 0, 0, 110), 6, 8)
    exit:On("DoClick", function() BCORE.Unbox:Open() end)

    -- LOGO ----------------------------------------------------------------
    local logo = BUi.Create("DPanel", topbar)
    logo:Stick(LEFT, 0, 10, 8, 0, 8)
    logo:SetWide(BUi:Scale(148))
    logo:ClearPaint():On("Paint", function(s, w, h)
        local rot = (CurTime() * 26) % 360
        BUi.masks.Start()
        surface.SetMaterial(BUi.Grad["Right"])
        surface.SetDrawColor(ColorAlpha(colors.tert, 90))
        surface.DrawTexturedRectRotated(w/2, h/2, w*2, h*2, rot)
        BUi.masks.Source()
        draw.RoundedBox(10, 0, 0, w, h, color_white)
        BUi.masks.End()
        draw.RoundedBox(10, 0, 0, w, h, ColorAlpha(colors.tert, 22))
        draw.RoundedBox(10, 1, 1, w-2, h-2, colors.sec)
        draw.SimpleText("UNBOX",  "BCORE.Unboxb.22", w/2, h/2 - 9,
            colors.tert,   TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        draw.SimpleText("SYSTEM", "BCORE.Unboxs.12", w/2, h/2 + 9,
            colors.cwhite, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    end)

    -- SEARCH --------------------------------------------------------------
    local sh = BUi.Create("DPanel", topbar)
    sh:Stick(LEFT, 0, 8, 8, 0, 8)
    sh:SetWide(topbar:GetWide() * .18)
    sh:ClearPaint():Background(colors.light, 8):On("Paint", function(s, w, h)
        draw.RoundedBox(8, 1, 1, w-2, h-2, colors.accent)
        BUi.DrawImgur(h*.15, h*.15, h*.7, h*.7, IC.search, color_white)
    end)
    sh:DockPadding(40, 0, 6, 0)

    BCORE.Unbox.search = BUi.Create("DTextEntry", sh)
    BCORE.Unbox.search:Stick(FILL)
    BCORE.Unbox.search:ReadyTextbox()
    BCORE.Unbox.search:SetPlaceholderText("Search items…")
    BCORE.Unbox.search:SetFont("BCORE.Unboxs.16")
    BCORE.Unbox.search:SetTextColor(colors.cwhite)
    BCORE.Unbox.search:SetCursorColor(colors.tert)
    BCORE.Unbox.search:On("OnChange", function() BCORE.Unbox:RefreshShop() end)

    -- BALANCE -------------------------------------------------------------
    local bal = BUi.Create("DPanel", topbar)
    bal:Stick(LEFT, 0, 8, 8, 0, 8)
    bal:SetWide(BUi:Scale(160))
    bal:ClearPaint():Background(colors.light, 8):On("Paint", function(s, w, h)
        draw.RoundedBox(8, 1, 1, w-2, h-2, colors.accent)
        local money = 0
        local lp = LocalPlayer and IsValid(LocalPlayer()) and LocalPlayer() or nil
        if lp and lp.getDarkRPVar then money = lp:getDarkRPVar("money") or 0 end
        local n, res, ct = tostring(math.floor(money)), "", 0
        for i = #n, 1, -1 do
            ct = ct + 1; res = n:sub(i,i)..res
            if ct%3==0 and i>1 then res = ","..res end
        end
        BUi.DrawImgur(5, h*.18, h*.64, h*.64, IC.coin, colors.moneygreen)
        draw.SimpleText("BALANCE", "BCORE.Unboxs.11", w/2+10, h/2-9,
            ColorAlpha(colors.cwhite, 150), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        draw.SimpleText("$"..res, "BCORE.Unboxs.17", w/2+10, h/2+9,
            colors.moneygreen, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    end)

    -- ADMIN BUTTON (only visible to admins) --------------------------------
    local function isLocalAdmin()
        local lp = LocalPlayer and IsValid(LocalPlayer()) and LocalPlayer() or nil
        if not lp then return false end
        if lp:IsSuperAdmin() then return true end
        for _, g in ipairs((BCORE.Inventory and BCORE.Inventory.config and
                             BCORE.Inventory.config.Admins) or {}) do
            if lp:IsUserGroup(g) then return true end
        end
        return false
    end

    if isLocalAdmin() then
        local adminBtn = BUi.Create("DButton", topbar)
        adminBtn:Stick(LEFT, 0, 8, 10, 0, 10)
        adminBtn:SetWide(BUi:Scale(90))
        adminBtn:SetText("")
        adminBtn:SetupTransition("hov", 9, BUi.HoverFunc)
        adminBtn:ClearPaint():Background(colors.light, 7):On("Paint", function(s, w, h)
            local rot = (CurTime() * 40) % 360
            BUi.masks.Start()
            surface.SetMaterial(BUi.Grad["Right"])
            surface.SetDrawColor(Color(220, 60, 60))
            surface.DrawTexturedRectRotated(w/2, h/2, w, h*2, rot)
            BUi.masks.Source()
            draw.RoundedBox(8, 0, 0, w, h, color_white)
            BUi.masks.End()
            draw.RoundedBox(8, 0, 0, w, h,
                ColorAlpha(Color(220,60,60), 22 + s.hov * 20))
            draw.RoundedBox(8, 1, 1, w-2, h-2, colors.sec)
            draw.SimpleText("ADMIN", "BCORE.Unboxb.15", w/2, h/2,
                Color(220, 60, 60), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        end)
        adminBtn:FadeHover(Color(255, 0, 0, 35), 8, 10)
        adminBtn:On("DoClick", function()
            BCORE.Unbox:OpenUnboxAdmin()
        end)
    end

    -- BUILD PAGES ---------------------------------------------------------
    BCORE.Unbox:Dash()
    BCORE.Unbox:Shop()
    BCORE.Unbox:Inventory()
    BCORE.Unbox:Settings()
    BCORE.Unbox:SelectPage("Home")

    thread.Start("BCORE:UnboxRequestSync", {})
end

concommand.Add("open_unboxing_menu", function() BCORE.Unbox:Open() end)