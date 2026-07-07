local colors = BCORE.Unbox.config.sh.Colors
local IC      = BCORE.Unbox.Icons

--------------------------------------------------------------------------------
function BCORE.Unbox:Settings()
    local page = BCORE.Unbox:CreatePage("Settings", IC.settings)

    local scroll=BUi.Create("BUi.Scroll",page); scroll:Stick(FILL,0,8,8,8,8)
    local grid=BUi.Create("DIconLayout",scroll); grid:Stick(FILL,8)
    grid:SetSpaceX(10); grid:SetSpaceY(10)

    -- helper: animated shimmer card
    local function makeCard(W, H, title, paintBody)
        local wrap=grid:Add("DPanel"); wrap:SetSize(W, H+BUi:Scale(8)); wrap:SetPaintBackground(false)
        local card=BUi.Create("DPanel",wrap); card:SetSize(W,H); card:SetPos(0,BUi:Scale(8))
        card:SetAlpha(0); card:AlphaTo(255,0.24,0)
        card:ClearPaint():Background(colors.light,10):On("Paint", function(s,w,h)
            local rot=(CurTime()*34)%360
            BUi.masks.Start()
            surface.SetMaterial(BUi.Grad["Up"])
            surface.SetDrawColor(colors.tert)
            surface.DrawTexturedRectRotated(w/2,h/2,w,h*2,rot)
            BUi.masks.Source()
            draw.RoundedBox(10,0,0,w,h,color_white)
            BUi.masks.End()

            draw.RoundedBox(10,2,2,w-4,h-4,colors.sec)
            BUi.DrawImgur(2,2,w-4,h-4,"https://invisibalfan-ui.github.io/bui_images/images/srl54gk.png",color_white,8)

            BUi.masks.Start()
            surface.SetMaterial(BUi.Grad["Down"])
            surface.SetDrawColor(ColorAlpha(colors.tert,65))
            surface.DrawTexturedRect(0,0,w,h)
            BUi.masks.Source()
            draw.RoundedBox(10,0,0,w,h,colors.tert)
            BUi.masks.End()

            -- title bar
            draw.RoundedBox(10,2,2,w-4,BUi:Scale(32),ColorAlpha(colors.bg,185))
            draw.SimpleText(title,"BCORE.Unboxb.16",14,BUi:Scale(16),
                color_white,TEXT_ALIGN_LEFT,TEXT_ALIGN_CENTER)
            draw.RoundedBox(0,2,BUi:Scale(32),w-4,1,ColorAlpha(colors.tert,110))

            if paintBody then paintBody(s,w,h) end
        end)
        return card
    end

    -- ABOUT -------------------------------------------------------------------
    local aboutCard=makeCard(BUi:Scale(380),BUi:Scale(175),"ABOUT")
    local aBody=BUi.Create("DPanel",aboutCard)
    aBody:Dock(FILL); aBody:DockMargin(10,BUi:Scale(40),10,10); aBody:SetPaintBackground(false)
    aBody:On("Paint", function(_,w,h)
        draw.SimpleText("BCORE Unboxing System","BCORE.Unboxb.18",w/2,18,
            color_white,TEXT_ALIGN_CENTER,TEXT_ALIGN_CENTER)
        draw.SimpleText("Open cases to win items and skins.","BCORE.Unboxs.14",w/2,44,
            ColorAlpha(colors.cwhite,175),TEXT_ALIGN_CENTER,TEXT_ALIGN_CENTER)
        draw.SimpleText("Buy items directly from the Shop tab.","BCORE.Unboxs.14",w/2,64,
            ColorAlpha(colors.cwhite,175),TEXT_ALIGN_CENTER,TEXT_ALIGN_CENTER)
        draw.SimpleText("Use items from the Inventory tab.","BCORE.Unboxs.14",w/2,84,
            ColorAlpha(colors.cwhite,175),TEXT_ALIGN_CENTER,TEXT_ALIGN_CENTER)
        -- version badge
        draw.RoundedBox(6,w/2-38,104,76,BUi:Scale(22),ColorAlpha(colors.tert,175))
        draw.SimpleText("v1.0.0","BCORE.Unboxs.14",w/2,115,color_white,TEXT_ALIGN_CENTER,TEXT_ALIGN_CENTER)
    end)

    -- RARITY GUIDE ------------------------------------------------------------
    local rarities={
        {name="Common",    clr=Color(190,190,190), chance=60},
        {name="Uncommon",  clr=Color(0,  200, 80), chance=25},
        {name="Rare",      clr=Color(30, 120,255), chance=10},
        {name="Epic",      clr=Color(175, 30,255), chance= 4},
        {name="Legendary", clr=Color(255,195,  0), chance= 1},
    }
    local RH2=BUi:Scale(48 + #rarities*38)
    local rarCard=makeCard(BUi:Scale(340),RH2,"RARITY CHANCES")
    local rBody=BUi.Create("DPanel",rarCard)
    rBody:Dock(FILL); rBody:DockMargin(8,BUi:Scale(40),8,8); rBody:SetPaintBackground(false)
    rBody:On("Paint", function(_,w,h)
        for i,rd in ipairs(rarities) do
            local y=(i-1)*BUi:Scale(36)+4
            draw.RoundedBox(6,0,y,w,BUi:Scale(30),ColorAlpha(colors.bg,140))
            -- swatch
            draw.RoundedBox(4,6,y+BUi:Scale(7),BUi:Scale(16),BUi:Scale(16),rd.clr)
            draw.SimpleText(rd.name,"BCORE.Unboxs.15",BUi:Scale(30),y+BUi:Scale(15),
                color_white,TEXT_ALIGN_LEFT,TEXT_ALIGN_CENTER)
            -- bar
            local bx,bw=BUi:Scale(102),w-BUi:Scale(144)
            draw.RoundedBox(4,bx,y+BUi:Scale(11),bw,BUi:Scale(8),ColorAlpha(colors.accent,200))
            draw.RoundedBox(4,bx,y+BUi:Scale(11),rd.chance/100*bw,BUi:Scale(8),rd.clr)
            draw.SimpleText(rd.chance.."%","BCORE.Unboxs.14",
                w-6,y+BUi:Scale(15),ColorAlpha(rd.clr,215),TEXT_ALIGN_RIGHT,TEXT_ALIGN_CENTER)
        end
    end)

    -- CONTROLS ----------------------------------------------------------------
    local ctrlCard=makeCard(BUi:Scale(270),BUi:Scale(175),"CONTROLS")
    local cBody=BUi.Create("DPanel",ctrlCard)
    cBody:Dock(FILL); cBody:DockMargin(10,BUi:Scale(40),10,10); cBody:SetPaintBackground(false)
    cBody:On("Paint", function(_,w,h)
        local rows={
            {key="open_unboxing_menu", desc="Open this menu"},
            {key="Shop tab",           desc="Browse & buy items"},
            {key="Inventory tab",      desc="Use items / open cases"},
            {key="× button (qty)",     desc="Cycle purchase amount"},
        }
        for i,row in ipairs(rows) do
            local y=(i-1)*BUi:Scale(30)+4
            draw.RoundedBox(4,0,y,w,BUi:Scale(24),ColorAlpha(colors.bg,130))
            draw.RoundedBox(4,0,y,BUi:Scale(130),BUi:Scale(24),ColorAlpha(colors.tert,120))
            draw.SimpleText(row.key,"BCORE.Unboxs.12",4,y+BUi:Scale(12),
                color_white,TEXT_ALIGN_LEFT,TEXT_ALIGN_CENTER)
            draw.SimpleText(row.desc,"BCORE.Unboxs.12",BUi:Scale(136),y+BUi:Scale(12),
                ColorAlpha(colors.cwhite,175),TEXT_ALIGN_LEFT,TEXT_ALIGN_CENTER)
        end
    end)

    -- REFRESH DATA BUTTON -----------------------------------------------------
    local refWrap=grid:Add("DPanel"); refWrap:SetSize(BUi:Scale(210),BUi:Scale(72)); refWrap:SetPaintBackground(false)
    local refCard=BUi.Create("DPanel",refWrap); refCard:Dock(FILL)
    refCard:ClearPaint():Background(colors.light,10):On("Paint", function(_,w,h)
        draw.RoundedBox(10,1,1,w-2,h-2,colors.sec)
        draw.SimpleText("DATA","BCORE.Unboxs.12",w/2,18,colors.cwhite,TEXT_ALIGN_CENTER,TEXT_ALIGN_CENTER)
    end)
    local refBtn=BUi.Create("DButton",refCard)
    refBtn:Dock(FILL); refBtn:DockMargin(10,30,10,10)
    refBtn:SetText(""); refBtn:SetupTransition("hov",9,BUi.HoverFunc)
    refBtn:ClearPaint():Background(colors.light,6):On("Paint", function(s,w,h)
        BUi.masks.Start()
        surface.SetMaterial(BUi.Grad["Right"])
        surface.SetDrawColor(ColorAlpha(colors.tert,85+s.hov*28))
        surface.DrawTexturedRect(0,0,w,h)
        BUi.masks.Source()
        draw.RoundedBox(6,0,0,w,h,color_white)
        BUi.masks.End()
        draw.RoundedBox(6,1,1,w-2,h-2,colors.accent)
        draw.SimpleText("↺  REFRESH DATA","BCORE.Unboxs.14",w/2,h/2,
            color_white,TEXT_ALIGN_CENTER,TEXT_ALIGN_CENTER)
    end)
    refBtn:On("DoClick", function()
        BCORE.netstream.Start("BCORE:UnboxRequestSync",{})
        if IsValid(BCORE.Unbox.frame) then
            BCORE.Unbox:Toast("Refreshing data…","Syncing with server",colors.tert)
        end
    end)
end