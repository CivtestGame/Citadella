minetest.register_craft({
	output = 'citadella:reinf_grout 20',
	recipe = {
		{'default:gravel', 'default:gravel', 'default:gravel'},
		{'default:gravel', 'group:sand', 'group:sand'},
		{'group:sand', 'group:sand', 'default:clay'},
	}
})