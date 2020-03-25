--[[

init.lua

Entrypoint to this plugin.

--]]

ct = {}
ctdb = {}

minetest.debug("Citadella initialised")

local modpath = minetest.get_modpath(minetest.get_current_modname())

local db = dofile(modpath .. "/db.lua")
dofile(modpath .. "/cache.lua")
dofile(modpath .. "/citadella.lua")
dofile(modpath .. "/hud.lua")
dofile(modpath .. "/container.lua")
dofile(modpath .. "/chest.lua")
dofile(modpath .. "/furnace.lua")

return ct
