
local stone_limit = tonumber(minetest.settings:get("stone_limit")) or 25
local iron_limit = tonumber(minetest.settings:get("iron_limit")) or 250
local diamond_limit = tonumber(minetest.settings:get("diamond_limit")) or 1800

ct.resource_limits = {
   ["default:stone"]   = stone_limit,
   ["default:copper_ingot"] = iron_limit,
   ["default:tin_ingot"] = iron_limit,
   ["default:steel_ingot"] = diamond_limit
}

ct.PLAYER_MODE_REINFORCE = "reinforce"
ct.PLAYER_MODE_FORTIFY = "fortify"
ct.PLAYER_MODE_INFO = "info"
ct.PLAYER_MODE_CHANGE = "change"

-- Mapping of Player -> Citadel mode
ct.player_modes = {}

-- Citadella bypass is tracked separately to the other modes. It's useful to be
-- able to have bypass mode enabled in parallel to fortify.
ct.player_bypass = {}

ct.player_current_reinf_group = {}
ct.player_fortify_material = {}


-- Implementation of a Citadella placement border.

local zerozero = vector.new(0, 0, 0)

local citadella_border_radius = tonumber(minetest.settings:get("citadella_border_radius"))
if not citadella_border_radius then
   citadella_border_radius = 1000
   minetest.log(
      "warning",
      "No Citadella reinforcement border radius specified, defaulting to "
         .. tonumber(citadella_border_radius) .. "."
   )
else
   minetest.log(
      "Citadella reinforcement border radius set to "
         .. tonumber(citadella_border_radius) .. "."
   )
end

function ct.position_in_citadella_border(pos)
   local pos_no_y = vector.new(pos.x, 0, pos.z)
   return vector.distance(pos_no_y, zerozero) < citadella_border_radius
end

-- Item/node reinforcement blacklisting

function ct.blacklisted_node(name)
   local def = core.registered_nodes[name]
   local is_blacklisted = false
   if def and def.groups then
      is_blacklisted = def.groups.attached_node
         or def.groups.falling_node
         or def.groups.leaves -- TODO: allow reinforcement of placed leaves
         or def.groups.leafdecay
         or name == "tnt:tnt"
   end
   return is_blacklisted
end

-- Container/node locking privileges

function ct.has_locked_container_privilege(pos, player)
   local pname = player:get_player_name()
   local reinf = ct.get_reinforcement(pos)
   if not reinf then
      return true
   end

   local player_id = pm.get_player_by_name(pname).id
   local reinf_ctgroup_id = reinf.ctgroup_id

   local player_in_group = pm.get_player_group(player_id, reinf_ctgroup_id)

   if not player_in_group then
      return false
   end

   local group = pm.get_group_by_id(reinf_ctgroup_id)

   return true, reinf, group
end


function ct.has_locked_chest_privilege(pos, player, description)
   local has_privilege, reinf, group
      = ct.has_locked_container_privilege(pos, player)
   if has_privilege then
      return true, reinf, group
   end
   local pname = player:get_player_name()
   minetest.chat_send_player(pname, description .. " is locked!")
   return false
end


local function set_parameterized_mode(name, param, mode)
   local player = minetest.get_player_by_name(name)
   if not player then
      return false
   end
   local pname = player:get_player_name()
   local current_pmode = ct.player_modes[pname]
   if current_pmode == nil or current_pmode ~= mode then
      local player = pm.get_player_by_name(pname)
      local ctgroup = pm.get_group_by_name(param)
      if not ctgroup then
         minetest.chat_send_player(
            pname,
            "Group '" .. param .. "' does not exist."
         )
         return false
      end
      local player_group = pm.get_player_group(player.id, ctgroup.id)
      if not player_group then
         minetest.chat_send_player(
            pname,
            "You are not on group '" .. param .. "'."
         )
         return false
      end
      ct.player_modes[pname] = mode
      ct.player_current_reinf_group[pname] = ctgroup
      minetest.chat_send_player(
         pname,
         "Citadella mode: " .. ct.player_modes[pname] ..
            " (group: '" .. ctgroup.name .. "')"
      )
   else
      ct.player_modes[pname] = nil
      minetest.chat_send_player(
         pname,
         "Citadella mode: " .. (ct.player_modes[pname] or "normal")
      )
   end
   ct.update_hud(player)
   return true
end


minetest.register_chatcommand("ctr", {
   params = "<group>",
   description = "Citadella REINFORCE mode. "
      .."Reinforces punched nodes with the held material.",
   func = function(name, param)
      set_parameterized_mode(name, param, ct.PLAYER_MODE_REINFORCE)
   end
})

minetest.register_chatcommand("ctc", {
   params = "<group>",
   description = "Citadella CHANGE mode. "
      .."Changes the reinforcement group of punched nodes.",
   func = function(name, param)
      set_parameterized_mode(name, param, ct.PLAYER_MODE_CHANGE)
   end
})

function ct.get_valid_reinforcement_items()
   local valid_names = pmutils.table_keyvals(ct.resource_limits)
   local valid_descriptions = {}
   for i,name in ipairs(valid_names) do
      valid_descriptions[i] = core.registered_items[name].description
   end
   return valid_names, valid_descriptions
end

minetest.register_chatcommand("ctf", {
   params = "",
   description = "Citadella FORTIFY mode. "
      .."Automatically reinforces placed nodes.",
   func = function(name, param)
      local player = minetest.get_player_by_name(name)
      if not player then
         return false
      end
      local pname = player:get_player_name()
      local item = player:get_wielded_item()
      local item_name = item:get_name()
      local item_description = item:get_definition().description

      local resource_limit = ct.resource_limits[item_name]
      if resource_limit then
         ct.player_fortify_material[pname] = item_name
         set_parameterized_mode(pname, param, ct.PLAYER_MODE_FORTIFY)
         return true
      else
         local valid_names, valid_descs = ct.get_valid_reinforcement_items()
         minetest.chat_send_player(
            pname,
            "Error: " .. item_description .. " is not a valid reinforcement"
               .. " material (" .. table.concat(valid_descs, ", ") .. ")."
         )
         return false
      end
   end
})

minetest.register_chatcommand("ctm", {
   params = "",
   description = "List valid Citadella reinforcement materials.",
   func = function(name, param)
         local valid_names, valid_descs = ct.get_valid_reinforcement_items()
         local cleaned = {}
         for i,name in ipairs(valid_names) do
            cleaned[i] = valid_descs[i] .. " ("
               .. tostring(ct.resource_limits[name]) .. ")"
         end

         minetest.chat_send_player(
            name, "Valid Citadella materials: "..table.concat(cleaned, ", ")
         )
   end
})

local function toggle_bypass_mode(name)
   if not ct.player_bypass[name] then
      minetest.chat_send_player(name, "Citadella bypass mode: enabled.")
      ct.player_bypass[name] = true
   else
      minetest.chat_send_player(name, "Citadella bypass mode: disabled.")
      ct.player_bypass[name] = nil
   end
   ct.update_hud(minetest.get_player_by_name(name))
end

local function set_simple_mode(name, mode)
   local player = minetest.get_player_by_name(name)
   if not player then
      return false
   end
   local pname = player:get_player_name()
   local current_pmode = ct.player_modes[pname]
   if not mode then
      ct.player_modes[pname] = mode
   elseif current_pmode == nil or current_pmode ~= mode then
      ct.player_modes[pname] = mode
   else -- Toggle
      ct.player_modes[pname] = nil
   end
   minetest.chat_send_player(
      pname, "Citadella mode: " .. (ct.player_modes[pname] or "normal")
   )
   ct.update_hud(player)
end


minetest.register_chatcommand("ctb", {
   params = "",
   description = "Citadella BYPASS mode. "
      .."Bypass owned reinforcements, returning the reinforcement material "
      .."(operates independently from other modes).",
   func = function(name, param)
      if param ~= "" then
         minetest.chat_send_player(name, "Error: Usage: /ctb")
      else
         toggle_bypass_mode(name)
      end
   end
})


minetest.register_chatcommand("cto", {
   params = "",
   description = "Turn off any current Citadella modes.",
   func = function(name, param)
      if param ~= "" then
         minetest.chat_send_player(name, "Error: Usage: /cto")
      else
         ct.player_bypass[name] = nil
         set_simple_mode(name, nil) -- NORMAL
      end
   end
})


minetest.register_chatcommand("cti", {
   params = "",
   description = "Citadella information mode",
   func = function(name, param)
      if param ~= "" then
         minetest.chat_send_player(name, "Error: Usage: /cti")
      else
         set_simple_mode(name, ct.PLAYER_MODE_INFO)
      end
   end
})

-- XXX: documents say this isn't recommended, use node definition callbacks instead
minetest.register_on_placenode(function(pos, newnode, placer, oldnode, itemstack, pointed_thing)
      local pname = placer:get_player_name()
      -- If we're in /ctf mode
      if ct.player_modes[pname] == ct.PLAYER_MODE_FORTIFY then
         if not ct.position_in_citadella_border(pos) then
            minetest.chat_send_player(pname, "You can't fortify blocks here!")
            return
         elseif ct.blacklisted_node(newnode.name) then
            minetest.chat_send_player(pname, "This block cannot be fortified!")
            return
         end

         local current_reinf_group = ct.player_current_reinf_group[pname]
         local current_reinf_material = ct.player_fortify_material[pname]

         local required_item = ItemStack({
               name = current_reinf_material,
               count = 1
         });

         local inv = placer:get_inventory()

         local invlist = (inv:contains_item("main", required_item) and "main")
            or (inv:contains_item("main2", required_item) and "main2")

         -- Ensure player has the required item to create the reinforcement
         if invlist then
            local resource_limit = ct.resource_limits[current_reinf_material]

            ct.register_reinforcement(pos, current_reinf_group.id,
                                      current_reinf_material, resource_limit)

            local desc = core.registered_items[current_reinf_material].description

            minetest.chat_send_player(
               pname,
               "Reinforced placed block (" .. vtos(pos) .. ") with "
                  .. desc .. " (" .. tostring(resource_limit)
                  .. ") (group: '" .. current_reinf_group.name .. "')."
            )

            -- Edge case when fortifying stone with stone: remove_item doesn't
            -- work, for some reason...
            if current_reinf_material == newnode.name then
               itemstack:take_item()
            else
               inv:remove_item(invlist, required_item)
            end
         else
            minetest.chat_send_player(
               pname,
               "Inventory has no more " .. current_reinf_material .. "."
            )
            set_simple_mode(pname, nil)
         end
      end
end)


function ct.can_player_access_reinf(pname, reinf)
   if reinf then
      if not pname or pname == "" then
         return false, nil
      end

      -- Figure out if player is in the block's reinf group
      local player_id = pm.get_player_by_name(pname).id
      local player_groups = pm.get_groups_for_player(player_id)
      local reinf_ctgroup_id = reinf.ctgroup_id

      for _, group in ipairs(player_groups) do
         if reinf_ctgroup_id == group.id then
            return true, group
         end
      end

      return false, nil
   end
   return true, nil
end


minetest.register_on_punchnode(function(pos, node, puncher, pointed_thing)
      local pname = puncher:get_player_name()
      -- If we're in /ctr mode
      if ct.player_modes[pname] == ct.PLAYER_MODE_REINFORCE then
         if not ct.position_in_citadella_border(pos) then
            minetest.chat_send_player(pname, "You can't reinforce blocks here!")
            return
         elseif ct.blacklisted_node(node.name) then
            minetest.chat_send_player(pname, "This block cannot be reinforced!")
            return
         end

         local current_reinf_group = ct.player_current_reinf_group[pname]
         local item = puncher:get_wielded_item()
         -- If we punch something with a reinforcement item
         local item_name = item:get_name()
         local item_desc = minetest.registered_items[item_name].description
         local resource_limit = ct.resource_limits[item_name]
         if resource_limit then
            local reinf = ct.get_reinforcement(pos)
            if not reinf then
               -- Remove item from player's wielded stack
               item:take_item()
               puncher:set_wielded_item(item)
               -- Set node's reinforcement value to the default for this material
               ct.register_reinforcement(
                  pos, current_reinf_group.id, item_name, resource_limit
               )
               minetest.chat_send_player(
                  pname,
                  "Reinforced block ("..vtos(pos)..") with " .. item_desc ..
                     " (" .. tostring(resource_limit) .. ") on group " ..
                     current_reinf_group.name .. "."
               )
            else
               local reinf_desc
                  = minetest.registered_items[reinf.material].description
               minetest.chat_send_player(
                  pname, "Block is already reinforced with " .. reinf_desc
                     .. " (" .. tostring(reinf.value) .. ")"
               )
            end
         end
      elseif ct.player_modes[pname] == ct.PLAYER_MODE_INFO then
         local reinf = ct.get_reinforcement(pos)
         if not reinf then
            return
         end
         local reinf_desc
            = minetest.registered_items[reinf.material].description

         local group_string = ""

         local can_access, group = ct.can_player_access_reinf(pname, reinf)
         if can_access then
            local group_name = group.name
            if group_name then
               group_string = " on group '" .. group_name .. "'"
            end
         end

         minetest.chat_send_player(
            pname,
            "Block (" .. vtos(pos) .. ") is reinforced" .. group_string
               .. " with " .. reinf_desc
               .. " (" .. tostring(reinf.value) .. "/"
               .. tostring(ct.resource_limits[reinf.material]) .. ")."
         )
      elseif ct.player_modes[pname] == ct.PLAYER_MODE_CHANGE then
         local reinf = ct.get_reinforcement(pos)
         local current_reinf_group = ct.player_current_reinf_group[pname]
         if not reinf then
            minetest.chat_send_player(
               pname, "Block at (" .. vtos(pos) .. ") "
                  .."has no reinforcement."
            )
            return
         end

         local can_access = ct.can_player_access_reinf(pname, reinf)
         if not can_access then
            minetest.chat_send_player(
               pname, "You do not have access to the reinforcement at "
                  .. "(" .. vtos(pos) .. ")."
            )
            return
         end

         if reinf.ctgroup_id == current_reinf_group.id then
            minetest.chat_send_player(
               pname, "Block at (" .. vtos(pos) .. ") "
                  .. "is already on group '" .. current_reinf_group.name .. "'."
            )
            return
         end

         ct.update_reinforcement_group(reinf, pos, current_reinf_group.id)

         minetest.chat_send_player(
            pname, "Changed group of block at (" .. vtos(pos) .. ") to '"
               .. current_reinf_group.name .. "'."
         )
      end
end)


-- Don't completely clobber other plugin's protections
local is_protected_fn = minetest.is_protected

-- BLOCK-BREAKING, /ctb
function minetest.is_protected(pos, pname, action)
   local reinf = ct.get_reinforcement(pos)
   if not reinf then
      return is_protected_fn(pos, pname, action)
   end

   if action ~= minetest.DIG_ACTION then
      local can_player_access = ct.can_player_access_reinf(pname, reinf)
      return (not can_player_access)
         or is_protected_fn(pos, pname, action)
   end

   -- Handle people with protection_bypass privilege
   local privs = minetest.get_player_privs(pname)
   if privs and privs.protection_bypass then
      local c = minetest.colorize
      minetest.chat_send_player(
         pname,
         c("#e00",
           "WARNING: you have privilege: protection_bypass. "
              .. "Block's reinforcement was bypassed!")
      )
      ct.modify_reinforcement(pos, 0)
      return is_protected_fn(pos, pname, action)
   end

   if ct.player_bypass[pname] then
      if ct.can_player_access_reinf(pname, reinf) then
         local refund_item_name = reinf.material
         local refund_item = ItemStack({
               name = refund_item_name,
               count = 1
         })
         -- set reinforcement value to zero
         ct.modify_reinforcement(pos, 0)

         local player = minetest.get_player_by_name(pname)
         local inv = player:get_inventory()
         if inv:room_for_item("main", refund_item) then
            inv:add_item("main", refund_item)
            minetest.chat_send_player(
               pname,
               refund_item_name .. " refunded from bypassed reinforcement."
            )
         elseif inv:room_for_item("main2", refund_item) then
            inv:add_item("main2", refund_item)
            minetest.chat_send_player(
               pname,
               refund_item_name .. " refunded from bypassed reinforcement."
            )
         else
            minetest.chat_send_player(
               pname,
               "Warning: no inventory space for refunded reinforcement "
                  .. "material" .. refund_item_name
            )
         end

         return is_protected_fn(pos, pname, action)
      else
         minetest.chat_send_player(pname, "You can't bypass this!")
         return true
      end
   else
      -- Decrement reinforcement
      local remaining = ct.modify_reinforcement(pos, reinf.value - 1)
      return remaining > 0 or is_protected_fn(pos, pname, action)
   end

end
