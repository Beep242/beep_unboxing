local colors = BCORE.Unbox.config.sh.Colors
local IC      = BCORE.Unbox.Icons

local function rc(r)
    local t={common=Color(190,190,190),uncommon=Color(0,200,80),rare=Color(30,120,255),
             epic=Color(175,30,255),legendary=Color(255,195,0)}
    return t[string.lower(r or "common")] or Color(190,190,190)
end
local function fmt(n)
    if not n then return "$0" end
    n=math.floor(tonumber(n) or 0)
    local s,res,c=tostring(n),"",0
    for i=#s,1,-1 do c=c+1;res=s:sub(i,i)..res; if c%3==0 and i>1 then res=","..res end end
    return "$"..res
end

--------------------------------------------------------------------------------
function BCORE.Unbox:Dash()
    local dash = BCORE.Unbox:CreatePage("Home", IC.home)
    BCORE.Unbox.dash = dash
    BCORE.Unbox:SelectPage("Home")

    local FW = BCORE.Unbox.frame:GetWide()
    local FH = BCORE.Unbox.frame:GetTall()

    -- HERO PANEL (left 52%) --------------------------------------------------
    local hero = BUi.Create("DPanel", dash)
    hero:Stick(LEFT, 0, 8, 8, 0, 8)
    hero:SetWide(FW * .52)
    hero:ClearPaint():Background(colors.light, 12):On("Paint", function(s,w,h)
        local rot=(CurTime()*22)%360
        BUi.masks.Start()
        surface.SetMaterial(BUi.Grad["Up"])
        surface.SetDrawColor(colors.tert)
        surface.DrawTexturedRectRotated(w/2,h/2,w,h*2,rot)
        BUi.masks.Source()
        draw.RoundedBox(12,0,0,w,h,color_white)
        BUi.masks.End()

        draw.RoundedBox(12,2,2,w-4,h-4,colors.sec)
        BUi.DrawImgur(2,2,w-4,h-4,"https://invisibalfan-ui.github.io/bui_images/images/srl54gk.png",color_white,10)

        BUi.masks.Start()
        surface.SetMaterial(BUi.Grad["Down"])
        surface.SetDrawColor(ColorAlpha(colors.tert,70))
        surface.DrawTexturedRect(0,0,w,h)
        BUi.masks.Source()
        draw.RoundedBox(12,0,0,w,h,colors.tert)
        BUi.masks.End()

        -- bottom fade for text
        BUi.masks.Start()
        surface.SetMaterial(BUi.Grad["Up"])
        surface.SetDrawColor(Color(0,0,0,210))
        surface.DrawTexturedRect(0,h*0.56,w,h*0.44)
        BUi.masks.Source()
        draw.RoundedBox(12,0,0,w,h,color_white)
        BUi.masks.End()

        -- "FEATURED" badge
        draw.RoundedBox(6,16,14,BUi:Scale(80),BUi:Scale(20),ColorAlpha(colors.tert,200))
        draw.SimpleText("FEATURED","BCORE.Unboxs.12",16+BUi:Scale(40),14+BUi:Scale(10),
            color_white,TEXT_ALIGN_CENTER,TEXT_ALIGN_CENTER)

        -- case name from live data
        local data=LocalPlayer().BCORE_UNBOX_DATA or {}
        local cname,cdef="MYSTERY CASE",{}
        for k,v in pairs(data.caseDefs or {}) do cname=v.Name or k; cdef=v; break end

        draw.SimpleText(string.upper(cname),"BCORE.Unboxb.32",w/2,h-78,
            color_white,TEXT_ALIGN_CENTER,TEXT_ALIGN_CENTER)
        draw.SimpleText("Open to win exclusive weapon skins & items","BCORE.Unboxs.14",w/2,h-50,
            ColorAlpha(color_white,175),TEXT_ALIGN_CENTER,TEXT_ALIGN_CENTER)
        draw.SimpleText(fmt(cdef.Price),"BCORE.Unboxb.24",w/2,h-24,
            colors.moneygreen,TEXT_ALIGN_CENTER,TEXT_ALIGN_CENTER)
    end)

    -- hero model
    local hmdl=BUi.Create("DModelPanel",hero)
    hmdl:Dock(FILL); hmdl:DockMargin(24,60,24,130)
    hmdl:SetModel("models/props_c17/oildrum001.mdl")
    hmdl:SetCamPos(Vector(80,50,30)); hmdl:SetLookAt(Vector(0,0,15))
    hmdl.LayoutEntity=function(_,ent) ent:SetAngles(Angle(0,CurTime()*20,0)) end

    -- RIGHT SIDE --------------------------------------------------------------
    local right=BUi.Create("DPanel",dash)
    right:Stick(FILL,0,0,8,8,8); right:ClearPaint()

    -- STATS CARD
    local stats=BUi.Create("DPanel",right)
    stats:Stick(TOP,0,0,0,0,8); stats:SetTall(BUi:Scale(90))
    stats:ClearPaint():Background(colors.light,10):On("Paint", function(_,w,h)
        draw.RoundedBox(10,1,1,w-2,h-2,colors.sec)
        local data=LocalPlayer().BCORE_UNBOX_DATA or {}
        local ii,ci,val=0,0,0
        local pr=data.prices or {}
        for k,v in pairs(data.inventory or {}) do
            ii=ii+v; if pr[k] then val=val+pr[k]*v end
        end
        for _,v in pairs(data.cases or {}) do ci=ci+v end
        local cols={
            {lbl="ITEMS", val=tostring(ii), clr=colors.tert       },
            {lbl="CASES", val=tostring(ci), clr=Color(30,120,255) },
            {lbl="VALUE", val=fmt(val),     clr=colors.moneygreen  },
        }
        local cw=w/#cols
        for i,col in ipairs(cols) do
            local x=(i-1)*cw
            if i>1 then draw.RoundedBox(0,x,14,1,h-28,ColorAlpha(colors.light,200)) end
            draw.SimpleText(col.lbl,"BCORE.Unboxs.13",x+cw/2,h/2-11,
                colors.cwhite,TEXT_ALIGN_CENTER,TEXT_ALIGN_CENTER)
            draw.SimpleText(col.val,"BCORE.Unboxb.22",x+cw/2,h/2+11,
                col.clr,TEXT_ALIGN_CENTER,TEXT_ALIGN_CENTER)
        end
    end)

    -- CASES HEADER
    local chead=BUi.Create("DPanel",right)
    chead:Stick(TOP,0,0,0,0,4); chead:SetTall(BUi:Scale(26))
    chead:SetPaintBackground(false)
    chead:On("Paint", function(_,w,h)
        draw.SimpleText("AVAILABLE CASES","BCORE.Unboxb.17",8,h/2,
            colors.tert,TEXT_ALIGN_LEFT,TEXT_ALIGN_CENTER)
        draw.RoundedBox(0,0,h-2,w,1,ColorAlpha(colors.tert,80))
    end)

    -- CASES GRID
    local cscroll=BUi.Create("BUi.Scroll",right); cscroll:Stick(FILL)
    local cgrid=BUi.Create("DIconLayout",cscroll)
    cgrid:Stick(FILL,6); cgrid:SetSpaceX(8); cgrid:SetSpaceY(14)
    BCORE.Unbox.DashGrid=cgrid
    BCORE.Unbox:RefreshDash()
end

--------------------------------------------------------------------------------
function BCORE.Unbox:RefreshDash()
    if not IsValid(BCORE.Unbox.DashGrid) then return end
    local grid=BCORE.Unbox.DashGrid; grid:Clear()

    local data=LocalPlayer().BCORE_UNBOX_DATA or {}
    local defs=data.caseDefs or {}
    local CW,CH=BUi:Scale(218),BUi:Scale(195)
    local LIFT=BUi:Scale(8)
    local idx=0

    if not next(defs) then
        local ph=grid:Add("DPanel"); ph:SetSize(BUi:Scale(260),BUi:Scale(90))
        ph:SetPaintBackground(false)
        local s=BUi.Create("DPanel",ph); s:Dock(FILL); s:ClearPaint()
        s:On("Paint", function(_,w,h)
            draw.RoundedBox(10,1,1,w-2,h-2,colors.sec)
            draw.SimpleText("No cases configured.","BCORE.Unboxs.16",
                w/2,h/2,colors.cwhite,TEXT_ALIGN_CENTER,TEXT_ALIGN_CENTER)
        end)
        return
    end

    for cname,cdef in pairs(defs) do
        idx=idx+1
        local tclr=colors.tert
        if cdef.Rarity then tclr=rc(cdef.Rarity) end

        local wrap=grid:Add("DPanel"); wrap:SetSize(CW,CH+LIFT); wrap:SetPaintBackground(false)
        local card=BUi.Create("DPanel",wrap); card:SetSize(CW,CH); card:SetPos(0,LIFT)
        card:SetAlpha(0)
        card:SetupTransition("hov",10,BUi.HoverFuncChild)
        card:On("Think", function(s) s:SetPos(0,LIFT-math.floor(s.hov*LIFT)) end)
        timer.Simple((idx-1)*0.04, function()
            if IsValid(card) then card:AlphaTo(255,0.24,0) end
        end)

        card:ClearPaint():Background(colors.light,10):On("Paint", function(s,w,h)
            local rot=(CurTime()*26)%360
            if s.hov>0.02 then draw.RoundedBox(10,3,5,w-6,h-2,Color(0,0,0,s.hov*62)) end

            BUi.masks.Start()
            surface.SetMaterial(BUi.Grad["Down"])
            surface.SetDrawColor(ColorAlpha(tclr,70+s.hov*25))
            surface.DrawTexturedRectRotated(w/2,h/2,w,h*2,rot)
            BUi.masks.Source()
            draw.RoundedBox(10,0,0,w,h,color_white)
            BUi.masks.End()

            draw.RoundedBox(10,2,2,w-4,h-4,colors.sec)
            BUi.DrawImgur(2,2,w-4,h-4,"https://invisibalfan-ui.github.io/bui_images/images/srl54gk.png",color_white,8)

            BUi.masks.Start()
            surface.SetMaterial(BUi.Grad["Down"])
            surface.SetDrawColor(ColorAlpha(tclr,70))
            surface.DrawTexturedRect(0,0,w,h)
            BUi.masks.Source()
            draw.RoundedBox(10,0,0,w,h,tclr)
            BUi.masks.End()

            -- lower info gradient
            BUi.masks.Start()
            surface.SetMaterial(BUi.Grad["Up"])
            surface.SetDrawColor(Color(0,0,0,205))
            surface.DrawTexturedRect(0,h*0.54,w,h*0.46)
            BUi.masks.Source()
            draw.RoundedBox(10,0,0,w,h,color_white)
            BUi.masks.End()

            -- rarity badge
            if cdef.Rarity then
                draw.RoundedBox(6,8,10,BUi:Scale(70),BUi:Scale(18),ColorAlpha(tclr,190))
                draw.SimpleText(string.upper(cdef.Rarity),"BCORE.Unboxs.11",
                    8+BUi:Scale(35),19,color_white,TEXT_ALIGN_CENTER,TEXT_ALIGN_CENTER)
            end

            draw.SimpleText(cdef.Name or cname,"BCORE.Unboxb.20",
                w/2,h-50,color_white,TEXT_ALIGN_CENTER,TEXT_ALIGN_CENTER)
            draw.SimpleText(fmt(cdef.Price),"BCORE.Unboxs.16",
                w/2,h-28,colors.moneygreen,TEXT_ALIGN_CENTER,TEXT_ALIGN_CENTER)
        end)

        -- model
        local mdl=BUi.Create("DModelPanel",card)
        mdl:SetPos(BUi:Scale(10),BUi:Scale(20)); mdl:SetSize(CW-BUi:Scale(20),BUi:Scale(94))
        mdl:SetModel("models/props_c17/oildrum001.mdl")
        mdl:SetCamPos(Vector(60,40,25)); mdl:SetLookAt(Vector(0,0,10))
        mdl.LayoutEntity=function(_,ent) ent:SetAngles(Angle(0,CurTime()*22,0)) end

        -- shop button
        local sb=BUi.Create("DButton",card)
        sb:SetPos(BUi:Scale(10),BUi:Scale(158)); sb:SetSize(CW-BUi:Scale(20),BUi:Scale(28))
        sb:SetText(""); sb:SetupTransition("hov",9,BUi.HoverFunc)
        sb:ClearPaint():Background(colors.light,6):On("Paint", function(s,w,h)
            draw.RoundedBox(6,1,1,w-2,h-2,Color(tclr.r,tclr.g,tclr.b,195+s.hov*35))
            draw.SimpleText("VIEW IN SHOP  →","BCORE.Unboxs.13",w/2,h/2,
                color_white,TEXT_ALIGN_CENTER,TEXT_ALIGN_CENTER)
        end)
        sb:On("DoClick", function() BCORE.Unbox:SelectPage("Shop") end)
    end
end