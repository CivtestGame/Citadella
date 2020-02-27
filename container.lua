
function ct.make_open_formspec(reinf, group, name)
   local chest_title = name or "Chest"
   if reinf then
      chest_title = "Locked " .. chest_title .. " (group: '" .. group.name .. "', "
         .. tostring(reinf.material) .. ", " .. tostring(reinf.value) .. "/"
         .. tostring(ct.resource_limits[reinf.material]) .. ")"
   end

   local open = {
      "size[8,10]",
      "label[0,0;", chest_title, "]",
      -- default.gui_bg ,
      -- default.gui_bg_img ,
      -- default.gui_slots ,
      "list[current_name;main;0,0.7;8,4;]",
      -- invisible tmp invlist to facilitate shift-clicking to player inv
      "list[current_name;tmp;0,0;0,0;]",
      "listring[]",
      sfinv.get_inventory_area_formspec(5.2),
      "listring[current_name;main]",
      "listring[current_player;main2]",
      "listring[current_name;main]",
      "listring[current_player;main]",
      "button[3,9.35;2,1;open;Close]" -- ,
      -- default.get_hotbar_bg(0,4.85)
   }
   return table.concat(open, "")
end

function ct.make_closed_formspec()
   local closed = "size[2,0.75]"..
      "button[0,0.0;2,1;open;Open]"
   return closed
end

function ct.override_on_construct(def)
   def.on_construct = function(pos)
      local meta = minetest.get_meta(pos)
      meta:set_string("formspec", ct.make_closed_formspec())
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

function ct.override_on_receive_fields(def)
   def.on_receive_fields = function(pos, formname, fields, sender)
      local meta = minetest.get_meta(pos)
      local can_open, reinf, group = ct.has_locked_chest_privilege(pos, sender)
      if can_open then
         if fields.open == "Open" then
            local name = core.registered_nodes[minetest.get_node(pos).name].description
            meta:set_string("formspec", ct.make_open_formspec(reinf, group, name))
         else
            meta:set_string("formspec", ct.make_closed_formspec())
         end
      end
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
            local leftover = player_api.give_item(player, stack)
            inv:set_stack("main", from_index, leftover)
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

function ct.override_definition(olddef)
   local def = table.copy(olddef)
   ct.override_on_construct(def)
   ct.wrap_allow_metadata_inventory_move(def)
   ct.wrap_allow_metadata_inventory_put(def)
   ct.wrap_allow_metadata_inventory_take(def)
   ct.override_on_receive_fields(def)
   ct.override_on_metadata_inventory_move(def)
   ct.override_on_metadata_inventory_take_put(def)

   return def
end
