_, _, _, _, _, _, val = reaper.get_action_context()
reaper.SetProjExtState(0, "reaticulate", "command", "activate_articulation=08," .. tostring(val))
