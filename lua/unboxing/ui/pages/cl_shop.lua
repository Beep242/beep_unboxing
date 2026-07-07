local colors = BCORE.Unbox.config.sh.Colors
local thread  = BCORE.netstream
local IC      = BCORE.Unbox.Icons

local RCLR = {
    common    = Color(190,190,190),
    uncommon  = Color(0,  200, 80),
    rare      = Color(30, 120,255),
    epic      = Color(175, 30,255),
    legendary = Color(255,195,  0),
}

function FixButton(btn)
    if not IsValid(btn) then return end
    btn:SetMouseInputEnabled(true)
    btn:SetKeyboardInputEnabled(false)
end

local RORDER = {"legendary","epic","rare","uncommon","common"}
local function rc(r) return RCLR[string.lower(r or "common")] or Color(190,190,190) end
local function fmt(n)
    if not n then return "$0" end
    n = math.floor(tonumber(n) or 0)
    local s,res,c = tostring(n),"",0
    for i=#s,1,-1 do c=c+1; res=s:sub(i,i)..res; if c%3==0 and i>1 then res=","..res end end
    return "$"..res
end
local function prettyKey(key)
    if not key or key=="" then return "Unknown" end
    return key:gsub("^weapon_",""):gsub("^swep_",""):gsub("^npc_","")
               :gsub("_"," "):gsub("(%a)([%w_']*)",function(f,r) return f:upper()..r end)
end
local function getDisplayName(item, key)
    local n = type(item.name)=="string" and item.name~="" and item.name or nil
    if n and n:lower()==(key or ""):lower() then n=nil end
    return n or prettyKey(item.class or key)
end
local function getWeaponIcon(item)
    if not item.class then return nil end
    local sw = weapons.GetStored(item.class)
    if not sw then return nil end
    local mat = sw.WepSelectIcon
    if not mat then return nil end
    if type(mat) == "string" then mat = Material(mat, "noclamp smooth") end
    if type(mat) == "userdata" then
        local ok, bad = pcall(function() return mat:IsError() end)
        if ok and not bad then return mat end
    end
    return nil
end

-- soldInStore = nil/true → shown by default
-- soldInStore = false    → admin explicitly hid it
local function isForSale(item)
    return item.soldInStore ~= false
end

local S  = { filter="all", qty={} }
local QO = {1,5,10,25,50}

thread.Hook("BCORE:UnboxSendData", function(data)
    LocalPlayer().BCORE_UNBOX_DATA = data or {}
    BCORE.Unbox._shopCacheKey = nil
    if IsValid(BCORE.Unbox.ShopScroll) and BCORE.Unbox.ShopScroll:IsVisible() then
        timer.Create("BCORE.Shop.Refresh", 0.3, 1, function()
            if IsValid(BCORE.Unbox.ShopScroll) then BCORE.Unbox:RefreshShop() end
        end)
    end
end)

concommand.Add("shopdbg", function()
    local data = LocalPlayer().BCORE_UNBOX_DATA
    if not data then print("[ShopDBG] BCORE_UNBOX_DATA is nil"); return end
    local shown, hidden = 0, 0
    for k, v in pairs(data.items or {}) do
        if isForSale(v) then shown=shown+1
        else hidden=hidden+1 end
    end
    print(string.format("[ShopDBG] items=%d shown=%d hidden=%d  cases=%d",
        table.Count(data.items or {}), shown, hidden, table.Count(data.caseDefs or {})))
    -- print first hidden item so we know why
    for k,v in pairs(data.items or {}) do
        if not isForSale(v) then
            print("  sample hidden: "..k.."  soldInStore="..tostring(v.soldInStore))
            break
        end
    end
end)

--------------------------------------------------------------------------------
function BCORE.Unbox:Shop()
    local shop = BCORE.Unbox:CreatePage("Shop", IC.shop)

    local sidebar = BUi.Create("DPanel", shop)
    sidebar:Stick(LEFT,0,8,8,0,8); sidebar:SetWide(BUi:Scale(126))
    sidebar:ClearPaint():Background(colors.light,10):On("Paint", function(s,w,h)
        draw.RoundedBox(10,1,1,w-2,h-2,colors.sec)
        draw.SimpleText("FILTER","BCORE.Unboxs.13",w/2,22,colors.cwhite,TEXT_ALIGN_CENTER,TEXT_ALIGN_CENTER)
        draw.RoundedBox(0,12,36,w-24,1,ColorAlpha(colors.tert,100))
    end)
    sidebar:DockPadding(0,44,0,8)

    for _,fd in ipairs({
        {id="all",      label="ALL",       clr=colors.tert    },
        {id="cases",    label="CASES",     clr=Color(255,140, 0)},
        {id="legendary",label="LEGENDARY", clr=rc("legendary")},
        {id="epic",     label="EPIC",      clr=rc("epic")     },
        {id="rare",     label="RARE",      clr=rc("rare")     },
        {id="uncommon", label="UNCOMMON",  clr=rc("uncommon") },
        {id="common",   label="COMMON",    clr=rc("common")   },
    }) do
        local fid,fclr = fd.id,fd.clr
        local fb = BUi.Create("DButton",sidebar)
        fb:Dock(TOP); fb:DockMargin(8,6,8,0); fb:SetTall(BUi:Scale(32)); fb:SetText("")
        fb:SetupTransition("hov",9,BUi.HoverFunc)
        fb:ClearPaint():On("Paint", function(s,w,h)
            local on = S.filter==fid
            if on then
                BUi.masks.Start()
                surface.SetMaterial(BUi.Grad["Right"])
                surface.SetDrawColor(ColorAlpha(fclr,65))
                surface.DrawTexturedRect(0,0,w,h)
                BUi.masks.Source()
                draw.RoundedBox(7,0,0,w,h,color_white)
                BUi.masks.End()
                draw.RoundedBox(7,0,0,w,h,ColorAlpha(fclr,38))
                draw.RoundedBox(7,1,1,w-2,h-2,ColorAlpha(fclr,18))
                draw.RoundedBox(3,0,h*.2,3,h*.6,fclr)
            else
                draw.RoundedBox(7,0,0,w,h,colors.accent)
                if s.hov>0.01 then
                    draw.RoundedBox(7,0,0,w,h,Color(fclr.r,fclr.g,fclr.b,s.hov*26))
                end
            end
            draw.SimpleText(fd.label,"BCORE.Unboxs.12",w/2,h/2,
                on and color_white or ColorAlpha(colors.cwhite,195),
                TEXT_ALIGN_CENTER,TEXT_ALIGN_CENTER)
        end)
        fb:On("DoClick", function()
            S.filter=fid
            BCORE.Unbox._shopCacheKey=nil
            BCORE.Unbox:RefreshShop()
        end)
    end

    local main = BUi.Create("DPanel",shop)
    main:Stick(FILL,0,0,8,8,8); main:ClearPaint()

    local countBar = BUi.Create("DPanel",main)
    countBar:Stick(TOP,0,0,0,0,0); countBar:SetTall(BUi:Scale(26))
    countBar:SetPaintBackground(false)
    countBar:On("Paint", function(_,w,h)
        local data   = LocalPlayer().BCORE_UNBOX_DATA or {}
        local search = IsValid(BCORE.Unbox.search) and
            string.lower(BCORE.Unbox.search:GetValue() or "") or ""
        local n = 0
        if S.filter == "cases" then
            for _,case in pairs(data.caseDefs or {}) do
                if case.Price and case.Price > 0 then n=n+1 end
            end
        else
            for _,item in pairs(data.items or {}) do
                if isForSale(item) then
                    local r = string.lower(item.rarity or "common")
                    if S.filter=="all" or r==S.filter then
                        if search=="" or string.find(string.lower(item.name or ""),search,1,true) then
                            n=n+1
                        end
                    end
                end
            end
        end
        draw.SimpleText(n.." item"..(n~=1 and "s" or "").." in shop",
            "BCORE.Unboxs.14",4,h/2,colors.cwhite,TEXT_ALIGN_LEFT,TEXT_ALIGN_CENTER)
    end)

    local scroll = BUi.Create("BUi.Scroll",main); scroll:Stick(FILL)
    BCORE.Unbox.ShopGrid   = nil
    BCORE.Unbox.ShopScroll = scroll
    timer.Simple(0, function()
        if IsValid(scroll) then BCORE.Unbox:RefreshShop() end
    end)
end

--------------------------------------------------------------------------------
function BCORE.Unbox:RefreshShop()
    local scroll = BCORE.Unbox.ShopScroll
    if not IsValid(scroll) then return end

    local search = IsValid(BCORE.Unbox.search) and BCORE.Unbox.search:GetValue() or ""
    local cacheKey = S.filter.."|"..search
    if IsValid(BCORE.Unbox.ShopGrid) and BCORE.Unbox._shopCacheKey==cacheKey then return end
    BCORE.Unbox._shopCacheKey = cacheKey

    if IsValid(BCORE.Unbox.ShopGrid) then BCORE.Unbox.ShopGrid:Remove() end
    local sw   = math.max(scroll:GetWide(), BUi:Scale(400))
    local grid = BUi.Create("DIconLayout", scroll)
    grid:Dock(TOP); grid:SetWide(sw-12)
    grid:SetSpaceX(8); grid:SetSpaceY(8)
    grid:SetMouseInputEnabled(true)
    BCORE.Unbox.ShopGrid = grid

    local data   = LocalPlayer().BCORE_UNBOX_DATA or {}
    local items  = data.items  or {}
    local prices = data.prices or {}
    search = string.lower(search)

    if not next(items) then
        local ph = grid:Add("DPanel"); ph:SetSize(BUi:Scale(400),BUi:Scale(60))
        ph:SetPaintBackground(false)
        ph.Paint = function(s,w,h)
            draw.SimpleText("Waiting for server data…","BCORE.Unboxs.15",
                w/2,h/2,colors.cwhite,TEXT_ALIGN_CENTER,TEXT_ALIGN_CENTER)
        end
        grid:SizeToChildren(false,true)
        return
    end

    local CW,CH = BUi:Scale(200),BUi:Scale(232)

    -- ── CASES TAB ──────────────────────────────────────────────────────────
    if S.filter == "cases" then
        local caseDefs = data.caseDefs or {}
        local allItems = data.items    or {}

        -- popup: show items inside a case with percentages
        local function showCaseContents(ckey, case)
            local frame = BUi.Create("EditablePanel")
            frame:SetSize(BUi:Scale(460), BUi:Scale(540))
            frame:Center(); frame:MakePopup()
            frame:SetAlpha(0); frame:AlphaTo(255, 0.15, 0)
            frame:ClearPaint():On("Paint", function(_,w,h)
                draw.RoundedBox(12,0,0,w,h,colors.sec)
                draw.RoundedBox(12,1,1,w-2,h-2,colors.sec)
                BUi.DrawImgur(1,1,w-2,h-2,
                    "https://invisibalfan-ui.github.io/bui_images/images/srl54gk.png",
                    ColorAlpha(color_white,30),12)
                draw.SimpleText(case.Name or ckey,"BCORE.Unboxb.18",w/2,22,color_white,TEXT_ALIGN_CENTER,TEXT_ALIGN_CENTER)
                draw.SimpleText("Case Contents","BCORE.Unboxs.12",w/2,40,ColorAlpha(color_white,120),TEXT_ALIGN_CENTER,TEXT_ALIGN_CENTER)
                draw.RoundedBox(0,20,52,w-40,1,ColorAlpha(color_white,20))
            end)

            local closeBtn = BUi.Create("DButton", frame)
            closeBtn:SetPos(frame:GetWide()-38, 6); closeBtn:SetSize(32,32); closeBtn:SetText("")
            closeBtn:SetMouseInputEnabled(true)
            closeBtn:ClearPaint():On("Paint",function(_,w2,h2)
                draw.RoundedBox(6,1,1,w2-2,h2-2,Color(160,40,40))
                draw.SimpleText("✕","BCORE.Unboxs.13",w2/2,h2/2,color_white,TEXT_ALIGN_CENTER,TEXT_ALIGN_CENTER)
            end)
            closeBtn:On("DoClick", function() frame:Remove() end)

            local scroll = BUi.Create("DScrollPanel", frame)
            scroll:SetPos(10, 60); scroll:SetSize(frame:GetWide()-20, frame:GetTall()-70)

            -- build weighted pool
            local weights  = case.weights or {}
            local itemKeys = case.itemKeys or {}
            local totalW   = 0
            for _, ik in ipairs(itemKeys) do totalW = totalW + (tonumber(weights[ik]) or 10) end
            totalW = math.max(totalW, 1)

            -- sort by percentage descending
            local pool = {}
            for _, ik in ipairs(itemKeys) do
                local idata = allItems[ik] or {}
                local w     = tonumber(weights[ik]) or 10
                table.insert(pool, {key=ik, item=idata, w=w, pct=w/totalW*100})
            end
            table.sort(pool, function(a,b) return a.pct > b.pct end)

            for _, entry in ipairs(pool) do
                local ik    = entry.key
                local idata = entry.item
                local pct   = entry.pct
                local rar   = string.lower(idata.rarity or "common")
                local rclr2 = rc(rar)
                local iname = getDisplayName(idata, ik)

                local row = BUi.Create("DPanel", scroll)
                row:Dock(TOP); row:DockMargin(0,4,0,0); row:SetTall(BUi:Scale(38))
                row:SetPaintBackground(false)
                row.Paint = function(_,w,h)
                    draw.RoundedBox(7,0,0,w,h,ColorAlpha(rclr2,25))
                    draw.RoundedBox(7,1,1,w-2,h-2,ColorAlpha(colors.bg,180))
                    draw.RoundedBox(3,0,h*.15,3,h*.7,rclr2)

                    -- rarity badge
                    local bw=BUi:Scale(72)
                    draw.RoundedBox(4,10,h/2-9,bw,18,ColorAlpha(rclr2,180))
                    draw.SimpleText(string.upper(rar),"BCORE.Unboxs.10",10+bw/2,h/2,color_white,TEXT_ALIGN_CENTER,TEXT_ALIGN_CENTER)

                    draw.SimpleText(iname,"BCORE.Unboxs.14",10+bw+8,h/2,color_white,TEXT_ALIGN_LEFT,TEXT_ALIGN_CENTER)

                    -- percentage bar background
                    local barX, barW2 = w-BUi:Scale(120), BUi:Scale(80)
                    draw.RoundedBox(4,barX,h/2-5,barW2,10,ColorAlpha(colors.bg,200))
                    draw.RoundedBox(4,barX,h/2-5,math.max(4,barW2*pct/100),10,ColorAlpha(rclr2,200))
                    draw.SimpleText(string.format("%.2f%%",pct),"BCORE.Unboxs.12",
                        w-10,h/2,color_white,TEXT_ALIGN_RIGHT,TEXT_ALIGN_CENTER)
                end
            end

            if #pool == 0 then
                local empty = BUi.Create("DPanel", scroll)
                empty:Dock(TOP); empty:SetTall(BUi:Scale(60)); empty:SetPaintBackground(false)
                empty.Paint = function(_,w,h)
                    draw.SimpleText("No items in this case","BCORE.Unboxs.14",
                        w/2,h/2,ColorAlpha(color_white,80),TEXT_ALIGN_CENTER,TEXT_ALIGN_CENTER)
                end
            end
        end
        for ckey,case in pairs(caseDefs) do
            if not case.Price or case.Price<=0 then continue end
            local cname = case.Name or prettyKey(ckey)
            local rar   = string.lower(case.Rarity or "common")
            local rclr2 = rc(rar)
            S.qty[ckey] = S.qty[ckey] or 1

            local CCH = BUi:Scale(265)
            local wrap = grid:Add("DPanel")
            wrap:SetSize(CW, CCH)
            wrap:SetMouseInputEnabled(true); wrap:SetCursor("hand")
            wrap.Paint = function(s,w,h)
                s._hov = Lerp(FrameTime()*9, s._hov or 0,
                    (s:IsHovered() or s:IsChildHovered()) and 1 or 0)
                local hov = s._hov
                local rot = (CurTime()*28) % 360

                -- rotating rarity border (same animation as chatbox HUD cards)
                BUi.masks.Start()
                surface.SetDrawColor(ColorAlpha(rclr2, math.floor(140+hov*80)))
                surface.SetMaterial(BUi.Grad["Right"])
                surface.DrawTexturedRectRotated(w/2,h/2,w,h*2,rot)
                BUi.masks.Source()
                draw.RoundedBox(10,0,0,w,h,color_white)
                BUi.masks.End()

                -- card body
                draw.RoundedBox(10,2,2,w-4,h-4,colors.sec)

                -- srl54gk animated pattern
                BUi.DrawImgur(2,2,w-4,h-4,
                    "https://invisibalfan-ui.github.io/bui_images/images/srl54gk.png",
                    Color(255,255,255,255), 10)

                -- rclr tint overlay
                BUi.masks.Start()
                surface.SetDrawColor(ColorAlpha(rclr2, math.floor(45+hov*35)))
                surface.SetMaterial(BUi.Grad["Right"])
                surface.DrawTexturedRect(2,2,w-4,h-4)
                BUi.masks.Source()
                draw.RoundedBox(10,2,2,w-4,h-4,color_white)
                BUi.masks.End()

                -- preview area
                local px,py  = BUi:Scale(10), BUi:Scale(10)
                local pw,ph2 = w-BUi:Scale(20), BUi:Scale(90)
                draw.RoundedBox(8,px,py,pw,ph2,ColorAlpha(colors.bg,160))
                local sz=BUi:Scale(20)
                draw.RoundedBox(sz,w/2-sz,py+ph2/2-sz,sz*2,sz*2,ColorAlpha(rclr2,100+hov*80))
                draw.SimpleText("CASE","BCORE.Unboxb.14",w/2,py+ph2/2,
                    color_white,TEXT_ALIGN_CENTER,TEXT_ALIGN_CENTER)

                -- rarity badge
                local by  = py+ph2+BUi:Scale(7)
                local bw2 = BUi:Scale(76)
                draw.RoundedBox(4,BUi:Scale(8),by,bw2,BUi:Scale(18),ColorAlpha(rclr2,210))
                draw.SimpleText(string.upper(rar),"BCORE.Unboxs.11",
                    BUi:Scale(8)+bw2/2,by+BUi:Scale(9),color_white,TEXT_ALIGN_CENTER,TEXT_ALIGN_CENTER)

                local ny = by+BUi:Scale(24)
                draw.SimpleText(BUi.Truncate(cname,18),"BCORE.Unboxs.15",
                    w/2,ny,color_white,TEXT_ALIGN_CENTER,TEXT_ALIGN_CENTER)
                local q = S.qty[ckey] or 1
                draw.SimpleText(fmt(case.Price*q),"BCORE.Unboxs.18",
                    w/2,ny+BUi:Scale(20),colors.moneygreen,TEXT_ALIGN_CENTER,TEXT_ALIGN_CENTER)
            end

            -- VIEW CONTENTS
            local vb = BUi.Create("DButton",wrap)
            vb:SetPos(BUi:Scale(8), CCH-BUi:Scale(92))
            vb:SetSize(CW-BUi:Scale(16), BUi:Scale(32))
            vb:SetText(""); vb:SetZPos(10); vb:SetMouseInputEnabled(true)
            vb:BUi():SetupTransition("hov",9,BUi.HoverFunc)
            vb:BUi():ClearPaint():On("Paint",function(s,w2,h2)
                BUi.masks.Start()
                surface.SetDrawColor(ColorAlpha(Color(80,120,220), 80+s.hov*60))
                surface.SetMaterial(BUi.Grad["Right"])
                surface.DrawTexturedRect(0,0,w2,h2)
                BUi.masks.Source()
                draw.RoundedBox(6,0,0,w2,h2,color_white)
                BUi.masks.End()
                draw.RoundedBox(6,1,1,w2-2,h2-2,Color(40+s.hov*20,60+s.hov*20,100+s.hov*20))
                draw.SimpleText("👁  VIEW CONTENTS","BCORE.Unboxb.12",
                    w2/2,h2/2,color_white,TEXT_ALIGN_CENTER,TEXT_ALIGN_CENTER)
            end)
            vb:BUi():On("DoClick",function() showCaseContents(ckey,case) end)
            vb:MoveToFront()

            -- BUY CASE
            local bb = BUi.Create("DButton",wrap)
            bb:SetPos(BUi:Scale(8), CCH-BUi:Scale(52))
            bb:SetSize(CW-BUi:Scale(16), BUi:Scale(42))
            bb:SetText(""); bb:SetZPos(10); bb:SetMouseInputEnabled(true)
            bb:BUi():SetupTransition("hov",9,BUi.HoverFunc)
            bb:BUi():ClearPaint():On("Paint",function(s,w2,h2)
                BUi.masks.Start()
                surface.SetDrawColor(ColorAlpha(colors.tert, 75+s.hov*50))
                surface.SetMaterial(BUi.Grad["Right"])
                surface.DrawTexturedRect(0,0,w2,h2)
                BUi.masks.Source()
                draw.RoundedBox(6,0,0,w2,h2,color_white)
                BUi.masks.End()
                draw.RoundedBox(6,1,1,w2-2,h2-2,
                    Color(colors.tert.r-s.hov*8,colors.tert.g,colors.tert.b))
                draw.SimpleText("BUY CASE","BCORE.Unboxb.16",
                    w2/2,h2/2,color_white,TEXT_ALIGN_CENTER,TEXT_ALIGN_CENTER)
            end)
            bb:BUi():On("DoClick",function()
                local q=S.qty[ckey] or 1
                thread.Start("BCORE:UnboxBuyCase",{caseKey=ckey,amount=q})
                BCORE.Unbox:Toast("Purchased!",BUi.Truncate(cname,20).." ×"..q,colors.tert)
                timer.Simple(0.7,function()
                    if IsValid(BCORE.Unbox.ShopGrid) then
                        BCORE.Unbox._shopCacheKey=nil; BCORE.Unbox:RefreshShop()
                    end
                end)
            end)
            bb:MoveToFront()
        end
        grid:SizeToChildren(false,true)
        return
    end
    -- ── END CASES TAB ───────────────────────────────────────────────────────

    local rw={}
    for i,r in ipairs(RORDER) do rw[r]=#RORDER-i+1 end
    local sorted={}
    for name,item in pairs(items) do
        if isForSale(item) then
            table.insert(sorted,{
                name=name, item=item,
                dn=getDisplayName(item,name),
                rw=rw[string.lower(item.rarity or "common")] or 0,
            })
        end
    end
    table.sort(sorted,function(a,b)
        if a.rw~=b.rw then return a.rw>b.rw end
        if a.dn~=b.dn then return a.dn<b.dn end
        return a.name<b.name
    end)

    for _,entry in ipairs(sorted) do
        local name  = entry.name
        local item  = entry.item
        local dname = entry.dn
        local rar   = string.lower(item.rarity or "common")
        local rclr  = rc(rar)

        if S.filter~="all" and rar~=S.filter then continue end
        if search~="" and not string.find(string.lower(dname),search,1,true)
                      and not string.find(string.lower(name),search,1,true) then continue end

        local price   = prices[name] or item.basePrice
        S.qty[name]   = S.qty[name] or 1
        local wepIcon = getWeaponIcon(item)

        local wrap = grid:Add("DPanel")
        wrap:SetSize(CW,CH); wrap._hov=0
        wrap:SetMouseInputEnabled(true); wrap:SetKeyboardInputEnabled(false)
        wrap:SetCursor("hand")

        -- 3D model panel (sits behind buy buttons)
        local px,py  = BUi:Scale(10), BUi:Scale(10)
        local pw,ph2 = CW-BUi:Scale(20), BUi:Scale(100)
        local mdl
        if item.model and item.model ~= "" then
            mdl = BUi.Create("DModelPanel", wrap)
            mdl:SetPos(px, py); mdl:SetSize(pw, ph2)
            mdl:SetMouseInputEnabled(false); mdl:SetKeyboardInputEnabled(false)
            mdl:SetPaintBackground(false)
            local ok = pcall(function()
                mdl:SetModel(item.model)
                mdl:SetFOV(45)
                mdl:SetCamPos(Vector(40,0,8)); mdl:SetLookAt(Vector(0,0,4))
            end)
            if not ok then mdl:Remove(); mdl=nil end
            if mdl then
                function mdl:LayoutEntity(ent)
                    ent:SetAngles(Angle(5, (RealTime()*28) % 360, 0))
                end
            end
        end

        wrap.Paint = function(s,w,h)
            s._hov=Lerp(FrameTime()*9,s._hov or 0,
                (s:IsHovered() or s:IsChildHovered()) and 1 or 0)
            local hov = s._hov
            local rot = (CurTime()*28) % 360

            -- rotating rarity border (matches chatbox HUD animation)
            BUi.masks.Start()
            surface.SetDrawColor(ColorAlpha(rclr, math.floor(120+hov*80)))
            surface.SetMaterial(BUi.Grad["Right"])
            surface.DrawTexturedRectRotated(w/2,h/2,w,h*2,rot)
            BUi.masks.Source()
            draw.RoundedBox(10,0,0,w,h,color_white)
            BUi.masks.End()

            -- card body
            draw.RoundedBox(10,2,2,w-4,h-4,colors.sec)

            -- srl54gk animated pattern (full card)
            BUi.DrawImgur(2,2,w-4,h-4,
                "https://invisibalfan-ui.github.io/bui_images/images/srl54gk.png",
                Color(255,255,255,255), 10)

            -- rclr tint
            BUi.masks.Start()
            surface.SetDrawColor(ColorAlpha(rclr, math.floor(40+hov*30)))
            surface.SetMaterial(BUi.Grad["Right"])
            surface.DrawTexturedRect(2,2,w-4,h-4)
            BUi.masks.Source()
            draw.RoundedBox(10,2,2,w-4,h-4,color_white)
            BUi.masks.End()

            -- preview area darker tint
            draw.RoundedBox(8,px,py,pw,ph2,ColorAlpha(colors.bg,160))


            -- fallback icon if no model
            if not IsValid(mdl) then
                if wepIcon then
                    local iw,ih=wepIcon:Width(),wepIcon:Height()
                    if iw>0 and ih>0 then
                        local sc=math.min((pw*0.82)/iw,(ph2*0.72)/ih)
                        surface.SetMaterial(wepIcon)
                        surface.SetDrawColor(255,255,255,200+hov*55)
                        surface.DrawTexturedRect(px+pw/2-iw*sc/2,py+ph2/2-ih*sc/2,iw*sc,ih*sc)
                    end
                else
                    local sz=BUi:Scale(20)
                    draw.RoundedBox(sz,w/2-sz,py+ph2/2-sz,sz*2,sz*2,ColorAlpha(rclr,80+hov*80))
                    draw.SimpleText((item.type or "W"):sub(1,1):upper(),"BCORE.Unboxb.22",
                        w/2,py+ph2/2,color_white,TEXT_ALIGN_CENTER,TEXT_ALIGN_CENTER)
                end
            end

            local by=py+ph2+BUi:Scale(8)
            local bw=BUi:Scale(76)
            draw.RoundedBox(4,BUi:Scale(8),by,bw,BUi:Scale(18),ColorAlpha(rclr,210))
            draw.SimpleText(string.upper(rar),"BCORE.Unboxs.11",
                BUi:Scale(8)+bw/2,by+BUi:Scale(9),color_white,TEXT_ALIGN_CENTER,TEXT_ALIGN_CENTER)
            local ny=by+BUi:Scale(22)
            draw.SimpleText(BUi.Truncate(dname,18),"BCORE.Unboxs.15",
                w/2,ny,color_white,TEXT_ALIGN_CENTER,TEXT_ALIGN_CENTER)
            local q=S.qty[name] or 1
            local py2=ny+BUi:Scale(22)
            draw.SimpleText(fmt(price*q),"BCORE.Unboxs.18",
                w/2,py2,colors.moneygreen,TEXT_ALIGN_CENTER,TEXT_ALIGN_CENTER)
            if q>1 then
                draw.SimpleText(fmt(price).." ea","BCORE.Unbox.11",
                    w/2,py2+BUi:Scale(11),ColorAlpha(colors.moneygreen,140),TEXT_ALIGN_CENTER,TEXT_ALIGN_CENTER)
            end
        end

        local qb = BUi.Create("DButton",wrap)
        qb:SetPos(BUi:Scale(8),CH-BUi:Scale(42))
        qb:SetSize(BUi:Scale(48),BUi:Scale(34))
        qb:SetText(""); qb:SetZPos(10); qb:SetMouseInputEnabled(true)
        qb:BUi():SetupTransition("hov",9,BUi.HoverFunc)
        qb:BUi():ClearPaint():Background(colors.light,6):On("Paint",function(s,w,h)
            draw.RoundedBox(6,1,1,w-2,h-2,
                Color(colors.accent.r+s.hov*14,colors.accent.g+s.hov*14,colors.accent.b+s.hov*14))
            draw.SimpleText("×"..(S.qty[name] or 1),"BCORE.Unboxs.15",
                w/2,h/2,color_white,TEXT_ALIGN_CENTER,TEXT_ALIGN_CENTER)
        end)
        qb:MoveToFront()
        qb:BUi():On("DoClick",function()
            local cur=S.qty[name] or 1; local i2=1
            for i,v in ipairs(QO) do if v==cur then i2=i; break end end
            S.qty[name]=QO[(i2%#QO)+1]
        end)

        local bb = BUi.Create("DButton",wrap)
        bb:SetPos(BUi:Scale(60),CH-BUi:Scale(42))
        bb:SetSize(CW-BUi:Scale(68),BUi:Scale(34))
        bb:SetText(""); bb._rip=0; bb:SetZPos(10); bb:SetMouseInputEnabled(true)
        bb:BUi():SetupTransition("hov",9,BUi.HoverFunc)
        bb:BUi():ClearPaint():Background(colors.light,6):On("Paint",function(s,w,h)
            BUi.masks.Start()
            surface.SetMaterial(BUi.Grad["Right"])
            surface.SetDrawColor(ColorAlpha(colors.tert,75+s.hov*28))
            surface.DrawTexturedRect(0,0,w,h)
            BUi.masks.Source()
            draw.RoundedBox(6,0,0,w,h,color_white)
            BUi.masks.End()
            draw.RoundedBox(6,1,1,w-2,h-2,Color(colors.tert.r-s.hov*8,colors.tert.g,colors.tert.b))
            draw.SimpleText("BUY","BCORE.Unboxb.16",w/2,h/2,color_white,TEXT_ALIGN_CENTER,TEXT_ALIGN_CENTER)
            if s._rip>0 then
                surface.SetDrawColor(Color(255,255,255,s._rip*90)); draw.NoTexture()
                BUi.DrawCircle(w/2,h/2,(1-s._rip)*math.max(w,h)*1.5,Color(255,255,255,s._rip*90))
                s._rip=math.max(0,s._rip-FrameTime()*3)
            end
        end)
        bb:MoveToFront()
        bb:BUi():On("DoClick",function()
            local q=S.qty[name] or 1
            thread.Start("BCORE:UnboxPurchase",{itemName=name,amount=q})
            bb._rip=1
            BCORE.Unbox:Toast("Purchase sent!",BUi.Truncate(dname,22).." ×"..q,colors.tert)
            timer.Simple(0.7,function()
                if IsValid(BCORE.Unbox.ShopGrid) then
                    BCORE.Unbox._shopCacheKey=nil; BCORE.Unbox:RefreshShop()
                end
            end)
        end)
    end

    grid:SizeToChildren(false,true)
end