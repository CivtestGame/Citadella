
function ct.make_open_formspec(reinf, group, name, pos)
   local F = minetest.formspec_escape
   local chest_title = name or "Chest"
   if reinf then
      local resource_limit = ct.reinforcement_types[reinf.material].value
      chest_title = "Locked " .. chest_title .. " (group: '" .. F(group.name) .. "', "
         .. tostring(reinf.material) .. ", " .. tostring(reinf.value) .. "/"
         .. tostring(resource_limit) .. ")"
   end

   local spos = pos.x .. "," .. pos.y .. "," .. pos.z

   local open = {
      "size[8,9.5]",
      "label[0,0;", chest_title, "]",
      -- default.gui_bg ,
      -- default.gui_bg_img ,
      -- default.gui_slots ,
      "list[nodemeta:"..spos..";main;0,0.7;8,4;]",
      -- invisible tmp invlist to facilitate shift-clicking to player inv
      "list[nodemeta:"..spos..";tmp;0,0;0,0;]",
      "listring[]",
      sfinv.get_inventory_area_formspec(5.2),
      "listring[nodemeta:"..spos..";main]",
      "listring[current_player;main2]",
      "listring[nodemeta:"..spos..";main]",
      "listring[current_player;main]",
      -- default.get_hotbar_bg(0,4.85)
   }
   return table.concat(open, "")
end

function ct.override_on_construct(def)
   def.on_construct = function(pos)
      local meta = minetest.get_meta(pos)
      meta:set_string("owner", "")
      local inv = meta:get_inventory()
      inv:set_size("main", 8*4)
      inv:set_size("tmp", 1)
   end
   return def
end

function ct.wrap_allow_metadata_inventory_move(def)
   local old_allow_metadata_inventory_move = def.allow_metadata_inventory_move
      or function(pos, from_list, from_index, to_list, to_index, count, player)
            return count
         end

   def.allow_metadata_inventory_move = function(pos, from_list, from_index, to_list, to_index, count, player)
      local meta = minetest.get_meta(pos)
      if from_list == "main" and to_list == "tmp" then
         local inv = minetest.get_meta(pos):get_inventory()
         local stack = inv:get_stack("main", from_index)
         local stack_count = stack:take_item(count)

         local pinv = player:get_inventory()
         if not pinv:room_for_item("main", stack_count)
            and not pinv:room_for_item("main2", stack_count)
         then
            return 0
         end
      end

      if not ct.has_locked_chest_privilege(pos, player) then
         minetest.log("action", player:get_player_name()..
                         " tried to move in a locked chest at "..
                         minetest.pos_to_string(pos))
         return 0
      end
      return old_allow_metadata_inventory_move(
         pos, from_list, from_index, to_list, to_index, count, player
      )
   end
   return def
end

function ct.wrap_allow_metadata_inventory_put(def)
   local old_allow_metadata_inventory_put = def.allow_metadata_inventory_put
      or function(pos, listname, index, stack, player)
            return stack:get_count()
         end

   def.allow_metadata_inventory_put = function(pos, listname, index, stack, player)
      local meta = minetest.get_meta(pos)
      if not ct.has_locked_chest_privilege(pos, player) then
         minetest.log("action", player:get_player_name()..
                         " tried to put into a locked chest at "..
                         minetest.pos_to_string(pos))
         return 0
      end
      return old_allow_metadata_inventory_put(pos, listname, index, stack, player)
   end
   return def
end

function ct.wrap_allow_metadata_inventory_take(def)
   local old_allow_metadata_inventory_take = def.allow_metadata_inventory_take
      or function(pos, listname, index, stack, player)
            return stack:get_count()
         end

   def.allow_metadata_inventory_take = function(pos, listname, index, stack, player)
      local meta = minetest.get_meta(pos)
      if not ct.has_locked_chest_privilege(pos, player) then
         minetest.log("action", player:get_player_name()..
                         " tried to take from a locked chest at "..
                         minetest.pos_to_string(pos))
         return 0
      end
      return old_allow_metadata_inventory_take(pos, listname, index, stack, player)
   end
   return def
end

function ct.override_on_metadata_inventory_move(def)
   local old_on_metadata_inventory_move = def.on_metadata_inventory_move
   def.on_metadata_inventory_move =
      function(pos, from_list, from_index, to_list, to_index, count, player)
         if from_list == "main" and to_list == "tmp" then
            local inv = minetest.get_meta(pos):get_inventory()
            local stack = inv:get_stack("tmp", to_index)
            local stack_count = stack:take_item(count)

            local leftover = player_api.give_item(player, stack_count, true)
            local leftover_count = (leftover and leftover:get_count()) or 0

            local from = inv:get_stack("main", from_index, stack)
            local from_count = from:get_count()

            from:set_count(math.max(0, from_count + leftover_count))

            inv:set_stack("main", from_index, from)

            -- XXX: I feel bad about this, just in case there are bugs that
            -- cause "tmp" to remain non-empty (and valid items get nuked).
            --
            -- But, for now, I think I would prefer to receive complaints than
            -- spew the items out into the world. That way, the players report
            -- the bugs, instead of getting used to 'weird' behaviour.
            inv:set_list("tmp", {})
         end
         minetest.log("verbose",
            player:get_player_name() .. " moves stuff in locked chest at "
               .. minetest.pos_to_string(pos)
         )
         if old_on_metadata_inventory_move then
            return old_on_metadata_inventory_move(
               pos, from_list, from_index, to_list, to_index, count, player
            )
         end
      end
end

function ct.override_on_metadata_inventory_take_put(def)
   local old_on_metadata_inventory_put = def.on_metadata_inventory_put
   def.on_metadata_inventory_put = function(pos, listname, index, stack, player)
      minetest.log("verbose",
         player:get_player_name() .. " puts stuff in locked chest at "
            .. minetest.pos_to_string(pos)
      )
      if old_on_metadata_inventory_put then
         old_on_metadata_inventory_put(pos, listname, index, stack, player)
      end
   end

   local old_on_metadata_inventory_take = def.on_metadata_inventory_take
   def.on_metadata_inventory_take = function(pos, listname, index, stack, player)
      minetest.log("verbose",
         player:get_player_name() .. " takes stuff from locked chest at "
            .. minetest.pos_to_string(pos)
      )
      if old_on_metadata_inventory_take then
         old_on_metadata_inventory_take(pos, listname, index, stack, player)
      end
   end
end

function ct.override_on_rightclick(def)
   local old_on_rightclick = def.on_rightclick
   def.on_rightclick = function(pos, node, clicker, itemstack, pointed_thing)
      local node_description = core.registered_nodes[node.name].description
      local has_privilege, reinf, group
         = ct.has_locked_chest_privilege(pos, clicker, node_description)
      if not has_privilege then
         return
      end

      local pname = clicker:get_player_name()
      local formspec = ct.make_open_formspec(reinf, group, node_description, pos)
      minetest.show_formspec(pname, "citadella:chest", formspec)

      if old_on_rightclick then
         old_on_rightclick(pos, node, clicker, itemstack, pointed_thing)
      end
   end
   return def
end

function ct.override_definition(olddef)
   local def = table.copy(olddef)
   ct.override_on_construct(def)
   ct.wrap_allow_metadata_inventory_move(def)
   ct.wrap_allow_metadata_inventory_put(def)
   ct.wrap_allow_metadata_inventory_take(def)
   ct.override_on_metadata_inventory_move(def)
   ct.override_on_metadata_inventory_take_put(def)
   ct.override_on_rightclick(def)

   return def
end
