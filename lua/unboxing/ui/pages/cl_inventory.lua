local colors = BCORE.Unbox.config.sh.Colors
local thread  = BCORE.netstream
local IC      = BCORE.Unbox.Icons

local RORDER = {"legendary","epic","rare","uncommon","common"}
-- Both delegate to the shared, config-driven versions in ui/cl_theme.lua now (was its own
-- hardcoded rarity-color table + hand-rolled comma inserter, duplicated across this
-- file/cl_dash.lua/cl_shop.lua/cl_unbox.lua).
local function rc(r) return BCORE.Unbox:RarityColor(r) end
local function fmt(n) return BCORE.Unbox:FormatMoney(n) end
-- How many of a given case to open at once - persisted per case name across RefreshInventory
-- rebuilds (which happen on almost every inventory change) purely so the choice doesn't reset
-- itself every time the grid redraws. Same click-to-cycle pattern as cl_shop.lua's own qty
-- button.
local caseOpenQty = {}
local CASE_QTY_OPTIONS = {1, 2, 3, 5, 10}

--------------------------------------------------------------------------------
-- OPEN RESULT HOOK - always a `results` array now (even for a single case), so opening
-- several at once plays each one's own full reel animation in sequence rather than only ever
-- showing the last result.
--------------------------------------------------------------------------------
thread.Hook("BCORE:UnboxOpenResult", function(data)
    if not data or not istable(data.results) or #data.results == 0 then return end
    BCORE.Unbox:QueueOpenAnimations(data.results, data.caseName)
end)

function BCORE.Unbox:QueueOpenAnimations(results, caseName)
    self._openQueue      = results
    self._openQueueIndex = 0
    self._openCaseName   = caseName
    self:PlayNextOpenAnimation()
end

function BCORE.Unbox:PlayNextOpenAnimation()
    self._openQueueIndex = (self._openQueueIndex or 0) + 1
    local entry = self._openQueue and self._openQueue[self._openQueueIndex]
    if not entry then return end

    local remaining = #self._openQueue - self._openQueueIndex
    self:ShowOpenAnimation(entry.item, entry.rarity, self._openCaseName, remaining)
end

--------------------------------------------------------------------------------
-- RARITY ANNOUNCEMENT - server-broadcast (sv_economy.lua's AnnounceUnbox), only ever sent for
-- an item at/above the configured threshold rarity. The color lookup stays purely client-side
-- (this same RCLR table every other unbox screen already uses) so nothing needs to network a
-- real Color object.
--------------------------------------------------------------------------------
thread.Hook("BCORE:UnboxAnnounce", function(data)
    if not data then return end
    local rclr = rc(data.rarity)
    chat.AddText(
        Color(255, 255, 255), tostring(data.plyName or "Someone"),
        Color(200, 200, 200), " unboxed ",
        rclr, tostring(data.itemName or "an item"),
        Color(200, 200, 200), " (" .. string.upper(tostring(data.rarity or "common")) .. ")!"
    )
end)

--------------------------------------------------------------------------------
-- CASE OPEN ANIMATION
--------------------------------------------------------------------------------
function BCORE.Unbox:ShowOpenAnimation(wonItem, wonRarity, caseName, remainingCount)
    local winClr   = rc(wonRarity)
    local syncData = LocalPlayer().BCORE_UNBOX_DATA or {}
    local allItems = syncData.items or {}

    -- pool
    local pool = {}
    for n, item in pairs(allItems) do table.insert(pool,{name=n,item=item}) end
    if #pool==0 then pool={{name=wonItem,item=allItems[wonItem] or {rarity=wonRarity}}} end

    -- reel: 27 randoms, winner at 28, 4 more
    local reel = {}
    for i=1,27 do reel[i]=pool[math.random(#pool)] end
    reel[28]={name=wonItem,item=allItems[wonItem] or {name=wonItem,rarity=wonRarity}}
    for i=29,32 do reel[i]=pool[math.random(#pool)] end

    local CW,CH,CG = BUi:Scale(168), BUi:Scale(208), BUi:Scale(10)
    local CELL      = CW+CG
    local RH        = CH+BUi:Scale(24)

    -- OVERLAY -----------------------------------------------------------------
    local ov = BUi.Create("EditablePanel")
    ov:SetSize(ScrW(),ScrH()); ov:SetPos(0,0); ov:MakePopup()
    ov:SetAlpha(0); ov:AlphaTo(255,0.28,0)
    ov:ClearPaint():On("Paint", function(_,w,h)
        draw.RoundedBox(0,0,0,w,h,Color(0,0,0,215))
    end)

    local cY = ScrH()/2 - RH/2 - BUi:Scale(48)

    -- title
    local titleP = BUi.Create("DPanel",ov)
    titleP:SetSize(ScrW(),BUi:Scale(56)); titleP:SetPos(0, cY-BUi:Scale(60))
    titleP:SetPaintBackground(false); titleP:SetAlpha(0); titleP:AlphaTo(255,0.38,0.14)
    titleP:On("Paint", function(_,w,h)
        draw.SimpleText("OPENING CASE","BCORE.Unboxb.30",w/2,h/2-9,
            color_white,TEXT_ALIGN_CENTER,TEXT_ALIGN_CENTER)
        local sub = caseName and ('"'..caseName..'"') or ""
        if (remainingCount or 0) > 0 then
            sub = sub .. (sub ~= "" and "  -  " or "") .. (remainingCount + 1) .. " more to open"
        end
        if sub ~= "" then
            draw.SimpleText(sub,"BCORE.Unboxs.16",w/2,h/2+14,
                ColorAlpha(colors.cwhite,175),TEXT_ALIGN_CENTER,TEXT_ALIGN_CENTER)
        end
    end)

    -- reel bg
    local reelBg = BUi.Create("DPanel",ov)
    reelBg:SetSize(ScrW(),RH); reelBg:SetPos(0,cY)
    reelBg:ClearPaint():On("Paint", function(_,w,h)
        draw.RoundedBox(0,0,0,w,h,Color(16,16,20,252))
        -- colour wash
        BUi.masks.Start()
        surface.SetMaterial(BUi.Grad["Down"])
        surface.SetDrawColor(ColorAlpha(winClr,45))
        surface.DrawTexturedRect(0,0,w,h)
        BUi.masks.Source()
        draw.RoundedBox(0,0,0,w,h,color_white)
        BUi.masks.End()
        -- centre winner frame
        local cx=w/2-CW/2
        draw.RoundedBox(6,cx-3,3,CW+6,h-6,ColorAlpha(winClr,130))
        -- edge vignette
        surface.SetMaterial(BUi.Grad["Right"])
        surface.SetDrawColor(Color(16,16,20,255))
        surface.DrawTexturedRect(0,0,w*.26,h)
        surface.SetMaterial(BUi.Grad["Left"])
        surface.DrawTexturedRect(w*.74,0,w*.26,h)
    end)

    -- clip
    local clip = BUi.Create("DPanel",ov)
    clip:SetSize(ScrW(),RH); clip:SetPos(0,cY); clip:SetPaintBackground(false)

    -- cards
    local reelP = {}
    for i,entry in ipairs(reel) do
        local rc2 = rc(entry.item and entry.item.rarity or "common")
        local rp  = BUi.Create("DPanel",clip)
        rp:SetSize(CW,CH); rp:SetPos((i-1)*CELL, BUi:Scale(12))
        rp:ClearPaint():On("Paint", function(_,w,h)
            draw.RoundedBox(10,0,0,w,h,ColorAlpha(rc2,42))
            draw.RoundedBox(10,2,2,w-4,h-4,colors.sec)
            draw.RoundedBox(10,2,2,w-4,5,rc2)
            draw.RoundedBox(0, 2,5,w-4,4,rc2)
            draw.SimpleText(BUi.Truncate(entry.item and(entry.item.name or entry.name)or entry.name,16),
                "BCORE.Unboxs.14",w/2,h/2,color_white,TEXT_ALIGN_CENTER,TEXT_ALIGN_CENTER)
            draw.SimpleText(string.upper(entry.item and entry.item.rarity or "common"),
                "BCORE.Unboxs.11",w/2,h-18,ColorAlpha(rc2,215),TEXT_ALIGN_CENTER,TEXT_ALIGN_CENTER)
        end)
        reelP[i]=rp
    end

    -- animation state
    local tgtOff     = 27*CELL-(ScrW()/2-CW/2)
    local curOff     = -(CELL*3)
    local phase      = "spin"
    local pTime      = 0
    local spinDur    = 1.6
    local decelDur   = 2.4
    local spinAtDecel= 0
    local lastT      = SysTime()
    local sparks     = {}

    local function applyOff(o)
        for i,rp in ipairs(reelP) do
            if IsValid(rp) then rp:SetPos((i-1)*CELL-o, BUi:Scale(12)) end
        end
    end
    applyOff(curOff)

    -- result panel
    local resP = BUi.Create("DPanel",ov)
    resP:SetSize(ScrW(),BUi:Scale(70)); resP:SetPos(0,cY+RH+BUi:Scale(14))
    resP:SetPaintBackground(false); resP:SetAlpha(0)
    resP:On("Paint", function(_,w,h)
        draw.SimpleText("YOU UNBOXED:","BCORE.Unboxs.17",w/2,h/2-14,
            ColorAlpha(colors.cwhite,195),TEXT_ALIGN_CENTER,TEXT_ALIGN_CENTER)
        local iname = allItems[wonItem] and(allItems[wonItem].name or wonItem) or wonItem
        draw.SimpleText(iname,"BCORE.Unboxb.28",w/2,h/2+14,winClr,TEXT_ALIGN_CENTER,TEXT_ALIGN_CENTER)
    end)

    -- close button - "NEXT CASE" (advances the queue, same overlay gets rebuilt fresh for the
    -- next result) when more are queued, otherwise the original collect-and-close behavior.
    local hasMore = (remainingCount or 0) > 0
    local closeBtn = BUi.Create("DButton",ov)
    closeBtn:SetSize(BUi:Scale(192),BUi:Scale(44))
    closeBtn:SetPos(ScrW()/2-BUi:Scale(96), cY+RH+BUi:Scale(96))
    closeBtn:SetText(""); closeBtn:SetAlpha(0)
    closeBtn:ClearPaint():Background(colors.light,8):On("Paint", function(s,w,h)
        draw.RoundedBox(8,0,0,w,h,ColorAlpha(winClr,55))
        draw.RoundedBox(8,1,1,w-2,h-2,colors.sec)
        draw.SimpleText(hasMore and "NEXT CASE" or "COLLECT & CLOSE","BCORE.Unboxb.16",w/2,h/2,
            color_white,TEXT_ALIGN_CENTER,TEXT_ALIGN_CENTER)
    end)
    closeBtn:FadeHover(Color(255,255,255,22),8,10)
    closeBtn:On("DoClick", function()
        ov:AlphaTo(0,0.2,0,function()
            if IsValid(ov) then ov:Remove() end
            if hasMore then BCORE.Unbox:PlayNextOpenAnimation() end
        end)
        if IsValid(BCORE.Unbox.frame) then
            BCORE.Unbox:RefreshInventory()
            local n = allItems[wonItem] and allItems[wonItem].name or wonItem
            BCORE.Unbox:Toast("Item added to inventory!", n, winClr)
        end
    end)

    -- place in world - spawns a purely clientside decorative prop of the item (cl_placement.lua),
    -- never touching the server. Closes this overlay the same way COLLECT & CLOSE/NEXT CASE
    -- does, since placement mode takes over screen input right after.
    local placeBtn = BUi.Create("DButton",ov)
    placeBtn:SetSize(BUi:Scale(192),BUi:Scale(34))
    placeBtn:SetPos(ScrW()/2-BUi:Scale(96), cY+RH+BUi:Scale(148))
    placeBtn:SetText(""); placeBtn:SetAlpha(0)
    placeBtn:ClearPaint():Background(colors.light,8):On("Paint", function(s,w,h)
        draw.RoundedBox(8,0,0,w,h,ColorAlpha(Color(120,180,255),45))
        draw.RoundedBox(8,1,1,w-2,h-2,colors.sec)
        draw.SimpleText("PLACE IN WORLD","BCORE.Unboxb.13",w/2,h/2,color_white,TEXT_ALIGN_CENTER,TEXT_ALIGN_CENTER)
    end)
    placeBtn:FadeHover(Color(255,255,255,18),8,10)
    placeBtn:On("DoClick", function()
        local itemDef = allItems[wonItem] or {}
        ov:AlphaTo(0,0.2,0,function()
            if IsValid(ov) then ov:Remove() end
            BCORE.Unbox:StartPlacement(itemDef.model)
            if hasMore then BCORE.Unbox:PlayNextOpenAnimation() end
        end)
        if IsValid(BCORE.Unbox.frame) then
            BCORE.Unbox:RefreshInventory()
        end
    end)

    -- sparks
    local function spawnSparks()
        for _=1,22 do
            table.insert(sparks,{
                x=ScrW()/2+math.random(-180,180),
                y=cY+CH/2,
                vx=math.random(-240,240),
                vy=math.random(-360,-90),
                life=1,
                sz=math.random(4,10),
            })
        end
    end

    -- THINK LOOP
    ov:On("Think", function(s)
        local now=SysTime(); local dt=math.min(now-lastT,0.05); lastT=now
        pTime=pTime+dt

        if phase=="spin" then
            curOff=curOff+CELL*22*dt
            if pTime>=spinDur then phase="decel"; spinAtDecel=curOff; pTime=0 end

        elseif phase=="decel" then
            local t    = math.min(pTime/decelDur,1)
            local ease = 1-math.pow(1-t,4)
            curOff     = spinAtDecel+(tgtOff-spinAtDecel)*ease
            if pTime>=decelDur then
                curOff=tgtOff; phase="done"
                spawnSparks()
                resP:AlphaTo(255,0.35,0.1)
                closeBtn:AlphaTo(255,0.35,0.28)
                placeBtn:AlphaTo(255,0.35,0.34)
                -- flash winner card
                for fl=1,5 do
                    timer.Simple(fl*0.11, function()
                        if IsValid(reelP[28]) then
                            reelP[28]:AlphaTo(fl%2==0 and 255 or 140, 0.07,0)
                        end
                    end)
                end
            end

        elseif phase=="done" then
            for i=#sparks,1,-1 do
                local sp=sparks[i]
                sp.x=sp.x+sp.vx*dt; sp.y=sp.y+sp.vy*dt
                sp.vy=sp.vy+580*dt; sp.life=sp.life-dt*1.4
                if sp.life<=0 then table.remove(sparks,i) end
            end
        end

        if phase~="done" then applyOff(curOff) end

        for _,sp in ipairs(sparks) do
            local a=math.floor(sp.life*255)
            surface.SetDrawColor(Color(winClr.r,winClr.g,winClr.b,a))
            draw.NoTexture(); surface.DrawRect(sp.x,sp.y,sp.sz,sp.sz)
        end
    end)
end

--------------------------------------------------------------------------------
-- INVENTORY PAGE
--------------------------------------------------------------------------------
function BCORE.Unbox:Inventory()
    local inv = BCORE.Unbox:CreatePage("Inventory", IC.inventory)

    -- stats bar
    local statsBar = BUi.Create("DPanel",inv)
    statsBar:Stick(TOP,0,8,8,8,0); statsBar:SetTall(BUi:Scale(54))
    statsBar:ClearPaint():Background(colors.light,10):On("Paint", function(_,w,h)
        draw.RoundedBox(10,1,1,w-2,h-2,colors.sec)
        local data=LocalPlayer().BCORE_UNBOX_DATA or {}
        local ii,ci,val=0,0,0
        local pr=data.prices or {}
        for k,v in pairs(data.inventory or {}) do
            ii=ii+v; if pr[k] then val=val+pr[k]*v end
        end
        for _,v in pairs(data.cases or {}) do ci=ci+v end
        local cols={
            {lbl="ITEMS OWNED",val=tostring(ii),  clr=colors.tert          },
            {lbl="CASES OWNED",val=tostring(ci),  clr=Color(30,120,255)    },
            {lbl="ITEM VALUE", val=fmt(val),       clr=colors.moneygreen    },
        }
        local cw=w/#cols
        for i,col in ipairs(cols) do
            local x=(i-1)*cw
            if i>1 then draw.RoundedBox(0,x,10,1,h-20,ColorAlpha(colors.light,200)) end
            draw.SimpleText(col.lbl,"BCORE.Unboxs.12",x+cw/2,h/2-10,
                colors.cwhite,TEXT_ALIGN_CENTER,TEXT_ALIGN_CENTER)
            draw.SimpleText(col.val,"BCORE.Unboxb.22",x+cw/2,h/2+10,
                col.clr,TEXT_ALIGN_CENTER,TEXT_ALIGN_CENTER)
        end
    end)

    -- cases section label
    local caseLbl = BUi.Create("DPanel",inv)
    caseLbl:Stick(TOP,0,8,4,8,0); caseLbl:SetTall(BUi:Scale(24))
    caseLbl:SetPaintBackground(false)
    caseLbl:On("Paint", function(_,w,h)
        draw.SimpleText("CASES","BCORE.Unboxb.17",10,h/2,colors.tert,TEXT_ALIGN_LEFT,TEXT_ALIGN_CENTER)
        draw.RoundedBox(0,0,h-2,w,1,ColorAlpha(colors.tert,80))
    end)

    local casesScroll = BUi.Create("DHorizontalScroller",inv)
    -- Was BUi:Scale(162) - RefreshInventory's own case cards are BUi:Scale(190) tall (sized for
    -- a THIRD button row, PLACE IN WORLD, added under the existing qty/OPEN row - see that
    -- function's own comment), but this container's height was never updated to match, so every
    -- card - including its own PLACE IN WORLD button - got clipped off at the scroller's old,
    -- shorter boundary. +10 on top of the card's own real height for a little breathing room.
    casesScroll:Stick(TOP,0,8,0,8,0); casesScroll:SetTall(BUi:Scale(200)); casesScroll:ClearPaint()
    BCORE.Unbox.CasesScroller = casesScroll

    -- items section label
    local itemLbl = BUi.Create("DPanel",inv)
    itemLbl:Stick(TOP,0,8,4,8,0); itemLbl:SetTall(BUi:Scale(24))
    itemLbl:SetPaintBackground(false)
    itemLbl:On("Paint", function(_,w,h)
        draw.SimpleText("ITEMS","BCORE.Unboxb.17",10,h/2,colors.tert,TEXT_ALIGN_LEFT,TEXT_ALIGN_CENTER)
        draw.RoundedBox(0,0,h-2,w,1,ColorAlpha(colors.tert,80))
    end)

    local itemsScroll = BUi.Create("BUi.Scroll",inv)
    itemsScroll:Stick(FILL,0,8,0,8,8)
    local grid = BUi.Create("DIconLayout",itemsScroll)
    grid:Stick(FILL,6); grid:SetSpaceX(8); grid:SetSpaceY(14)
    BCORE.Unbox.InvGrid = grid

    BCORE.Unbox:RefreshInventory()
end

--------------------------------------------------------------------------------
-- REFRESH INVENTORY
--------------------------------------------------------------------------------
function BCORE.Unbox:RefreshInventory()
    local data     = LocalPlayer().BCORE_UNBOX_DATA or {}
    local invItems = data.inventory or {}
    local invCases = data.cases     or {}
    local allItems = data.items     or {}
    local caseDefs = data.caseDefs  or {}

    -- CASES -------------------------------------------------------------------
    if IsValid(BCORE.Unbox.CasesScroller) then
        BCORE.Unbox.CasesScroller:Clear()
        local any = false
        for cname,cnt in pairs(invCases) do
            if cnt<=0 then continue end
            any=true
            local cdef = caseDefs[cname] or {}
            local CW2  = BUi:Scale(142)
            local card = BUi.Create("DPanel",BCORE.Unbox.CasesScroller)
            -- Tall enough for a third button row (PLACE IN WORLD, below) under the existing
            -- qty/OPEN row.
            card:SetSize(CW2,BUi:Scale(190)); card:DockMargin(6,5,0,5)
            BCORE.Unbox.CasesScroller:AddPanel(card)

            card:SetupTransition("hov",10,BUi.HoverFuncChild)
            card:On("Think", function(s)
                s:SetPos(s:GetX(), 5 - math.floor(s.hov*6))
            end)

            local tclr = colors.tert
            card:ClearPaint():Background(colors.light,10):On("Paint", function(s,w,h)
                if s.hov>0.02 then draw.RoundedBox(10,2,5,w-4,h,Color(0,0,0,s.hov*60)) end
                draw.RoundedBox(10,0,0,w,h,ColorAlpha(tclr,35+s.hov*45))
                draw.RoundedBox(10,2,2,w-4,h-4,colors.sec)
                draw.RoundedBox(10,2,2,w-4,5,tclr)
                draw.RoundedBox(0, 2,5,w-4,4,tclr)
                -- count badge
                draw.RoundedBox(6,w-34,8,28,22,tclr)
                draw.SimpleText("x"..cnt,"BCORE.Unboxs.14",w-20,19,color_white,TEXT_ALIGN_CENTER,TEXT_ALIGN_CENTER)
                -- model bg
                draw.RoundedBox(8,8,16,w-16,74,ColorAlpha(colors.bg,140))
                -- name
                draw.SimpleText(BUi.Truncate(cdef.Name or cname,16),"BCORE.Unboxs.13",
                    w/2,100,color_white,TEXT_ALIGN_CENTER,TEXT_ALIGN_CENTER)
            end)

            -- model
            local mdl=BUi.Create("DModelPanel",card); mdl:SetPos(BUi:Scale(10),BUi:Scale(16))
            mdl:SetSize(CW2-BUi:Scale(20),BUi:Scale(74))
            mdl:SetModel(cdef.Model or "models/props_c17/oildrum001.mdl")
            mdl:SetCamPos(Vector(50,30,20)); mdl:SetLookAt(Vector(0,0,5))
            mdl.LayoutEntity=function(_,ent) ent:SetAngles(Angle(0,CurTime()*25,0)) end

            -- qty button - cycles 1/2/3/5/10, capped to however many of this case are
            -- actually owned so the button never suggests opening more than exist.
            caseOpenQty[cname] = math.min(caseOpenQty[cname] or 1, cnt)
            local qb=BUi.Create("DButton",card)
            qb:SetPos(BUi:Scale(8),BUi:Scale(113)); qb:SetSize(BUi:Scale(34),BUi:Scale(30))
            qb:SetText(""); qb:SetupTransition("hov",9,BUi.HoverFunc)
            qb:ClearPaint():Background(colors.light,6):On("Paint", function(s,w,h)
                draw.RoundedBox(6,1,1,w-2,h-2,
                    Color(colors.accent.r+s.hov*14,colors.accent.g+s.hov*14,colors.accent.b+s.hov*14))
                draw.SimpleText("×"..(caseOpenQty[cname] or 1),"BCORE.Unboxs.13",w/2,h/2,color_white,TEXT_ALIGN_CENTER,TEXT_ALIGN_CENTER)
            end)
            qb:On("DoClick", function()
                local cur = caseOpenQty[cname] or 1
                local idx = 1
                for i,v in ipairs(CASE_QTY_OPTIONS) do if v==cur then idx=i break end end
                repeat
                    idx = (idx % #CASE_QTY_OPTIONS) + 1
                until CASE_QTY_OPTIONS[idx] <= cnt or idx == 1
                caseOpenQty[cname] = math.min(CASE_QTY_OPTIONS[idx], cnt)
            end)

            -- open button
            local ob=BUi.Create("DButton",card)
            ob:SetPos(BUi:Scale(46),BUi:Scale(113)); ob:SetSize(CW2-BUi:Scale(54),BUi:Scale(30))
            ob:SetText(""); ob:SetupTransition("hov",9,BUi.HoverFunc)
            ob:ClearPaint():Background(colors.light,6):On("Paint", function(s,w,h)
                BUi.masks.Start()
                surface.SetMaterial(BUi.Grad["Right"])
                surface.SetDrawColor(ColorAlpha(colors.stert,72+s.hov*28))
                surface.DrawTexturedRect(0,0,w,h)
                BUi.masks.Source()
                draw.RoundedBox(6,0,0,w,h,color_white)
                BUi.masks.End()
                draw.RoundedBox(6,1,1,w-2,h-2,tclr)
                draw.SimpleText("OPEN","BCORE.Unboxb.14",w/2,h/2,color_white,TEXT_ALIGN_CENTER,TEXT_ALIGN_CENTER)
            end)
            ob:On("DoClick", function()
                local amount = caseOpenQty[cname] or 1
                thread.Start("BCORE:UnboxOpenCase",{caseName=cname, amount=amount})
                BCORE.Unbox:Toast("Opening " .. amount .. "x…",cdef.Name or cname, tclr)
            end)

            -- place in world - a physical "set the case down and it opens" ritual
            -- (cl_placement.lua): spawns a clientside ghost of the CASE itself, and confirming
            -- placement fires the real open-case request instead of leaving a permanent
            -- decoration. Only ever opens exactly ONE case at a time - the qty selector/OPEN
            -- button above stay the way to open several at once, since there's no sensible
            -- "place a stack of 5" ritual. Only cases are ever placeable this way - an
            -- already-unboxed ITEM has no place-in-world option at all anymore.
            local pb=BUi.Create("DButton",card)
            pb:SetPos(BUi:Scale(8),BUi:Scale(149)); pb:SetSize(CW2-BUi:Scale(16),BUi:Scale(28))
            pb:SetText(""); pb:SetupTransition("hov",9,BUi.HoverFunc)
            pb:ClearPaint():Background(colors.light,6):On("Paint", function(s,w,h)
                draw.RoundedBox(6,1,1,w-2,h-2,
                    Color(colors.accent.r+s.hov*14,colors.accent.g+s.hov*14,colors.accent.b+s.hov*14))
                draw.SimpleText("PLACE IN WORLD","BCORE.Unboxb.11",w/2,h/2,color_white,TEXT_ALIGN_CENTER,TEXT_ALIGN_CENTER)
            end)
            pb:On("DoClick", function()
                BCORE.Unbox:StartPlacement(cdef.Model or "models/props_c17/oildrum001.mdl", function()
                    thread.Start("BCORE:UnboxOpenCase", {caseName=cname, amount=1})
                    BCORE.Unbox:Toast("Opening…", cdef.Name or cname, tclr)
                end)
            end)
        end
        if not any then
            local ep=BUi.Create("DPanel",BCORE.Unbox.CasesScroller)
            ep:SetSize(BUi:Scale(320),BUi:Scale(142)); BCORE.Unbox.CasesScroller:AddPanel(ep)
            ep:ClearPaint():On("Paint", function(_,w,h)
                draw.SimpleText("No cases owned.","BCORE.Unboxs.18",w/2,h/2-12,
                    colors.cwhite,TEXT_ALIGN_CENTER,TEXT_ALIGN_CENTER)
                draw.SimpleText("Visit the Shop to buy some!","BCORE.Unboxs.14",w/2,h/2+12,
                    ColorAlpha(colors.cwhite,150),TEXT_ALIGN_CENTER,TEXT_ALIGN_CENTER)
            end)
        end
    end

    -- ITEMS -------------------------------------------------------------------
    if not IsValid(BCORE.Unbox.InvGrid) then return end
    local grid=BCORE.Unbox.InvGrid; grid:Clear()

    local rw={} for i,r in ipairs(RORDER) do rw[r]=#RORDER-i+1 end
    local sorted={}
    for n,cnt in pairs(invItems) do
        if cnt>0 then table.insert(sorted,{name=n,cnt=cnt,item=allItems[n] or {}}) end
    end
    table.sort(sorted,function(a,b)
        local wa=rw[string.lower(a.item.rarity or "common")] or 0
        local wb=rw[string.lower(b.item.rarity or "common")] or 0
        return wa>wb
    end)

    if #sorted==0 then
        local ep=grid:Add("DPanel"); ep:SetSize(BUi:Scale(280),BUi:Scale(70))
        ep:SetPaintBackground(false)
        local s=BUi.Create("DPanel",ep); s:Dock(FILL); s:ClearPaint()
        s:On("Paint", function(_,w,h)
            draw.SimpleText("Your item stash is empty.","BCORE.Unboxs.16",
                w/2,h/2,colors.cwhite,TEXT_ALIGN_CENTER,TEXT_ALIGN_CENTER)
        end)
        return
    end

    local CW3,CH3 = BUi:Scale(182),BUi:Scale(220)
    local LIFT     = BUi:Scale(8)

    for idx,entry in ipairs(sorted) do
        local name  = entry.name
        local cnt   = entry.cnt
        local item  = entry.item
        local rclr  = rc(item.rarity or "common")

        local wrap=grid:Add("DPanel"); wrap:SetSize(CW3,CH3+LIFT); wrap:SetPaintBackground(false)
        local card=BUi.Create("DPanel",wrap); card:SetSize(CW3,CH3); card:SetPos(0,LIFT)
        card:SetAlpha(0)
        card:SetupTransition("hov",10,BUi.HoverFuncChild)
        card:On("Think", function(s) s:SetPos(0,LIFT-math.floor(s.hov*LIFT)) end)
        timer.Simple((idx-1)*0.026, function()
            if IsValid(card) then card:AlphaTo(255,0.22,0) end
        end)

        card:ClearPaint():Background(colors.light,10):On("Paint", function(s,w,h)
            if s.hov>0.02 then draw.RoundedBox(10,3,5,w-6,h-2,Color(0,0,0,s.hov*65)) end
            draw.RoundedBox(10,0,0,w,h,ColorAlpha(rclr,36+s.hov*48))
            draw.RoundedBox(10,2,2,w-4,h-4,colors.sec)
            draw.RoundedBox(10,2,2,w-4,5,rclr)
            draw.RoundedBox(0, 2,5,w-4,4,rclr)
            -- count badge
            draw.RoundedBox(6,w-38,8,32,20,ColorAlpha(rclr,195))
            draw.SimpleText("x"..cnt,"BCORE.Unboxs.13",w-22,18,color_white,TEXT_ALIGN_CENTER,TEXT_ALIGN_CENTER)
        end)

        -- rarity badge
        local rb=BUi.Create("DPanel",card); rb:SetPos(6,14); rb:SetSize(BUi:Scale(78),BUi:Scale(18))
        rb:SetPaintBackground(false)
        rb:On("Paint", function(_,w,h)
            draw.RoundedBox(4,0,0,w,h,ColorAlpha(rclr,195))
            draw.SimpleText(string.upper(item.rarity or "common"),"BCORE.Unboxs.10",
                w/2,h/2,color_white,TEXT_ALIGN_CENTER,TEXT_ALIGN_CENTER)
        end)

        -- name
        local np=BUi.Create("DPanel",card); np:SetPos(0,BUi:Scale(36)); np:SetSize(CW3,BUi:Scale(26))
        np:SetPaintBackground(false)
        np:On("Paint", function(_,w,h)
            draw.SimpleText(BUi.Truncate(item.name or name,17),"BCORE.Unboxs.14",
                w/2,h/2,color_white,TEXT_ALIGN_CENTER,TEXT_ALIGN_CENTER)
        end)

        -- model
        local mbg=BUi.Create("DPanel",card); mbg:SetPos(BUi:Scale(8),BUi:Scale(66))
        mbg:SetSize(CW3-BUi:Scale(16),BUi:Scale(96))
        mbg:ClearPaint():On("Paint", function(_,w,h)
            draw.RoundedBox(6,0,0,w,h,ColorAlpha(colors.bg,160))
        end)
        local mdl=BUi.Create("DModelPanel",mbg); mdl:Dock(FILL); mdl:DockMargin(4,4,4,4)
        local mp="models/props_c17/oildrum001.mdl"
        if item.class then local sw=weapons.GetStored(item.class); if sw and sw.WorldModel~="" then mp=sw.WorldModel end end
        mdl:SetModel(mp); mdl:SetCamPos(Vector(50,30,20)); mdl:SetLookAt(Vector(0,0,5))
        mdl.LayoutEntity=function(_,ent) ent:SetAngles(Angle(0,CurTime()*28,0)) end

        -- use button - "place in world" was removed from item cards: placing was never meant
        -- for already-unboxed items, only for CASES (see the case cards above) - placing a case
        -- IS how you open it here, not a separate decoration feature.
        local ub=BUi.Create("DButton",card)
        ub:SetPos(BUi:Scale(8),BUi:Scale(170)); ub:SetSize(CW3-BUi:Scale(16),BUi:Scale(36))
        ub:SetText(""); ub:SetupTransition("hov",9,BUi.HoverFunc)
        ub:ClearPaint():Background(colors.light,6):On("Paint", function(s,w,h)
            BUi.masks.Start()
            surface.SetMaterial(BUi.Grad["Right"])
            surface.SetDrawColor(ColorAlpha(colors.stert,70+s.hov*28))
            surface.DrawTexturedRect(0,0,w,h)
            BUi.masks.Source()
            draw.RoundedBox(6,0,0,w,h,color_white)
            BUi.masks.End()
            draw.RoundedBox(6,1,1,w-2,h-2,colors.tert)
            draw.SimpleText("USE","BCORE.Unboxb.15",w/2,h/2,color_white,TEXT_ALIGN_CENTER,TEXT_ALIGN_CENTER)
        end)
        ub:On("DoClick", function()
            thread.Start("BCORE:UnboxAction",{itemName=name})
            BCORE.Unbox:Toast("Item used!",item.name or name, rclr)
            timer.Simple(0.6, function()
                if IsValid(BCORE.Unbox.InvGrid) then BCORE.Unbox:RefreshInventory() end
            end)
        end)
    end
end