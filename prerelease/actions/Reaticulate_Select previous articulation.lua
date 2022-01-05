cmdlist = reaper.GetExtState("reaticulate", "command")
cmd = (cmdlist or '') .. ' select_relative_articulation=2,127,-1'
reaper.SetExtState("reaticulate", "command", cmd, false)