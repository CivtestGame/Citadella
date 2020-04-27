--[[

init.lua

Entrypoint to this plugin.

--]]

ct = {}
ctdb = {}

minetest.debug("Citadella initialised")

local modpath = minetest.get_modpath(minetest.get_current_modname())

local ie = minetest.request_insecure_environment() or
   error("Citadella needs to be a trusted mod. "
            .."Add it to `secure.trusted_mods` in minetest.conf")

loadfile(modpath .. "/db.lua")(ie)
dofile(modpath .. "/cache.lua")
dofile(modpath .. "/reinforcements.lua")
dofile(modpath .. "/decay.lua")
dofile(modpath .. "/citadella.lua")
dofile(modpath .. "/hud.lua")
dofile(modpath .. "/container.lua")
dofile(modpath .. "/chest.lua")
dofile(modpath .. "/furnace.lua")
dofile(modpath .. "/crafting.lua")

return ct
