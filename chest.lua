
minetest.register_craft({
      type = "fuel",
      recipe = "citadella:chest",
      burntime = 30,
})


minetest.register_craft({
      output = "citadella:chest",
      recipe = {
         {'group:wood', 'group:wood', 'group:wood'},
         {'group:wood', ''          , 'group:wood'},
         {'group:wood', 'group:wood', 'group:wood'},
      }
})


minetest.register_node(
   "citadella:chest",
   {
      description = "Chest",
      tiles ={"default_chest.png^[sheet:2x2:0,0", "default_chest.png^[sheet:2x2:0,0",
              "default_chest.png^[sheet:2x2:1,0", "default_chest.png^[sheet:2x2:1,0",
              "default_chest.png^[sheet:2x2:1,0", "default_chest.png^[sheet:2x2:1,1"},
      paramtype2 = "facedir",
      groups = {snappy=2,choppy=2,oddly_breakable_by_hand=2},
      legacy_facedir_simple = true,
      is_ground_content = false,
      sounds = default.node_sound_wood_defaults(),
})
