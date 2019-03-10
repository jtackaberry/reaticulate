cmdlist = reaper.GetExtState("reaticulate", "command")
cmd = ' insert_articulation=0'
reaper.SetExtState("reaticulate", "command", (cmdlist or '') .. cmd, false)