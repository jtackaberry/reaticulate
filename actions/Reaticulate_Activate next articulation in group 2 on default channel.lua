cmdlist = reaper.GetExtState("reaticulate", "command")
cmd = ' activate_relative_articulation=0,2,2,127,1'
reaper.SetExtState("reaticulate", "command", (cmdlist or '') .. cmd, false)