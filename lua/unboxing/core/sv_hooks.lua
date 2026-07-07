local u = BCORE.Unbox

hook.Add("PlayerInitialSpawn", "BCORE_Unbox_Load", function(ply)
    u:LoadPlayer(ply)
    timer.Simple(1, function()
        if IsValid(ply) then
            u:Sync(ply)
            print("INITSPAWN CALLSED PLAYERS SHOULD BE SYNCED")
        end
    end)
end)

hook.Add("PlayerDisconnected", "BCORE_Unbox_Save", function(ply)
    u:SavePlayer(ply)
end)

hook.Add("ShutDown", "BCORE_Unbox_SaveAll", function()
    for _, ply in ipairs(player.GetAll()) do
        u:SavePlayer(ply)
    end
end)

hook.Add("InitPostEntity", "BCORE_Unbox_ImportWeapons", function()
    u:ImportWeapons()
end)
