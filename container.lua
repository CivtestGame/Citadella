function ct.override_on_construct(def)
   def.on_construct = function(pos)
      local meta = minetest.get_meta(pos)
      meta:set_string("formspec", ct.make_closed_formspec())
      meta:set_string("owner", "")
      local inv = meta:get_inventory()
      inv:set_size("main", 8*4)
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
                         " tried to access a locked chest at "..
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

function ct.override_definition(olddef)
   local def = table.copy(olddef)
   ct.override_on_construct(def)
   ct.wrap_allow_metadata_inventory_move(def)
   ct.wrap_allow_metadata_inventory_put(def)
   ct.wrap_allow_metadata_inventory_take(def)
   ct.override_on_receive_fields(def)

   return def
end
