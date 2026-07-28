-- Font creation and the BCORE:UnboxSendData handler both used to be duplicated here -
-- cl_main.lua already creates the same fonts and is the one real place that message is
-- handled now (netstream.Hook only holds one callback per message name, so a second
-- registration here was silently replacing whichever of the two loaded last rather than
-- running alongside it - see cl_main.lua's own comment on its hook for the full story).
BCORE.Unbox.UI = BCORE.Unbox.UI or {}

