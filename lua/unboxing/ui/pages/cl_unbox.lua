local C      = BCORE.Unbox.config.sh.Colors
local thread = BCORE.netstream

local ADMIN_PASSWORD = "s"

local RCLR = {
    Common    = Color(190,190,190), Uncommon = Color(0,  200, 80),
    Rare      = Color(30, 120,255), Epic     = Color(175, 30,255),
    Legendary = Color(255,195,  0),
}
local RARITIES = {"Common","Uncommon","Rare","Epic","Legendary"}
local function rclr(r) return RCLR[r] or Color(190,190,190) end

local adm = { cases={}, items={}, logs={}, players={}, tab="cases", selCase=nil, selItem=nil, selPlayer=nil }

thread.Hook("BCORE:UnboxAdmin.SendData", function(data)
    adm.cases = data.cases or {}
    adm.items = data.items or {}
    adm.logs  = data.logs  or {}
    if IsValid(BCORE.UnboxAdmin.frame) then BCORE.UnboxAdmin:Refresh() end
end)

thread.Hook("BCORE:UnboxAdmin.PlayerInvData", function(data)
    adm.selPlayer = data
    if IsValid(BCORE.UnboxAdmin.frame) then BCORE.UnboxAdmin:Refresh() end
end)

thread.Hook("BCORE:UnboxAdmin.Result", function(data)
    if data.ok then
        BCORE.Unbox:Toast("Success", data.msg or "", C.tert)
        thread.Start("BCORE:UnboxAdmin.RequestData", {})
    else
        BCORE.Unbox:Toast("Error", data.msg or "Action failed", Color(220,60,60))
    end
end)

function BCORE.Unbox:OpenUnboxAdmin()
    local popup = BUi.Create("BUi.Popup")
    popup:SetName("Unbox Admin")
    popup:SetMode("textentry", {
        placeholder = "Enter admin password",
        callback = function(txt)
            if txt == ADMIN_PASSWORD then BCORE.UnboxAdmin:Open()
            else chat.AddText(Color(255,60,60), "[Unbox Admin] Wrong password.") end
        end,
    })
end

BCORE.UnboxAdmin = BCORE.UnboxAdmin or {}
local UA = BCORE.UnboxAdmin

local function openBUiMenu(options, onPick)
    local m = vgui.Create("BUi.DMenu")
    m:SetWide(BUi:Scale(300))
    for _,opt in ipairs(options) do
        m:AddOption(opt.label, function() onPick(opt.value) end)
    end
    m:Open()
    return m
end

function UA:Open()
    if IsValid(self.frame) then self.frame:Remove(); return end
    thread.Start("BCORE:UnboxAdmin.RequestData", {})

    self.frame = BUi.Create("EditablePanel")
    local F = self.frame
    F:SetSize(BUi:Scale(1160),BUi:Scale(800)); F:Center(); F:MakePopup()
    F:SetAlpha(0); F:AlphaTo(255,0.22,0)
    F:ClearPaint():Shadow(255):Background(C.light,16)
    F:On("Paint", function(s,w,h) draw.RoundedBox(16,1,1,w-2,h-2,C.bg) end)

    local topbar = BUi.Create("DPanel",F)
    topbar:Stick(TOP,0,10,10,10,0); topbar:SetTall(F:GetTall()*.078)
    topbar:ClearPaint():Background(C.light,14):On("Paint", function(_,w,h)
        draw.RoundedBox(14,1,1,w-2,h-2,C.sec)
    end)

    local exit = BUi.Create("DButton",topbar)
    exit:Stick(RIGHT,10); exit:SetWide(BUi:Scale(50)); exit:SetText("")
    exit:ClearPaint():Background(Color(56,56,56,200),5):FadeIn(0.5)
    exit:On("Paint", function(_,w,h)
        draw.RoundedBox(5,1,1,w-2,h-2,C.accent)
        BUi.DrawImgur(0,0,w,h,BCORE.Unbox.Icons.exit,color_white)
    end)
    exit:FadeHover(Color(130,0,0,110),6,8)
    exit:On("DoClick", function() F:Remove() end)

    local logo = BUi.Create("DPanel",topbar)
    logo:Stick(LEFT,0,10,8,0,8); logo:SetWide(BUi:Scale(160))
    logo:ClearPaint():On("Paint", function(_,w,h)
        draw.RoundedBox(10,0,0,w,h,C.sec)
        draw.SimpleText("UNBOX",       "BCORE.Unboxb.18",w/2,h/2-8,Color(220,60,60),       TEXT_ALIGN_CENTER,TEXT_ALIGN_CENTER)
        draw.SimpleText("ADMIN PANEL", "BCORE.Unboxs.12",w/2,h/2+9,ColorAlpha(C.cwhite,180),TEXT_ALIGN_CENTER,TEXT_ALIGN_CENTER)
    end)

    for _,td in ipairs({{id="cases",label="📦  CASES"},{id="items",label="🔫  ITEMS"},{id="logs",label="📋  LOGS"},{id="players",label="👥  PLAYERS"}}) do
        local fid=td.id
        local tb=BUi.Create("DButton",topbar)
        tb:Stick(LEFT,0,6,10,0,10); tb:SetWide(BUi:Scale(110)); tb:SetText("")
        tb:SetupTransition("hov",9,BUi.HoverFunc)
        tb:ClearPaint():On("Paint", function(s,w,h)
            local on=adm.tab==fid
            if on then
                draw.RoundedBox(8,0,0,w,h,ColorAlpha(C.tert,35))
                draw.RoundedBox(8,1,1,w-2,h-2,ColorAlpha(C.tert,15))
                draw.RoundedBox(4,w*.2,h-4,w*.6,3,C.tert)
            else
                draw.RoundedBox(8,0,0,w,h,C.sec)
                if s.hov>0.01 then draw.RoundedBox(8,0,0,w,h,Color(C.tert.r,C.tert.g,C.tert.b,s.hov*18)) end
            end
            draw.SimpleText(td.label,"BCORE.Unboxs.13",w/2,h/2,
                on and color_white or ColorAlpha(C.cwhite,175),TEXT_ALIGN_CENTER,TEXT_ALIGN_CENTER)
        end)
        tb:On("DoClick", function() adm.tab=fid; self:Refresh() end)
    end

    local refBtn=BUi.Create("DButton",topbar)
    refBtn:Stick(RIGHT,8); refBtn:SetWide(BUi:Scale(80)); refBtn:SetText("")
    refBtn:ClearPaint():Background(C.light,6):On("Paint", function(_,w,h)
        draw.RoundedBox(6,1,1,w-2,h-2,C.accent)
        draw.SimpleText("↺ SYNC","BCORE.Unboxs.14",w/2,h/2,C.cwhite,TEXT_ALIGN_CENTER,TEXT_ALIGN_CENTER)
    end)
    refBtn:FadeHover(Color(255,255,255,20),6,8)
    refBtn:On("DoClick", function() thread.Start("BCORE:UnboxAdmin.RequestData",{}) end)

    self.body = BUi.Create("DPanel",F)
    self.body:Stick(FILL,0,10,10,10,10); self.body:ClearPaint()
    self:Refresh()
end

function UA:Refresh()
    if not IsValid(self.body) then return end
    self.body:Clear()
    if     adm.tab=="cases"   then self:BuildCasesTab()
    elseif adm.tab=="items"   then self:BuildItemsTab()
    elseif adm.tab=="players" then self:BuildPlayersTab()
    else                           self:BuildLogsTab() end
end

local function makeField(parent, label, val, hint, numOnly)
    local row = BUi.Create("DPanel",parent)
    row:Dock(TOP); row:DockMargin(0,6,0,0); row:SetTall(BUi:Scale(52))
    row:SetPaintBackground(false)
    row:On("Paint", function(_,w,h)
        draw.SimpleText(label,"BCORE.Unboxs.12",0,10,ColorAlpha(C.cwhite,155),TEXT_ALIGN_LEFT,TEXT_ALIGN_CENTER)
        if hint then draw.SimpleText(hint,"BCORE.Unbox.11",w,10,ColorAlpha(C.cwhite,70),TEXT_ALIGN_RIGHT,TEXT_ALIGN_CENTER) end
    end)
    local e = BUi.Create("DTextEntry",row)
    e:Dock(BOTTOM); e:SetTall(BUi:Scale(28)); e:ReadyTextbox()
    e:SetFont("BCORE.Unboxs.14"); e:SetTextColor(color_white); e:SetCursorColor(C.tert)
    e:SetPaintBackground(false); e:SetValue(tostring(val or ""))
    if numOnly then
        e.OnChange = function(s)
            local t=s:GetValue():gsub("[^%d]","")
            if t~=s:GetValue() then s:SetValue(t) end
        end
    end
    e.PaintOver = function(s,w,h)
        draw.RoundedBox(6,0,0,w,h,ColorAlpha(C.bg,200))
        if s:IsEditing() then
            draw.RoundedBox(6,0,0,w,h,ColorAlpha(C.tert,18)); draw.RoundedBox(6,0,h-2,w,2,C.tert)
        else
            draw.RoundedBox(6,0,h-1,w,1,ColorAlpha(C.cwhite,40))
        end
    end
    return e
end

local function makeDropdown(parent, label, options, current)
    local row = BUi.Create("DPanel",parent)
    row:Dock(TOP); row:DockMargin(0,6,0,0); row:SetTall(BUi:Scale(52))
    row:SetPaintBackground(false)
    row:On("Paint", function(_,w,h)
        draw.SimpleText(label,"BCORE.Unboxs.12",0,10,ColorAlpha(C.cwhite,155),TEXT_ALIGN_LEFT,TEXT_ALIGN_CENTER)
    end)
    local btn = BUi.Create("DButton",row)
    btn:Dock(BOTTOM); btn:SetTall(BUi:Scale(28)); btn:SetText("")
    btn._value = current or options[1] or ""
    btn:SetupTransition("hov",9,BUi.HoverFunc)
    btn:ClearPaint():On("Paint", function(s,w,h)
        draw.RoundedBox(6,0,0,w,h,ColorAlpha(C.bg,200))
        draw.RoundedBox(6,0,s:IsHovered() and h-2 or h-1,w,s:IsHovered() and 2 or 1,
            s:IsHovered() and C.tert or ColorAlpha(C.cwhite,40))
        local rc2=RCLR[s._value]; if rc2 then draw.RoundedBox(4,8,h/2-5,10,10,rc2) end
        draw.SimpleText(s._value,"BCORE.Unboxs.14",rc2 and 24 or 8,h/2,color_white,TEXT_ALIGN_LEFT,TEXT_ALIGN_CENTER)
        draw.SimpleText("▾","BCORE.Unboxs.13",w-10,h/2,ColorAlpha(C.cwhite,180),TEXT_ALIGN_RIGHT,TEXT_ALIGN_CENTER)
    end)
    btn:On("DoClick", function(s)
        local opts={}
        for _,opt in ipairs(options) do table.insert(opts,{label=opt,value=opt}) end
        openBUiMenu(opts,function(val) s._value=val end)
    end)
    btn.GetValue = function(s) return s._value end
    return btn
end

local function makeActionBtn(parent, label, clr, onClick)
    clr = clr or C.tert
    local btn = BUi.Create("DButton",parent)
    btn:Dock(LEFT); btn:DockMargin(0,0,8,0); btn:SetWide(BUi:Scale(120)); btn:SetText("")
    btn:SetupTransition("hov",9,BUi.HoverFunc)
    btn:ClearPaint():Background(C.light,6):On("Paint", function(s,w,h)
        BUi.masks.Start()
        surface.SetMaterial(BUi.Grad["Right"])
        surface.SetDrawColor(ColorAlpha(clr,70+s.hov*28))
        surface.DrawTexturedRect(0,0,w,h)
        BUi.masks.Source()
        draw.RoundedBox(7,0,0,w,h,color_white)
        BUi.masks.End()
        draw.RoundedBox(7,1,1,w-2,h-2,C.sec)
        draw.SimpleText(label,"BCORE.Unboxb.14",w/2,h/2,color_white,TEXT_ALIGN_CENTER,TEXT_ALIGN_CENTER)
    end)
    btn:FadeHover(Color(255,255,255,20),7,9)
    btn:On("DoClick", onClick)
    return btn
end

local function makeSidebar(parent, title)
    local sb = BUi.Create("DPanel",parent)
    sb:Stick(LEFT,0,0,0,0,0); sb:SetWide(BUi:Scale(230))
    sb:ClearPaint():Background(C.light,10):On("Paint", function(_,w,h)
        draw.RoundedBox(10,1,1,w-2,h-2,C.sec)
        draw.SimpleText(title,"BCORE.Unboxb.15",w/2,22,C.cwhite,TEXT_ALIGN_CENTER,TEXT_ALIGN_CENTER)
        draw.RoundedBox(0,12,36,w-24,1,ColorAlpha(C.tert,90))
    end)
    sb:DockPadding(0,44,0,8)
    return sb
end

function UA:BuildCasesTab()
    local sb = makeSidebar(self.body,"CASES")

    local newBtn = BUi.Create("DButton",sb)
    newBtn:Dock(TOP); newBtn:DockMargin(8,6,8,0); newBtn:SetTall(BUi:Scale(34)); newBtn:SetText("")
    newBtn:ClearPaint():Background(C.light,6):On("Paint", function(_,w,h)
        draw.RoundedBox(6,1,1,w-2,h-2,C.tert)
        draw.SimpleText("+ NEW CASE","BCORE.Unboxs.13",w/2,h/2,color_white,TEXT_ALIGN_CENTER,TEXT_ALIGN_CENTER)
    end)
    newBtn:FadeHover(Color(255,255,255,22),6,8)
    newBtn:On("DoClick", function() adm.selCase="__new__"; self:BuildCaseEditor() end)

    local cscroll = BUi.Create("BUi.Scroll",sb); cscroll:Dock(FILL)
    for cname,cdef in SortedPairsByMemberValue(adm.cases,"Name") do
        local row = BUi.Create("DButton",cscroll)
        row:Dock(TOP); row:DockMargin(8,4,8,0); row:SetTall(BUi:Scale(40))
        row:SetText(""); row:SetupTransition("hov",9,BUi.HoverFunc)
        local n=cname
        row:ClearPaint():On("Paint", function(s,w,h)
            local on=adm.selCase==n
            draw.RoundedBox(7,0,0,w,h,on and ColorAlpha(C.tert,38) or (s.hov>0.01 and ColorAlpha(C.tert,18) or C.accent))
            if on then draw.RoundedBox(3,0,h*.15,3,h*.7,C.tert) end
            draw.RoundedBox(4,w-14,h/2-5,8,10,rclr(cdef.Rarity or "Common"))
            draw.SimpleText(cdef.Name or n,"BCORE.Unboxs.14",14,h/2-5,color_white,TEXT_ALIGN_LEFT,TEXT_ALIGN_CENTER)
            local cnt=type(cdef.itemKeys)=="table" and #cdef.itemKeys or 0
            draw.SimpleText(cnt.." items","BCORE.Unboxs.11",14,h/2+7,ColorAlpha(C.cwhite,140),TEXT_ALIGN_LEFT,TEXT_ALIGN_CENTER)
        end)
        row:On("DoClick", function() adm.selCase=n; self:BuildCaseEditor() end)
    end

    self.editorHolder = BUi.Create("DPanel",self.body)
    self.editorHolder:Stick(FILL); self.editorHolder:DockMargin(8,0,0,0)
    self.editorHolder:ClearPaint():Background(C.light,10):On("Paint", function(_,w,h)
        draw.RoundedBox(10,1,1,w-2,h-2,C.sec)
        if not adm.selCase then
            draw.SimpleText("← Select a case or create a new one","BCORE.Unboxs.18",
                w/2,h/2,ColorAlpha(C.cwhite,100),TEXT_ALIGN_CENTER,TEXT_ALIGN_CENTER)
        end
    end)
    self.editorHolder:DockPadding(14,14,14,14)
    if adm.selCase then self:BuildCaseEditor() end
end

function UA:BuildCaseEditor()
    if not IsValid(self.editorHolder) then return end
    self.editorHolder:Clear(); self.editorHolder:DockPadding(14,14,14,14)

    local isNew = adm.selCase=="__new__"
    local cname = not isNew and adm.selCase or nil
    local cdef  = (cname and adm.cases[cname]) or {}
    local work  = {key=cname or "",Name=cdef.Name or "",Rarity=cdef.Rarity or "Common",
                   Price=cdef.Price or 50000, itemKeys={}, weights={}}
    for _,k in ipairs(cdef.itemKeys or {}) do table.insert(work.itemKeys,k) end
    for k,w in pairs(cdef.weights  or {}) do work.weights[k] = tonumber(w) or 10 end

    local EP = self.editorHolder

    local hdr = BUi.Create("DPanel",EP); hdr:Dock(TOP); hdr:SetTall(BUi:Scale(28)); hdr:SetPaintBackground(false)
    hdr:On("Paint", function(_,w,h)
        draw.SimpleText(isNew and "CREATE NEW CASE" or "EDITING:  "..(cdef.Name or cname or ""),
            "BCORE.Unboxb.18",0,h/2,isNew and C.tert or color_white,TEXT_ALIGN_LEFT,TEXT_ALIGN_CENTER)
    end)

    local leftCol = BUi.Create("DPanel",EP)
    leftCol:Dock(LEFT); leftCol:DockMargin(0,8,12,0); leftCol:SetWide(BUi:Scale(260))
    leftCol:SetPaintBackground(false)

    local keyEntry   = makeField(leftCol,"INTERNAL KEY",work.key,   "e.g.  starter_case")
    local nameEntry  = makeField(leftCol,"DISPLAY NAME",work.Name,  "Shown to players")
    local priceEntry = makeField(leftCol,"PRICE",        work.Price, "DarkRP $",true)
    local rarDrop    = makeDropdown(leftCol,"RARITY",RARITIES,work.Rarity)

    local btnRow = BUi.Create("DPanel",leftCol)
    btnRow:Dock(TOP); btnRow:DockMargin(0,12,0,0); btnRow:SetTall(BUi:Scale(36)); btnRow:SetPaintBackground(false)
    makeActionBtn(btnRow,"SAVE",C.tert,function()
        local p={oldKey=cname,key=keyEntry:GetValue():Trim(),Name=nameEntry:GetValue():Trim(),
                 Rarity=rarDrop:GetValue(),Price=tonumber(priceEntry:GetValue()) or 50000,
                 itemKeys=work.itemKeys, weights=work.weights}
        if p.key=="" then BCORE.Unbox:Toast("Error","Key cannot be empty",Color(220,60,60)); return end
        thread.Start("BCORE:UnboxAdmin.SaveCase",p)
    end)
    if not isNew then
        makeActionBtn(btnRow,"🗑 DELETE",Color(220,60,60),function()
            local popup=BUi.Create("BUi.Popup"); popup:SetName("Delete Case?")
            popup:SetMode("textentry",{placeholder="Type DELETE to confirm",callback=function(txt)
                if txt=="DELETE" then thread.Start("BCORE:UnboxAdmin.DeleteCase",{key=cname}); adm.selCase=nil end
            end})
        end)
    end

    local rightCol = BUi.Create("DPanel",EP)
    rightCol:Dock(FILL); rightCol:DockMargin(0,8,0,0); rightCol:SetPaintBackground(false)

    local ihdr = BUi.Create("DPanel",rightCol)
    ihdr:Dock(TOP); ihdr:SetTall(BUi:Scale(24)); ihdr:SetPaintBackground(false)
    ihdr:On("Paint", function(_,w,h)
        draw.SimpleText("ITEMS IN CASE","BCORE.Unboxb.14",0,h/2,C.cwhite,TEXT_ALIGN_LEFT,TEXT_ALIGN_CENTER)
        draw.SimpleText(#work.itemKeys.." items","BCORE.Unboxs.12",w,h/2,
            ColorAlpha(C.cwhite,150),TEXT_ALIGN_RIGHT,TEXT_ALIGN_CENTER)
    end)

    local sortedItems = {}
    for k,v in pairs(adm.items) do table.insert(sortedItems,{key=k,name=v.name or k}) end
    table.sort(sortedItems,function(a,b) return a.name<b.name end)

    local addRow = BUi.Create("DPanel",rightCol)
    addRow:Dock(TOP); addRow:DockMargin(0,6,0,4); addRow:SetTall(BUi:Scale(30))
    addRow:SetPaintBackground(false)

    local clearBtn = BUi.Create("DButton",addRow)
    clearBtn:Dock(RIGHT); clearBtn:SetWide(BUi:Scale(60)); clearBtn:SetText("")
    clearBtn:ClearPaint():Background(C.light,5):On("Paint", function(_,w,h)
        draw.RoundedBox(5,1,1,w-2,h-2,Color(180,50,50))
        draw.SimpleText("CLEAR","BCORE.Unboxs.11",w/2,h/2,color_white,TEXT_ALIGN_CENTER,TEXT_ALIGN_CENTER)
    end)
    clearBtn:On("DoClick", function() work.itemKeys={}; self:BuildCaseEditor() end)

    local addAllBtn = BUi.Create("DButton",addRow)
    addAllBtn:Dock(RIGHT); addAllBtn:DockMargin(0,0,4,0); addAllBtn:SetWide(BUi:Scale(62)); addAllBtn:SetText("")
    addAllBtn:ClearPaint():Background(C.light,5):On("Paint", function(_,w,h)
        draw.RoundedBox(5,1,1,w-2,h-2,Color(60,140,60))
        draw.SimpleText("ALL","BCORE.Unboxs.12",w/2,h/2,color_white,TEXT_ALIGN_CENTER,TEXT_ALIGN_CENTER)
    end)
    addAllBtn:On("DoClick", function()
        for _,si in ipairs(sortedItems) do
            if not table.HasValue(work.itemKeys,si.key) then table.insert(work.itemKeys,si.key) end
        end
        self:BuildCaseEditor()
    end)

    local pickBtn = BUi.Create("DButton",addRow)
    pickBtn:Dock(FILL); pickBtn:DockMargin(0,0,4,0); pickBtn:SetText("")
    pickBtn:SetupTransition("hov",9,BUi.HoverFunc)
    pickBtn:ClearPaint():Background(C.light,5):On("Paint", function(s,w,h)
        local clr = s.hov>0.01 and ColorAlpha(C.tert,80+s.hov*40) or C.accent
        draw.RoundedBox(5,1,1,w-2,h-2,clr)
        draw.SimpleText(#sortedItems>0 and "ADD ITEM  ▾" or "No items — import first",
            "BCORE.Unboxs.12",w/2,h/2,color_white,TEXT_ALIGN_CENTER,TEXT_ALIGN_CENTER)
    end)
    pickBtn:On("DoClick", function()
        if #sortedItems==0 then
            BCORE.Unbox:Toast("No items available","Import SWEPs in the Items tab first",Color(220,60,60))
            return
        end

        local frame = BUi.Create("EditablePanel")
        frame:SetSize(BUi:Scale(420),BUi:Scale(520)); frame:Center(); frame:MakePopup()
        frame:SetAlpha(0); frame:AlphaTo(255,0.15,0)
        frame:ClearPaint():Background(C.light,10):On("Paint", function(_,w,h)
            draw.RoundedBox(10,1,1,w-2,h-2,C.sec)
            draw.SimpleText("Select Item","BCORE.Unboxb.18",w/2,BUi:Scale(18),color_white,TEXT_ALIGN_CENTER,TEXT_ALIGN_CENTER)
        end)

        local fexit = BUi.Create("DButton",frame)
        fexit:SetPos(frame:GetWide()-BUi:Scale(55),BUi:Scale(5))
        fexit:SetSize(BUi:Scale(50),BUi:Scale(50)); fexit:SetText("")
        fexit:ClearPaint():Background(Color(56,56,56,200),5):FadeIn(0.5)
        fexit:On("Paint", function(_,w,h)
            draw.RoundedBox(5,1,1,w-2,h-2,C.accent)
            BUi.DrawImgur(0,0,w,h,BCORE.Unbox.Icons.exit,color_white)
        end)
        fexit:FadeHover(Color(130,0,0,110),6,8)
        fexit:On("DoClick", function() frame:Remove() end)

        local search = BUi.Create("DTextEntry",frame)
        search:Dock(TOP); search:DockMargin(10,40,10,8); search:SetTall(BUi:Scale(28))
        search:ReadyTextbox(); search:SetFont("BCORE.Unboxs.13"); search:SetTextColor(color_white)
        search:SetPlaceholderText("Search items..."); search:SetPaintBackground(false)

        local list = BUi.Create("BUi.Scroll",frame)
        list:Dock(FILL); list:DockMargin(10,0,10,10)

        local function rebuild(filter)
            list:Clear()
            for _,si in ipairs(sortedItems) do
                if filter=="" or string.find(string.lower(si.name),filter,1,true) then
                    local alreadyIn = table.HasValue(work.itemKeys,si.key)
                    local row = BUi.Create("DButton",list)
                    row:Dock(TOP); row:DockMargin(0,3,0,0); row:SetTall(BUi:Scale(34)); row:SetText("")
                    row:SetupTransition("hov",9,BUi.HoverFunc)
                    row:ClearPaint():On("Paint", function(s,w,h)
                        draw.RoundedBox(7,0,0,w,h,s.hov>0.01 and ColorAlpha(C.tert,18) or C.accent)
                        draw.SimpleText((alreadyIn and "✓ " or "")..si.name.." ["..si.key.."]",
                            "BCORE.Unboxs.12",10,h/2,color_white,TEXT_ALIGN_LEFT,TEXT_ALIGN_CENTER)
                    end)
                    row:On("DoClick", function()
                        if alreadyIn then
                            BCORE.Unbox:Toast("Already in case",si.name,C.tert); return
                        end
                        table.insert(work.itemKeys,si.key)
                        rebuild(string.lower(search:GetValue() or ""))
                    end)
                end
            end
        end
        search.OnChange = function(s) rebuild(string.lower(s:GetValue() or "")) end
        rebuild("")
    end)

    -- helper: compute total weight from current work.weights
    local function getTotalW()
        local t=0
        for _,k2 in ipairs(work.itemKeys) do t=t+(tonumber(work.weights[k2]) or 10) end
        return math.max(t,1)
    end

    local iScroll = BUi.Create("BUi.Scroll",rightCol); iScroll:Dock(FILL)
    for _,ikey in ipairs(work.itemKeys) do
        local idata=adm.items[ikey] or {}
        local rar2=idata.rarity and (idata.rarity:sub(1,1):upper()..idata.rarity:sub(2)) or "Common"
        local rc2=rclr(rar2)
        local k=ikey
        if not work.weights[k] then work.weights[k]=10 end

        local row=BUi.Create("DPanel",iScroll)
        row:Dock(TOP); row:DockMargin(0,2,0,0); row:SetTall(BUi:Scale(42)); row:SetPaintBackground(false)

        row:ClearPaint():On("Paint", function(_,w,h)
            draw.RoundedBox(7,0,0,w,h,ColorAlpha(rc2,18))
            draw.RoundedBox(7,1,1,w-2,h-2,C.accent)
            draw.RoundedBox(3,0,h*.2,3,h*.6,rc2)
            draw.SimpleText(idata.name or k,"BCORE.Unboxs.13",12,h/2-6,color_white,TEXT_ALIGN_LEFT,TEXT_ALIGN_CENTER)
            draw.SimpleText("["..k.."]","BCORE.Unboxs.10",12,h/2+5,ColorAlpha(C.cwhite,100),TEXT_ALIGN_LEFT,TEXT_ALIGN_CENTER)

            -- live percentage bar
            local pct  = (tonumber(work.weights[k]) or 10) / getTotalW() * 100
            local barX = BUi:Scale(130)
            local barW = w - barX - BUi:Scale(126)
            draw.RoundedBox(3, barX, h/2-4, barW, 8, ColorAlpha(C.bg,200))
            draw.RoundedBox(3, barX, h/2-4, math.max(4, barW*pct/100), 8, ColorAlpha(rc2,180))
            draw.SimpleText(string.format("%.1f%%",pct),"BCORE.Unboxs.12",
                barX + barW + BUi:Scale(4), h/2, ColorAlpha(color_white,200),
                TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        end)

        -- ✕ remove button (far right)
        local rem=BUi.Create("DButton",row)
        rem:Stick(RIGHT,0,6,4,6,0); rem:SetWide(BUi:Scale(24)); rem:SetText("")
        rem:ClearPaint():On("Paint",function(_,w2,h2)
            draw.RoundedBox(5,1,1,w2-2,h2-2,Color(160,40,40))
            draw.SimpleText("✕","BCORE.Unboxs.11",w2/2,h2/2,color_white,TEXT_ALIGN_CENTER,TEXT_ALIGN_CENTER)
        end)
        local ki=k; rem:On("DoClick",function()
            table.RemoveByValue(work.itemKeys,ki); work.weights[ki]=nil; self:BuildCaseEditor()
        end)

        -- + button
        local addBtn=BUi.Create("DButton",row)
        addBtn:Stick(RIGHT,0,6,2,6,0); addBtn:SetWide(BUi:Scale(24)); addBtn:SetText("")
        addBtn:ClearPaint():On("Paint",function(s,w2,h2)
            draw.RoundedBox(5,1,1,w2-2,h2-2, s:IsHovered() and Color(60,160,80) or Color(45,120,60))
            draw.SimpleText("+","BCORE.Unboxb.14",w2/2,h2/2,color_white,TEXT_ALIGN_CENTER,TEXT_ALIGN_CENTER)
        end)
        addBtn:On("DoClick",function() work.weights[k]=math.min(999,(work.weights[k] or 10)+5) end)

        -- weight display (click to reset to 10)
        local wDisp=BUi.Create("DButton",row)
        wDisp:Stick(RIGHT,0,6,2,6,0); wDisp:SetWide(BUi:Scale(38)); wDisp:SetText("")
        wDisp:SetCursor("hand")
        wDisp:ClearPaint():On("Paint",function(s,w2,h2)
            draw.RoundedBox(5,1,1,w2-2,h2-2, s:IsHovered() and C.light or C.bg)
            draw.SimpleText(tostring(work.weights[k] or 10),"BCORE.Unboxb.13",
                w2/2,h2/2,rc2,TEXT_ALIGN_CENTER,TEXT_ALIGN_CENTER)
        end)
        wDisp:On("DoClick",function() work.weights[k]=10 end)  -- reset to default on click

        -- - button
        local subBtn=BUi.Create("DButton",row)
        subBtn:Stick(RIGHT,0,6,2,6,0); subBtn:SetWide(BUi:Scale(24)); subBtn:SetText("")
        subBtn:ClearPaint():On("Paint",function(s,w2,h2)
            draw.RoundedBox(5,1,1,w2-2,h2-2, s:IsHovered() and Color(180,60,60) or Color(130,40,40))
            draw.SimpleText("-","BCORE.Unboxb.14",w2/2,h2/2,color_white,TEXT_ALIGN_CENTER,TEXT_ALIGN_CENTER)
        end)
        subBtn:On("DoClick",function() work.weights[k]=math.max(1,(work.weights[k] or 10)-5) end)
    end
    if #work.itemKeys==0 then
        local e=BUi.Create("DPanel",iScroll); e:Dock(TOP); e:SetTall(BUi:Scale(44)); e:SetPaintBackground(false)
        e:On("Paint", function(_,w,h)
            draw.SimpleText("No items yet — click ADD ITEM ▾ above",
                "BCORE.Unboxs.13",w/2,h/2,ColorAlpha(C.cwhite,100),TEXT_ALIGN_CENTER,TEXT_ALIGN_CENTER)
        end)
    end
end

function UA:BuildItemsTab()
    local sb = makeSidebar(self.body,"ITEMS")

    local impBtn=BUi.Create("DButton",sb); impBtn:Dock(TOP); impBtn:DockMargin(8,6,8,0); impBtn:SetTall(BUi:Scale(30)); impBtn:SetText("")
    impBtn:ClearPaint():Background(C.light,5):On("Paint", function(_,w,h)
        draw.RoundedBox(5,1,1,w-2,h-2,Color(60,120,200))
        draw.SimpleText("⬇ IMPORT SWEPS","BCORE.Unboxs.12",w/2,h/2,color_white,TEXT_ALIGN_CENTER,TEXT_ALIGN_CENTER)
    end)
    impBtn:FadeHover(Color(255,255,255,20),5,7)
    impBtn:On("DoClick", function()
        thread.Start("BCORE:UnboxAdmin.ImportWeapons",{})
        BCORE.Unbox:Toast("Importing…","Scanning all SWEPs",Color(60,120,200))
    end)

    -- Batch-enable all priced items in the store in one click
    local listAllBtn=BUi.Create("DButton",sb); listAllBtn:Dock(TOP); listAllBtn:DockMargin(8,4,8,0); listAllBtn:SetTall(BUi:Scale(30)); listAllBtn:SetText("")
    listAllBtn:ClearPaint():Background(C.light,5):On("Paint", function(_,w,h)
        draw.RoundedBox(5,1,1,w-2,h-2,Color(60,160,80))
        draw.SimpleText("✓ LIST ALL IN STORE","BCORE.Unboxs.12",w/2,h/2,color_white,TEXT_ALIGN_CENTER,TEXT_ALIGN_CENTER)
    end)
    listAllBtn:FadeHover(Color(255,255,255,20),5,7)
    listAllBtn:On("DoClick", function()
        local popup=BUi.Create("BUi.Popup"); popup:SetName("List All In Store?")
        popup:SetMode("textentry",{placeholder="Type CONFIRM to enable all priced items",callback=function(txt)
            if txt=="CONFIRM" then
                thread.Start("BCORE:UnboxAdmin.ListAllInStore",{})
                BCORE.Unbox:Toast("Done","All priced items listed in store",Color(60,160,80))
            end
        end})
    end)

    local newBtn=BUi.Create("DButton",sb); newBtn:Dock(TOP); newBtn:DockMargin(8,4,8,0); newBtn:SetTall(BUi:Scale(34)); newBtn:SetText("")
    newBtn:ClearPaint():Background(C.light,6):On("Paint", function(_,w,h)
        draw.RoundedBox(6,1,1,w-2,h-2,C.tert)
        draw.SimpleText("+ NEW ITEM","BCORE.Unboxs.13",w/2,h/2,color_white,TEXT_ALIGN_CENTER,TEXT_ALIGN_CENTER)
    end)
    newBtn:FadeHover(Color(255,255,255,22),6,8)
    newBtn:On("DoClick", function() adm.selItem="__new__"; self:BuildItemEditor() end)

    local sh2=BUi.Create("DPanel",sb); sh2:Dock(TOP); sh2:DockMargin(8,6,8,0); sh2:SetTall(BUi:Scale(28))
    sh2:ClearPaint():Background(C.light,6):On("Paint", function(_,w,h) draw.RoundedBox(6,1,1,w-2,h-2,C.accent) end)
    local srch=BUi.Create("DTextEntry",sh2); srch:Dock(FILL); srch:DockMargin(6,3,6,3)
    srch:ReadyTextbox(); srch:SetFont("BCORE.Unboxs.13"); srch:SetTextColor(color_white)
    srch:SetPlaceholderText("Search items…"); srch:SetPaintBackground(false)

    local iscroll=BUi.Create("BUi.Scroll",sb); iscroll:Dock(FILL)
    local function buildList(filter)
        iscroll:Clear()
        local sorted={}
        for k,v in pairs(adm.items) do
            if filter=="" or string.find(string.lower(v.name or k),filter,1,true) then
                table.insert(sorted,{key=k,item=v})
            end
        end
        table.sort(sorted,function(a,b) return (a.item.name or a.key)<(b.item.name or b.key) end)
        for _,si in ipairs(sorted) do
            local rar2=si.item.rarity and (si.item.rarity:sub(1,1):upper()..si.item.rarity:sub(2)) or "Common"
            local rc2=rclr(rar2)
            local row=BUi.Create("DButton",iscroll); row:Dock(TOP); row:DockMargin(8,3,8,0); row:SetTall(BUi:Scale(36))
            row:SetText(""); row:SetupTransition("hov",9,BUi.HoverFunc)
            local k=si.key; local v=si.item
            row:ClearPaint():On("Paint", function(s,w,h)
                local on=adm.selItem==k
                draw.RoundedBox(7,0,0,w,h,on and ColorAlpha(C.tert,35) or (s.hov>0.01 and ColorAlpha(C.tert,16) or C.accent))
                if on then draw.RoundedBox(3,0,h*.15,3,h*.7,C.tert) end
                draw.RoundedBox(4,w-12,h/2-5,7,10,rc2)
                draw.SimpleText(v.name or k,"BCORE.Unboxs.13",12,h/2-4,color_white,TEXT_ALIGN_LEFT,TEXT_ALIGN_CENTER)
                draw.SimpleText("["..k.."]","BCORE.Unboxs.10",12,h/2+6,ColorAlpha(C.cwhite,120),TEXT_ALIGN_LEFT,TEXT_ALIGN_CENTER)
            end)
            row:On("DoClick", function() adm.selItem=k; self:BuildItemEditor() end)
        end
    end
    buildList("")
    srch.OnChange=function(s) buildList(string.lower(s:GetValue())) end

    self.itemEditorHolder=BUi.Create("DPanel",self.body)
    self.itemEditorHolder:Stick(FILL); self.itemEditorHolder:DockMargin(8,0,0,0)
    self.itemEditorHolder:ClearPaint():Background(C.light,10):On("Paint", function(_,w,h)
        draw.RoundedBox(10,1,1,w-2,h-2,C.sec)
        if not adm.selItem then
            draw.SimpleText("← Select an item or create a new one","BCORE.Unboxs.18",
                w/2,h/2,ColorAlpha(C.cwhite,100),TEXT_ALIGN_CENTER,TEXT_ALIGN_CENTER)
        end
    end)
    self.itemEditorHolder:DockPadding(14,14,14,14)
    if adm.selItem then self:BuildItemEditor() end
end

function UA:BuildItemEditor()
    if not IsValid(self.itemEditorHolder) then return end
    self.itemEditorHolder:Clear(); self.itemEditorHolder:DockPadding(14,14,14,14)

    local isNew=adm.selItem=="__new__"
    local iname=not isNew and adm.selItem or nil
    local idef=(iname and adm.items[iname]) or {}
    local EP=self.itemEditorHolder
    -- NOTE: do NOT set idef.cansell here — it overwrites the value the server sent back.
    -- The dropdown reads idef.soldInStore directly below.

    local hdr=BUi.Create("DPanel",EP); hdr:Dock(TOP); hdr:SetTall(BUi:Scale(28)); hdr:SetPaintBackground(false)
    hdr:On("Paint", function(_,w,h)
        draw.SimpleText(isNew and "CREATE NEW ITEM" or "EDITING:  "..(idef.name or iname or ""),
            "BCORE.Unboxb.18",0,h/2,isNew and C.tert or color_white,TEXT_ALIGN_LEFT,TEXT_ALIGN_CENTER)
    end)

    local leftCol = BUi.Create("DPanel",EP)
    leftCol:Dock(LEFT); leftCol:DockMargin(0,8,16,0); leftCol:SetWide(BUi:Scale(280))
    leftCol:SetPaintBackground(false)

    local keyEntry   = makeField(leftCol,"INTERNAL KEY",  iname or "",        "e.g.  weapon_ak47")
    local nameEntry  = makeField(leftCol,"DISPLAY NAME",  idef.name or "",    "Shown in UI")
    local classEntry = makeField(leftCol,"SWEP CLASS",    idef.class or "",   "weapon_ak47")
    local typeEntry  = makeField(leftCol,"CATEGORY/TYPE", idef.type or "Weapon","Weapon / Consumable")
    local priceEntry = makeField(leftCol,"BASE PRICE",    idef.basePrice or 100,"",true)

    -- FIX: read soldInStore from the server data to set the correct default.
    -- Previously "idef.cansell = 'No'" was hardcoded here, which always reset
    -- the dropdown to No when opening a saved item.
    local canSellDefault = idef.soldInStore and "Yes" or "No"
    local cansell = makeDropdown(leftCol,"CAN SELL IN STORE",{"Yes","No"}, canSellDefault)

    local currentRar = idef.rarity and (idef.rarity:sub(1,1):upper()..idef.rarity:sub(2)) or "Common"
    local rarDrop    = makeDropdown(leftCol,"RARITY",RARITIES,currentRar)

    local btnRow=BUi.Create("DPanel",leftCol)
    btnRow:Dock(TOP); btnRow:DockMargin(0,12,0,0); btnRow:SetTall(BUi:Scale(36)); btnRow:SetPaintBackground(false)
    makeActionBtn(btnRow,"SAVE",C.tert,function()
        local p={
            oldKey      = iname,
            key         = keyEntry:GetValue():Trim(),
            name        = nameEntry:GetValue():Trim(),
            class       = classEntry:GetValue():Trim(),
            type        = typeEntry:GetValue():Trim(),
            rarity      = string.lower(rarDrop:GetValue() or "common"),
            basePrice   = tonumber(priceEntry:GetValue()) or 100,
            -- FIX: actually include the cansell value in the payload
            soldInStore = cansell:GetValue() == "Yes",
        }
        if p.key=="" then BCORE.Unbox:Toast("Error","Key cannot be empty",Color(220,60,60)); return end
        thread.Start("BCORE:UnboxAdmin.SaveItem",p)
    end)
    if not isNew then
        makeActionBtn(btnRow,"🗑 DELETE",Color(220,60,60),function()
            local popup=BUi.Create("BUi.Popup"); popup:SetName("Delete Item?")
            popup:SetMode("textentry",{placeholder="Type DELETE to confirm",callback=function(txt)
                if txt=="DELETE" then thread.Start("BCORE:UnboxAdmin.DeleteItem",{key=iname}); adm.selItem=nil end
            end})
        end)
    end

    local rightCol=BUi.Create("DPanel",EP); rightCol:Dock(FILL); rightCol:DockMargin(0,8,0,0); rightCol:SetPaintBackground(false)
    local pvHdr=BUi.Create("DPanel",rightCol); pvHdr:Dock(TOP); pvHdr:SetTall(BUi:Scale(22)); pvHdr:SetPaintBackground(false)
    pvHdr:On("Paint", function(_,w,h)
        draw.SimpleText("PREVIEW","BCORE.Unboxb.14",0,h/2,ColorAlpha(C.cwhite,150),TEXT_ALIGN_LEFT,TEXT_ALIGN_CENTER)
    end)
    local preview=BUi.Create("DPanel",rightCol)
    preview:Dock(TOP); preview:DockMargin(0,6,0,0); preview:SetTall(BUi:Scale(200))
    preview:ClearPaint():Background(C.light,10)
    preview:On("Paint", function(s,w,h)
        local rar2=rarDrop:GetValue() or "Common"; local rc2=rclr(rar2)
        local pName=nameEntry:GetValue(); local pClass=classEntry:GetValue()
        local pPrice=tonumber(priceEntry:GetValue()) or 0; local pType=typeEntry:GetValue()
        local pSell=cansell:GetValue()=="Yes"
        draw.RoundedBox(10,0,0,w,h,ColorAlpha(rc2,40)); draw.RoundedBox(10,2,2,w-4,h-4,C.sec)
        draw.RoundedBox(10,2,2,w-4,5,rc2); draw.RoundedBox(0,2,5,w-4,4,rc2)
        local px,py2,pw2,ph3=BUi:Scale(10),BUi:Scale(16),w-BUi:Scale(20),BUi:Scale(90)
        draw.RoundedBox(8,px,py2,pw2,ph3,ColorAlpha(C.bg,180))
        draw.RoundedBox(8,px,py2,pw2,ph3,ColorAlpha(rc2,60))
        local sz=BUi:Scale(20); local cx3,cy3=w/2,py2+ph3/2
        draw.RoundedBox(sz,cx3-sz,cy3-sz,sz*2,sz*2,ColorAlpha(rc2,120))
        draw.SimpleText((pType~="" and pType or "W"):sub(1,1):upper(),"BCORE.Unboxb.20",cx3,cy3,color_white,TEXT_ALIGN_CENTER,TEXT_ALIGN_CENTER)
        local by2=py2+ph3+BUi:Scale(8)
        draw.RoundedBox(4,BUi:Scale(8),by2,BUi:Scale(72),BUi:Scale(18),ColorAlpha(rc2,195))
        draw.SimpleText(string.upper(rar2),"BCORE.Unboxs.11",BUi:Scale(8)+BUi:Scale(36),by2+BUi:Scale(9),color_white,TEXT_ALIGN_CENTER,TEXT_ALIGN_CENTER)
        draw.SimpleText(pName~="" and pName or "(no name)","BCORE.Unboxs.15",w/2,by2+BUi:Scale(24),color_white,TEXT_ALIGN_CENTER,TEXT_ALIGN_CENTER)
        draw.SimpleText("["..( pClass~="" and pClass or "no class").."]","BCORE.Unboxs.11",w/2,by2+BUi:Scale(42),ColorAlpha(C.cwhite,120),TEXT_ALIGN_CENTER,TEXT_ALIGN_CENTER)
        draw.SimpleText("$"..tostring(pPrice),"BCORE.Unboxs.18",w/2,by2+BUi:Scale(62),C.moneygreen,TEXT_ALIGN_CENTER,TEXT_ALIGN_CENTER)
        -- store badge
        local badgeClr = pSell and Color(60,200,100) or Color(180,60,60)
        draw.RoundedBox(4,w-BUi:Scale(72)-BUi:Scale(8),by2,BUi:Scale(72),BUi:Scale(18),ColorAlpha(badgeClr,180))
        draw.SimpleText(pSell and "IN STORE" or "NOT FOR SALE","BCORE.Unboxs.10",
            w-BUi:Scale(8)-BUi:Scale(36),by2+BUi:Scale(9),color_white,TEXT_ALIGN_CENTER,TEXT_ALIGN_CENTER)
    end)
end

function UA:BuildLogsTab()
    local scroll=BUi.Create("BUi.Scroll",self.body); scroll:Dock(FILL)
    if #adm.logs==0 then
        local empty=BUi.Create("DPanel",scroll); empty:Dock(TOP); empty:SetTall(BUi:Scale(80)); empty:SetPaintBackground(false)
        empty:On("Paint", function(_,w,h)
            draw.SimpleText("No admin logs yet.","BCORE.Unboxs.18",w/2,h/2,ColorAlpha(C.cwhite,100),TEXT_ALIGN_CENTER,TEXT_ALIGN_CENTER)
        end)
        return
    end
    local ACT={SaveCase=Color(80,200,120),DeleteCase=Color(220,70,70),SaveItem=Color(90,160,240),DeleteItem=Color(220,70,70),ImportWeapons=Color(180,100,240)}
    for i=#adm.logs,1,-1 do
        local log=adm.logs[i]; local ac=ACT[log.action] or Color(180,180,180)
        local row=BUi.Create("DPanel",scroll); row:Dock(TOP); row:DockMargin(0,4,0,0); row:SetTall(BUi:Scale(36))
        row:ClearPaint():Background(C.light,7):On("Paint", function(_,w,h)
            draw.RoundedBox(7,1,1,w-2,h-2,C.sec); draw.RoundedBox(3,1,h*.15,3,h*.7,ac)
            draw.SimpleText(os.date("%H:%M:%S",log.time),"BCORE.Unboxs.12",14,h/2,ColorAlpha(C.cwhite,130),TEXT_ALIGN_LEFT,TEXT_ALIGN_CENTER)
            draw.SimpleText(log.admin or "?","BCORE.Unboxs.13",BUi:Scale(70),h/2,color_white,TEXT_ALIGN_LEFT,TEXT_ALIGN_CENTER)
            draw.SimpleText(log.action or "?","BCORE.Unboxs.13",BUi:Scale(210),h/2,ac,TEXT_ALIGN_LEFT,TEXT_ALIGN_CENTER)
            draw.SimpleText(log.detail or "","BCORE.Unboxs.12",BUi:Scale(350),h/2,ColorAlpha(C.cwhite,150),TEXT_ALIGN_LEFT,TEXT_ALIGN_CENTER)
        end)
    end
end

function UA:BuildPlayersTab()
    local body = self.body

    -- Left: player list
    local lp = BUi.Create("DPanel", body)
    lp:Stick(LEFT,0,0,8,0,8); lp:SetWide(BUi:Scale(220))
    lp:ClearPaint():Background(C.light,10):On("Paint",function(_,w,h)
        draw.RoundedBox(10,1,1,w-2,h-2,C.sec)
        draw.SimpleText("PLAYERS","BCORE.Unboxs.13",w/2,18,C.cwhite,TEXT_ALIGN_CENTER,TEXT_ALIGN_CENTER)
        draw.RoundedBox(0,10,32,w-20,1,ColorAlpha(C.tert,80))
    end)
    lp:DockPadding(8,40,8,8)

    local plyscroll = BUi.Create("BUi.Scroll",lp); plyscroll:Dock(FILL)
    for _,ply in ipairs(player.GetAll()) do
        local uid  = ply:UserID()
        local name = ply:Nick()
        local pb   = BUi.Create("DButton",plyscroll); pb:Dock(TOP); pb:DockMargin(0,4,0,0)
        pb:SetTall(BUi:Scale(38)); pb:SetText("")
        pb:SetupTransition("hov",9,BUi.HoverFunc)
        pb:ClearPaint():Background(C.light,7):On("Paint",function(s,w,h)
            local sel = adm.selPlayer and adm.selPlayer.userID==uid
            draw.RoundedBox(7,1,1,w-2,h-2, sel and ColorAlpha(C.tert,40) or C.sec)
            if sel then draw.RoundedBox(3,1,h*.2,3,h*.6,C.tert) end
            draw.SimpleText(name,"BCORE.Unboxs.13",14,h/2,color_white,TEXT_ALIGN_LEFT,TEXT_ALIGN_CENTER)
        end)
        pb:On("DoClick",function()
            thread.Start("BCORE:UnboxAdmin.GetPlayerInv",{userID=uid})
        end)
    end

    -- Right: inventory view
    local rp = BUi.Create("DPanel", body)
    rp:Stick(FILL,0,0,0,0,8); rp:ClearPaint()

    local sp = adm.selPlayer
    if not sp then
        rp:On("Paint",function(_,w,h)
            draw.SimpleText("← Select a player to view their inventory",
                "BCORE.Unboxs.15",w/2,h/2,ColorAlpha(C.cwhite,80),TEXT_ALIGN_CENTER,TEXT_ALIGN_CENTER)
        end)
        return
    end

    -- Header
    local hdr = BUi.Create("DPanel",rp); hdr:Dock(TOP); hdr:SetTall(BUi:Scale(44))
    hdr:ClearPaint():Background(C.light,8):On("Paint",function(_,w,h)
        draw.RoundedBox(10,1,1,w-2,h-2,C.sec)
        draw.SimpleText(sp.name or "?","BCORE.Unboxb.16",14,h/2,C.cwhite,TEXT_ALIGN_LEFT,TEXT_ALIGN_CENTER)
        draw.SimpleText(sp.steamid or "","BCORE.Unboxs.12",w-BUi:Scale(130),h/2,ColorAlpha(C.cwhite,110),TEXT_ALIGN_RIGHT,TEXT_ALIGN_CENTER)
    end)

    local wipeBtn = BUi.Create("DButton",hdr)
    wipeBtn:Stick(RIGHT,0,6,6,6,0); wipeBtn:SetWide(BUi:Scale(100)); wipeBtn:SetText("")
    wipeBtn:ClearPaint():Background(C.light,5):On("Paint",function(s,w,h)
        draw.RoundedBox(6,1,1,w-2,h-2,Color(180,40,40))
        draw.SimpleText("🗑 WIPE INV","BCORE.Unboxs.12",w/2,h/2,color_white,TEXT_ALIGN_CENTER,TEXT_ALIGN_CENTER)
    end)
    wipeBtn:FadeHover(Color(255,255,255,25),6,8)
    wipeBtn:On("DoClick",function()
        local popup=BUi.Create("BUi.Popup"); popup:SetName("Wipe "..sp.name.."'s inventory?")
        popup:SetMode("textentry",{placeholder="Type WIPE to confirm — removes all items & cases",callback=function(txt)
            if txt=="WIPE" then
                thread.Start("BCORE:UnboxAdmin.WipePlayerInv",{userID=sp.userID})
                BCORE.Unbox:Toast("Wiped",sp.name.."'s inventory cleared",Color(220,60,60))
            end
        end})
    end)

    -- Section label helper
    local function section(parent, txt)
        local s=BUi.Create("DPanel",parent); s:Dock(TOP); s:DockMargin(0,10,0,4); s:SetTall(BUi:Scale(22))
        s:SetPaintBackground(false)
        s:On("Paint",function(_,w,h)
            draw.SimpleText(txt,"BCORE.Unboxs.12",0,h/2,ColorAlpha(C.cwhite,140),TEXT_ALIGN_LEFT,TEXT_ALIGN_CENTER)
            draw.RoundedBox(0,BUi:Scale(80),h/2,w-BUi:Scale(84),1,ColorAlpha(C.cwhite,30))
        end)
    end

    local invScroll = BUi.Create("BUi.Scroll",rp); invScroll:Dock(FILL)
    invScroll:DockMargin(0,8,0,0)

    -- ITEMS
    section(invScroll, "ITEMS  ("..table.Count(sp.inventory or {})..")")
    local invGrid = vgui.Create("DIconLayout", invScroll)
    invGrid:Dock(TOP); invGrid:SetWide(rp:GetWide()-20)
    invGrid:SetSpaceX(6); invGrid:SetSpaceY(6)

    local RCLR2={common=Color(190,190,190),uncommon=Color(0,200,80),rare=Color(30,120,255),epic=Color(175,30,255),legendary=Color(255,195,0)}
    local IW,IH = BUi:Scale(120), BUi:Scale(54)

    for ikey,qty in pairs(sp.inventory or {}) do
        local idata = adm.items[ikey] or {}
        local rr    = string.lower(idata.rarity or "common")
        local rc2   = RCLR2[rr] or Color(190,190,190)
        local iname = idata.name or ikey
        local tile  = invGrid:Add("DPanel"); tile:SetSize(IW,IH)
        tile:SetPaintBackground(false); tile:SetMouseInputEnabled(true)
        tile.Paint = function(s,w,h)
            s._hov=Lerp(FrameTime()*9,s._hov or 0,s:IsHovered() and 1 or 0)
            draw.RoundedBox(7,0,0,w,h,ColorAlpha(rc2,30+s._hov*30))
            draw.RoundedBox(7,1,1,w-2,h-2,C.sec)
            draw.RoundedBox(3,1,1,3,h-2,rc2)
            draw.SimpleText(BUi.Truncate(iname,12),"BCORE.Unboxs.12",10,h/2-7,color_white,TEXT_ALIGN_LEFT,TEXT_ALIGN_CENTER)
            draw.SimpleText("×"..qty,"BCORE.Unboxs.15",10,h/2+7,ColorAlpha(C.cwhite,160),TEXT_ALIGN_LEFT,TEXT_ALIGN_CENTER)
        end
        -- delete one button (top-right)
        local del=BUi.Create("DButton",tile); del:SetPos(IW-22,2); del:SetSize(20,20); del:SetText("")
        del:SetMouseInputEnabled(true)
        del:ClearPaint():On("Paint",function(_,w2,h2)
            draw.RoundedBox(4,1,1,w2-2,h2-2,Color(180,40,40))
            draw.SimpleText("✕","BCORE.Unboxs.10",w2/2,h2/2,color_white,TEXT_ALIGN_CENTER,TEXT_ALIGN_CENTER)
        end)
        local ik=ikey
        del:On("DoClick",function()
            thread.Start("BCORE:UnboxAdmin.RemovePlayerItem",{userID=sp.userID,itemKey=ik,amount=1})
        end)
    end
    invGrid:SizeToChildren(false,true)

    -- CASES
    section(invScroll, "CASES  ("..table.Count(sp.cases or {})..")")
    local caseGrid = vgui.Create("DIconLayout", invScroll)
    caseGrid:Dock(TOP); caseGrid:SetWide(rp:GetWide()-20)
    caseGrid:SetSpaceX(6); caseGrid:SetSpaceY(6)

    for ckey,qty in pairs(sp.cases or {}) do
        local cdata = adm.cases[ckey] or {}
        local rr    = string.lower(cdata.Rarity or "common")
        local rc2   = RCLR2[rr] or Color(190,190,190)
        local cname = cdata.Name or ckey
        local tile  = caseGrid:Add("DPanel"); tile:SetSize(IW,IH)
        tile:SetPaintBackground(false); tile:SetMouseInputEnabled(true)
        tile.Paint = function(s,w,h)
            s._hov=Lerp(FrameTime()*9,s._hov or 0,s:IsHovered() and 1 or 0)
            draw.RoundedBox(7,0,0,w,h,ColorAlpha(rc2,30+s._hov*30))
            draw.RoundedBox(7,1,1,w-2,h-2,C.sec)
            draw.RoundedBox(3,1,1,3,h-2,rc2)
            draw.SimpleText(BUi.Truncate(cname,12),"BCORE.Unboxs.12",10,h/2-7,color_white,TEXT_ALIGN_LEFT,TEXT_ALIGN_CENTER)
            draw.SimpleText("×"..qty,"BCORE.Unboxs.15",10,h/2+7,ColorAlpha(C.cwhite,160),TEXT_ALIGN_LEFT,TEXT_ALIGN_CENTER)
        end
        local del=BUi.Create("DButton",tile); del:SetPos(IW-22,2); del:SetSize(20,20); del:SetText("")
        del:SetMouseInputEnabled(true)
        del:ClearPaint():On("Paint",function(_,w2,h2)
            draw.RoundedBox(4,1,1,w2-2,h2-2,Color(180,40,40))
            draw.SimpleText("✕","BCORE.Unboxs.10",w2/2,h2/2,color_white,TEXT_ALIGN_CENTER,TEXT_ALIGN_CENTER)
        end)
        local ck=ckey
        del:On("DoClick",function()
            thread.Start("BCORE:UnboxAdmin.RemovePlayerCase",{userID=sp.userID,caseKey=ck,amount=1})
        end)
    end
    caseGrid:SizeToChildren(false,true)
end

concommand.Add("open_unbox_admin", function() BCORE.Unbox:OpenUnboxAdmin() end)