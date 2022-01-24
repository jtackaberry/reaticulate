_, _, _, _, mode, res, val = reaper.get_action_context()
cmdlist = reaper.GetExtState("reaticulate", "command")
cmd = string.format('select_relative_articulation=%d,%d,%d', mode, res, val)
reaper.SetExtState("reaticulate", "command", (cmdlist or '') .. cmd, false)