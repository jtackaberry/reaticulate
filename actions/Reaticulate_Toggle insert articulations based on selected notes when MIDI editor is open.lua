_, _, section_id, cmd_id, _, _, val = reaper.get_action_context()
cmd = string.format('set_toggle_option=art_insert_at_selected_notes,-1,%s,%s', section_id, cmd_id)
reaper.SetExtState("reaticulate", "command", cmd, false)
