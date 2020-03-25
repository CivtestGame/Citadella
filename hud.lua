
-- Citadella HUDs, since it's nice to always know if you have modes enabled.

local ct_huds = {}
local ct_huds_bg = {}
local ct_huds_mode = {}
local ct_huds_group = {}
local ct_huds_bypass = {}

local Y_OFFSET_SPACE = 26
local X_OFFSET_SPACE = -90

function ct.remove_hud(player)
   local pname = player:get_player_name()

   local _
   _ = ct_huds[pname] and player:hud_remove(ct_huds[pname])
   _ = ct_huds_bg[pname] and player:hud_remove(ct_huds_bg[pname])
   _ = ct_huds_mode[pname] and player:hud_remove(ct_huds_mode[pname])
   _ = ct_huds_group[pname] and player:hud_remove(ct_huds_group[pname])
   _ = ct_huds_bypass[pname] and player:hud_remove(ct_huds_bypass[pname])

   ct_huds[pname] = nil
   ct_huds_bg[pname] = nil
   ct_huds_mode[pname] = nil
   ct_huds_group[pname] = nil
   ct_huds_bypass[pname] = nil
end

minetest.register_on_leaveplayer(function(player)
      ct.remove_hud(player)
end)

minetest.register_on_joinplayer(function(player)
      ct.update_hud(player)
end)

function ct.update_hud(player)
   local pname = player:get_player_name()

   local mode = ct.player_modes[pname]
   local bypass = ct.player_bypass[pname]

   -- remove existing huds if no modes are enabled
   if not (mode or bypass) then
      ct.remove_hud(player)
      return
   end

   local title_idx = ct_huds[pname]
   local bg_idx = ct_huds_bg[pname]
   local mode_idx = ct_huds_mode[pname]
   local group_idx = ct_huds_group[pname]
   local bypass_idx = ct_huds_bypass[pname]

   local modestring = "Mode: NONE"
   local mode_color = 0x888888
   if mode then
      modestring = "Mode: " .. mode:upper()
      mode_color = 0xFFFFFF
   end

   local groupstring = "Group: N/A"
   local group_color = 0x888888
   if mode == "fortify" or mode == "reinforce" then
      groupstring = "Group: " .. ct.player_current_reinf_group[pname].name
      group_color = 0xFFFFFF
   end

   local bypassstring = "Bypass: OFF"
   local bypass_color = 0x888888
   if bypass then
      bypassstring = "Bypass: ON"
      bypass_color = 0xFFFFFF
   end

   local y_offset = -Y_OFFSET_SPACE

   if not title_idx then
      local bg_new_idx = player:hud_add({
            hud_elem_type = "image",
            position  = {x = 1, y = 0.5},
            offset    = {x = -180, y = 14},
            text      = "citadella_hud_bg.png",
            scale     = { x = 1, y = 1},
            alignment = { x = 1, y = 0 },
      })
      ct_huds_bg[pname] = bg_new_idx

      local new_idx = player:hud_add({
            hud_elem_type = "text",
            text      = "Citadella",
            position  = {x = 1, y = 0.5},
            offset    = {x = X_OFFSET_SPACE, y = y_offset},
            alignment = -1,
            scale     = { x = 50, y = 10},
            number    = 0x00FF00,
      })
      ct_huds[pname] = new_idx
      y_offset = y_offset + Y_OFFSET_SPACE
   end

   if mode_idx then
      player:hud_change(mode_idx, "text", modestring)
      player:hud_change(mode_idx, "number", mode_color)
   else
      local mode_new_idx = player:hud_add({
            hud_elem_type = "text",
            text      = modestring,
            position  = {x = 1, y = 0.5},
            offset    = {x = X_OFFSET_SPACE, y = y_offset},
            alignment = -1,
            scale     = { x = 50, y = 10},
            number    = mode_color,
      })
      ct_huds_mode[pname] = mode_new_idx
      y_offset = y_offset + Y_OFFSET_SPACE
   end

   if group_idx then
      player:hud_change(group_idx, "text", groupstring)
      player:hud_change(group_idx, "number", group_color)
   else
      local group_new_idx = player:hud_add({
            hud_elem_type = "text",
            text      = groupstring,
            position  = {x = 1, y = 0.5},
            offset    = {x = X_OFFSET_SPACE, y = y_offset},
            alignment = -1,
            scale     = { x = 50, y = 10},
            number    = group_color,
      })
      ct_huds_group[pname] = group_new_idx
      y_offset = y_offset + Y_OFFSET_SPACE
   end

   if bypass_idx then
      player:hud_change(bypass_idx, "text", bypassstring)
      player:hud_change(bypass_idx, "number", bypass_color)
   else
      local bypass_new_idx = player:hud_add({
            hud_elem_type = "text",
            text      = bypassstring,
            position  = {x = 1, y = 0.5},
            offset    = {x = X_OFFSET_SPACE, y = y_offset},
            alignment = -1,
            scale     = { x = 50, y = 10},
            number    = bypass_color,
      })
      ct_huds_bypass[pname] = bypass_new_idx
   end

end
