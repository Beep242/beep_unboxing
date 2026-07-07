BCORE.Unbox.UI = BCORE.Unbox.UI or {}
local u = BCORE.Unbox.UI.networking
local thread = BCORE.netstream

for i = 1, 200 do
    BUi:CreateFont("BCORE.Unbox." .. i, "Montserrat", i, 500)
    BUi:CreateFont("BCORE.Unboxs." .. i, "Montserrat", i, 600)
    BUi:CreateFont("BCORE.Unboxb." .. i, "Montserrat", i, 1024)
end


thread.Hook("BCORE:UnboxSendData", function(data)
    print("HEY")
    print(data)
    LocalPlayer().BCORE_UNBOX_DATA = data or {}
    PrintTable(LocalPlayer().BCORE_UNBOX_DATA)
end)

