--[[

Database connection functionality via PostgreSQL.

`luarocks install luasql-postgres`

]]--

local ie = minetest.request_insecure_environment() or
   error("Citadella needs to be a trusted mod. "
            .."Add it to `secure.trusted_mods` in minetest.conf")

local driver_exists, driver = pcall(ie.require, "luasql.postgres")
if not driver_exists then
   error("[Citadella] Lua PostgreSQL driver not found. "
            .."Please install it (try 'luarocks install luasql-postgres').")
end

local db = nil
local env = nil

local sourcename = minetest.settings:get("citadella_db_sourcename")
local username = minetest.settings:get("citadella_db_username")
local password = minetest.settings:get("citadella_db_password")

local u = pmutils

local function prep_db()
   env = assert (driver.postgres())
   -- connect to data source
   db = assert (env:connect(sourcename, username, password))

   -- create reinforcements table
   local res = assert(u.prepare(db, [[
     CREATE TABLE IF NOT EXISTS reinforcement (
         x INTEGER NOT NULL,
         y INTEGER NOT NULL,
         z INTEGER NOT NULL,
         value INTEGER NOT NULL,
         material VARCHAR(50) NOT NULL,
         ctgroup_id VARCHAR(32) REFERENCES ctgroup(id),
         PRIMARY KEY (x, y, z)
     )]]))
end


prep_db()


minetest.register_on_shutdown(function()
   ct.force_flush_cache()
   db:close()
   env:close()
end)

local QUERY_REGISTER_REINFORCEMENT = [[
  INSERT INTO reinforcement (x, y, z, value, material, ctgroup_id)
  VALUES (?, ?, ?, ?, ?, ?)
]]

function ctdb.register_reinforcement(pos, ctgroup_id, item_name)
   local value = ct.resource_limits[item_name]
   assert(u.prepare(db, QUERY_REGISTER_REINFORCEMENT,
                    pos.x, pos.y, pos.z,
                    value, item_name, ctgroup_id))
end

local QUERY_UPDATE_REINFORCEMENT_GROUP = [[
  UPDATE reinforcement
  SET ctgroup_id = ?
  WHERE ctgroup_id = ?
    AND reinforcement.x = ?
    AND reinforcement.y = ?
    AND reinforcement.z = ?
]]

function ctdb.update_reinforcement_group(pos, old_ctgroup_id, new_ctgroup_id)
   assert(u.prepare(db, QUERY_UPDATE_REINFORCEMENT_GROUP,
                    new_ctgroup_id, old_ctgroup_id,
                    pos.x, pos.y, pos.z))
end


local QUERY_REMOVE_REINFORCEMENT = [[
  DELETE FROM reinforcement
  WHERE reinforcement.x = ?
    AND reinforcement.y = ?
    AND reinforcement.z = ?
]]

function ctdb.remove_reinforcement(pos)
   assert(u.prepare(db, QUERY_REMOVE_REINFORCEMENT,
                    pos.x, pos.y, pos.z))
end

local QUERY_GET_REINFORCEMENT = [[
  SELECT * FROM reinforcement
  WHERE reinforcement.x = ?
    AND reinforcement.y = ?
    AND reinforcement.z = ?
]]

function ctdb.get_reinforcement(pos)
   local cur = u.prepare(db, QUERY_GET_REINFORCEMENT,
                         pos.x, pos.y, pos.z)
   if cur then
      return cur:fetch({}, "a")
   else
      return nil
   end
end

local QUERY_GET_REINFORCEMENTS = [[
  SELECT * FROM reinforcement
  WHERE reinforcement.x BETWEEN ? AND ?
    AND reinforcement.y BETWEEN ? AND ?
    AND reinforcement.z BETWEEN ? AND ?
]]

function ctdb.get_reinforcements_for_cache(cache, pos1, pos2)
   local cur = u.prepare(db, QUERY_GET_REINFORCEMENTS,
                         pos1.x, pos2.x,
                         pos1.y, pos2.y,
                         pos1.z, pos2.z)
   local reinfs = {}
   local row = cur:fetch({}, "a")
   while row do
      local x, y, z = tonumber(row.x), tonumber(row.y), tonumber(row.z)
      reinfs[ptos(x, y, z)] = {
         x = x, y = y, z = z,
         value = tonumber(row.value),
         material = row.material,
         ctgroup_id = row.ctgroup_id,
         new = false
      }
      row = cur:fetch(row, "a")
   end
   cache[vtos(pos1)] = {
      reinforcements = reinfs,
      time_added = os.time(os.date("!*t"))
   }
end

local QUERY_UPDATE_REINFORCEMENT = [[
  UPDATE reinforcement
  SET value = ?
  WHERE reinforcement.x = ?
    AND reinforcement.y = ?
    AND reinforcement.z = ?
]]

function ctdb.update_reinforcement(pos, new_value)
   assert(u.prepare(db, QUERY_UPDATE_REINFORCEMENT, new_value,
                    pos.x, pos.y, pos.z))
end

return db
