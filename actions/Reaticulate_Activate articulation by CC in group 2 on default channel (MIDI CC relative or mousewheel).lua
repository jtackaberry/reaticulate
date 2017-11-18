_, _, _, _, mode, res, val = reaper.get_action_context()
_, cmdlist = reaper.GetProjExtState(0, "reaticulate", "command")
cmd = string.format(' activate_relative_articulation=0,2,%d,%d,%d', mode, res, val)
reaper.SetProjExtState(0, "reaticulate", "command", (cmdlist or '') .. cmd)