-- Lets a player place a purely CLIENTSIDE ghost prop of a CASE out in the world - placing it is
-- the ritual that actually OPENS that case (fires the real BCORE:UnboxOpenCase request), not a
-- permanent decoration. "Clientside" still matters for the ghost/preview itself (never
-- networked, costs zero server load while you're aiming it) but the placement's real EFFECT
-- (opening the case) is the same server-authoritative action the plain OPEN button already
-- uses - this is just a different, one-at-a-time way to trigger it. This was originally built
-- for already-unboxed ITEMS as a static display piece; that's wrong - only cases are ever
-- placeable, and placing one always opens it.
local ghostProp        = nil
local placementActive  = false
local placeModel       = nil
local placementOnConfirm = nil

local GHOST_COLOR = Color(255, 255, 255, 140)

local function StopPlacement()
    placementActive = false
    if IsValid(ghostProp) then
        ghostProp:Remove()
    end
    ghostProp = nil
    placeModel = nil
    placementOnConfirm = nil
end

local function ConfirmPlacement()
    if not IsValid(ghostProp) then
        StopPlacement()
        return
    end

    local onConfirm = placementOnConfirm
    local placedProp = ghostProp

    -- The ghost briefly becomes solid/full-opacity to sell "you just set this down", then gets
    -- removed shortly after - the case itself is being CONSUMED by opening it, not left behind
    -- as a permanent prop the way an item's own (now-removed) placement used to work.
    placedProp:SetColor(Color(255, 255, 255, 255))
    placedProp:SetRenderMode(RENDERMODE_NORMAL)

    timer.Simple(0.35, function()
        if IsValid(placedProp) then placedProp:Remove() end
    end)

    if onConfirm then onConfirm() end

    placementActive = false
    ghostProp = nil
    placeModel = nil
    placementOnConfirm = nil
end

-- onConfirm is required in practice (only cases call this now) but kept optional here rather
-- than asserted, in case something else ever wants a purely decorative placement again later.
function BCORE.Unbox:StartPlacement(model, onConfirm)
    if not model or model == "" then return end
    StopPlacement()

    local ok, ent = pcall(ClientsideModel, model, RENDERGROUP_TRANSLUCENT)
    if not ok or not IsValid(ent) then return end

    ent:SetColor(GHOST_COLOR)
    ent:SetRenderMode(RENDERMODE_TRANSALPHA)
    ent:SetNoDraw(false)

    ghostProp        = ent
    placeModel       = model
    placementActive  = true
    placementOnConfirm = onConfirm

    BCORE.Unbox:Toast("Placement mode", "Left click to place and open, right click to cancel.", Color(120, 180, 255))
end

function BCORE.Unbox:IsPlacementActive()
    return placementActive
end

hook.Add("Think", "BCORE.Unbox.PlacementGhost", function()
    if not placementActive or not IsValid(ghostProp) then return end

    local ply = LocalPlayer()
    if not IsValid(ply) then return end

    local tr = ply:GetEyeTrace()
    if not tr.Hit then return end

    ghostProp:SetPos(tr.HitPos)
    ghostProp:SetAngles(Angle(0, ply:EyeAngles().y, 0))
end)

-- Intercepts +attack/+attack2 ONLY while placement mode is active, so a normal left-click
-- still fires the player's held weapon exactly as always the rest of the time. Returning true
-- from PlayerBindPress is the standard, safe way to suppress a bind's default action for one
-- press without disabling the weapon/input system as a whole.
hook.Add("PlayerBindPress", "BCORE.Unbox.PlacementInput", function(ply, bind, pressed)
    if not placementActive or not pressed then return end

    bind = string.lower(bind)
    if bind == "+attack" then
        ConfirmPlacement()
        return true
    elseif bind == "+attack2" then
        StopPlacement()
        return true
    end
end)

hook.Add("HUDPaint", "BCORE.Unbox.PlacementHint", function()
    if not placementActive then return end
    draw.SimpleText("LEFT CLICK: Place & Open    RIGHT CLICK: Cancel", "BCORE.Unboxb.18",
        ScrW() / 2, ScrH() - 60, color_white, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
end)
