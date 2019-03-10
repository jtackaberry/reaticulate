cmdlist = reaper.GetExtState("reaticulate", "command")
local cmd = (cmdlist or '') .. ' activate_selected_articulation=0'
reaper.SetExtState("reaticulate", "command", cmd, false)