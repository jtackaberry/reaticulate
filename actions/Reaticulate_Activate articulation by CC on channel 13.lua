_, _, _, _, _, _, val = reaper.get_action_context()
reaper.SetExtState("reaticulate", "command", "activate_articulation=13," .. tostring(val), false)
