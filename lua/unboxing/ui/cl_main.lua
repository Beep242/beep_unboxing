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
    exit      = "https://beep242.github.io/bui_images/images/0cjxwbc.png",
    search    = "https://beep242.github.io/bui_images/images/mkp8lur.png",
    home      = "https://beep242.github.io/bui_images/images/mkp8lur.png",
    shop      = "https://beep242.github.io/bui_images/images/mkp8lur.png",
    inventory = "https://beep242.github.io/bui_images/images/mkp8lur.png",
    settings  = "https://beep242.github.io/bui_images/images/mkp8lur.png",
    case      = "https://beep242.github.io/bui_images/images/mkp8lur.png",
    coin      = "https://beep242.github.io/bui_images/images/mkp8lur.png",
    bag       = "https://beep242.github.io/bui_images/images/mkp8lur.png",
    star      = "https://beep242.github.io/bui_images/images/mkp8lur.png",
    tradein   = "https://beep242.github.io/bui_images/images/mkp8lur.png",
    gambling  = "https://beep242.github.io/bui_images/images/mkp8lur.png",
}
local IC = BCORE.Unbox.Icons

--------------------------------------------------------------------------------
-- DATA SYNC
--
-- The ONE place this net message is handled - netstream.Hook keeps a single slot
-- per message name (netstream.stored[name] = Callback), so registering it more than
-- once anywhere else doesn't add a second listener, it silently REPLACES whichever
-- one loaded first. cl_shop.lua and cl_networking.lua both used to register their own
-- copy of this same hook; whichever one happened to load last was winning and the
-- other(s)' logic never ran at all - in practice this meant the shop's own cache-key
-- reset below was getting silently dropped, so a player who opened the store before
-- the server's data had arrived would see the "Waiting for server data…" placeholder
-- forever, since nothing ever told RefreshShop() to actually rebuild once real data
-- showed up. Refreshing unconditionally (not gated on which specific tab is visible
-- right now) means every page is already correct the instant the player switches to
-- it, rather than depending on the data happening to arrive while that exact tab is
-- on screen.
--------------------------------------------------------------------------------
thread.Hook("BCORE:UnboxSendData", function(data)
    LocalPlayer().BCORE_UNBOX_DATA = data or {}
    BCORE.Unbox._shopCacheKey = nil
    if not IsValid(BCORE.Unbox.frame) then return end
    BCORE.Unbox:RefreshShop()
    BCORE.Unbox:RefreshInventory()
    BCORE.Unbox:RefreshDash()
    if BCORE.Unbox.RefreshTradeIn then BCORE.Unbox:RefreshTradeIn() end
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
-- parent (optional): when nil, behaves exactly as before - a standalone, draggable, MakePopup'd
-- floating frame the player can toggle open/closed (used by the concommand/chat-command entry
-- points below). When given a real panel (beep-f4's own Unboxing tab, see beep-f4's
-- cl_unbox_tab.lua), this whole UI is built AS A CHILD of it instead - Dock(FILL)'d into the
-- tab's own page, no MakePopup (F4's own frame already owns input capture for its whole
-- hierarchy), no drag/fade-in animation, and no own exit button (F4's sidebar/exit already
-- covers "leave this screen"). Every existing internal size/position call below (topbar's own
-- frame:GetTall()-relative sizing, Toast's frame:GetWide(), etc.) reads real numbers either way,
-- since the embedded case still calls frame:SetSize(...) explicitly up front rather than relying
-- on Dock(FILL)'s own layout timing.
function BCORE.Unbox:Open(parent)
    local wantEmbedded = parent ~= nil

    -- REGRESSION FIX: BCORE.Unbox.frame is one shared reference for BOTH the standalone popup
    -- and an F4-embedded instance. Once F4's own Unbox tab had been opened at least once (see
    -- cl_unbox_tab.lua), this reference pointed at the EMBEDDED frame - so typing !unbox
    -- afterward hit this toggle-close branch against THAT frame instead of opening a real
    -- standalone popup, silently animating the F4 tab's own content closed instead. The toggle-
    -- close gesture only makes sense against an existing STANDALONE frame; an embedded one should
    -- just be left alone while a real standalone popup gets built fresh below.
    if not wantEmbedded and IsValid(BCORE.Unbox.frame) and not BCORE.Unbox.frameIsEmbedded then
        local f = BCORE.Unbox.frame
        local px, py = f:GetPos()
        f:MoveTo(px, py + BUi:Scale(22), 0.18, 0, 1)
        f:AlphaTo(0, 0.18, 0, function() if IsValid(f) then f:Remove() end end)
        return
    end

    -- Only remove the previous frame when replacing one of the SAME kind - an F4-embedded
    -- instance and a standalone popup are different UI contexts and are allowed to coexist
    -- (e.g. F4's Unbox tab was opened earlier, then !unbox is typed later - the embedded one is
    -- simply left running, orphaned from this reference but still fully valid inside F4).
    if IsValid(BCORE.Unbox.frame) and BCORE.Unbox.frameIsEmbedded == wantEmbedded then
        BCORE.Unbox.frame:Remove()
    end

    BCORE.Unbox.Tabs   = {}
    BCORE.Unbox.Toasts = {}

    -- FRAME ---------------------------------------------------------------
    local frame = BUi.Create("EditablePanel", parent)
    BCORE.Unbox.frame = frame
    BCORE.Unbox.frameIsEmbedded = wantEmbedded

    if parent then
        frame:SetSize(parent:GetWide(), parent:GetTall())
        frame:Dock(FILL)
    else
        frame:SetSize(BUi:Scale(1420), BUi:Scale(850))
        frame:Center()
        frame:MakePopup()
    end

    frame:ClearPaint():Shadow(255):Background(colors.light, 16)
    frame:On("Paint", function(s, w, h)
        draw.RoundedBox(16, 1, 1, w-2, h-2, colors.bg)
    end)

    if not parent then
        local ox, oy = frame:GetPos()
        frame:SetAlpha(0)
        frame:SetPos(ox, oy + BUi:Scale(30))
        frame:AlphaTo(255, 0.22, 0)
        frame:MoveTo(ox, oy, 0.22, 0, -1)
    end

    -- TOPBAR --------------------------------------------------------------
    local topbar = BUi.Create("DPanel", frame)
    BCORE.Unbox.topbar = topbar
    topbar:Stick(TOP, 0, 10, 10, 10, 0)
    topbar:SetTall(frame:GetTall() * .08)
    topbar:ClearPaint():Background(colors.light, 14):On("Paint", function(s, w, h)
        draw.RoundedBox(14, 1, 1, w-2, h-2, colors.sec)
    end)

    -- EXIT (standalone popup only - embedded in F4, the sidebar tabs/exit already do this) -----
    if not parent then
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
    end

    -- LOGO ----------------------------------------------------------------
    -- Shrunk from 148 - with Trade-In and Gambling added to the tab bar (now 6 tabs, each
    -- frame:GetWide()*.092 wide - see CreateButton, cl_tabs.lua), the topbar's fixed-width
    -- elements (this logo + search + balance + admin button) no longer left enough room for the
    -- last tab (Gambling) to fit without getting clipped/pushed past the topbar's own edge.
    local logo = BUi.Create("DPanel", topbar)
    logo:Stick(LEFT, 0, 10, 8, 0, 8)
    logo:SetWide(BUi:Scale(86))
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
        draw.SimpleText("UNBOX",  "BCORE.Unboxb.15", w/2, h/2 - 7,
            colors.tert,   TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        draw.SimpleText("SYSTEM", "BCORE.Unboxs.9", w/2, h/2 + 7,
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
    -- Used to read BCORE.Inventory.config.Admins (the wrong addon's admin list, and one that
    -- doesn't exist if beep-inventory isn't installed) - now uses the shared config admin gate.
    local function isLocalAdmin()
        if BCORE.IsConfigAdmin then
            return BCORE:IsConfigAdmin(LocalPlayer())
        end
        return IsValid(LocalPlayer()) and LocalPlayer():IsSuperAdmin() or false
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
    BCORE.Unbox:TradeIn()
    BCORE.Unbox:Gambling()
    BCORE.Unbox:SelectPage("Home")

    thread.Start("BCORE:UnboxRequestSync", {})
end

concommand.Add("open_unboxing_menu", function() BCORE.Unbox:Open() end)

-- Same pattern as beep-framework's !config chat command - open to everyone (unlike !config,
-- this menu has no admin gate at all), suppressed from actually appearing in chat.
hook.Add("OnPlayerChat", "BCORE.Unbox.ChatCommand", function(ply, text)
    if ply ~= LocalPlayer() then return end
    if string.Trim(string.lower(text)) ~= "!unbox" then return end

    BCORE.Unbox:Open()

    return true
end)