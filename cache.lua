
-- Implementation of a reinforcement cache

local chunk_size = 16

local function coord_chunk(n)
   return math.floor(n / chunk_size) * chunk_size
end

local function get_pos_chunk(pos)
   return vector.new(
      coord_chunk(pos.x),
      coord_chunk(pos.y),
      coord_chunk(pos.z)
   )
end

--[[
cache:
  chunk coords --> block coords --> reinforcement
]]--

local chunk_reinf_cache = {}
local cache_chunk_expiry = 30 -- debug, can be set to 60+

function ct.flush_reinf(reinf)
   local reinf_value = reinf.value
   local x, y, z = reinf.x, reinf.y, reinf.z
   if reinf.new then
      -- minetest.chat_send_all("  Registered: (" .. ptos(x, y, z) .. ")")
      ctdb.remove_reinforcement(vector.new(x, y, z))
      -- TODO: cleanup this remove-then-register hack
      ctdb.register_reinforcement(
         vector.new(x, y, z),
         reinf.ctgroup_id,
         reinf.material,
         reinf.last_update,
         reinf.creation_date,
         reinf.last_stacked
      )
      reinf.new = false
   end
   if reinf_value < 1 then
      -- minetest.chat_send_all("  Removed: (" .. ptos(x, y, z) .. ")")
      ctdb.remove_reinforcement(vector.new(x, y, z))
   else
      -- minetest.chat_send_all("  Updated: (" .. ptos(x, y, z) .. ")")
      ctdb.update_reinforcement(
         vector.new(x, y, z),
         reinf_value,
         reinf.last_update,
         reinf.creation_date,
         reinf.last_stacked
      )
   end
end


function ct.try_flush_cache()
   local current_time = os.time(os.date("!*t"))
   ctdb.begin_transaction()
   for key, chunk in pairs(chunk_reinf_cache) do
      if (chunk.time_added + cache_chunk_expiry) < current_time then
         minetest.log("verbose", "Flushing chunk (" .. key .. ") to db.")
         for _, reinf in pairs(chunk.reinforcements) do
            ct.flush_reinf(reinf)
         end
         chunk_reinf_cache[key] = nil
      end
   end
   ctdb.end_transaction()
end


function ct.force_flush_cache()
   ctdb.begin_transaction()
   for key, chunk in pairs(chunk_reinf_cache) do
      minetest.log("verbose", "Force flushing chunk (" .. key .. ") to db.")
      for _, reinf in pairs(chunk.reinforcements) do
         ct.flush_reinf(reinf)
      end
      chunk_reinf_cache[key] = nil
   end
   ctdb.end_transaction()
end


function ct.chunk_ensure_cached(pos)
   local vchunk_start = get_pos_chunk(pos)
   local vchunk_end = vector.add(vchunk_start, chunk_size)

   local chunk_reinf = chunk_reinf_cache[vtos(vchunk_start)]
   if not chunk_reinf then
      ctdb.get_reinforcements_for_cache(
         chunk_reinf_cache,
         vchunk_start,
         vchunk_end
      )
   end
end


function ct.get_reinforcement(pos)
   ct.try_flush_cache()
   ct.chunk_ensure_cached(pos)
   local vchunk_start = get_pos_chunk(pos)
   local chunk_reinf = chunk_reinf_cache[vtos(vchunk_start)]
   local reinf = chunk_reinf.reinforcements[vtos(pos)]
   -- Apply warmup/decay to this reinforcement
   ct.try_catchup_reinforcement(pos, reinf)
   return reinf
end


function ct.modify_reinforcement(pos, value)
   ct.try_flush_cache()
   ct.chunk_ensure_cached(pos)
   local vchunk_start = get_pos_chunk(pos)
   local chunk_reinf = chunk_reinf_cache[vtos(vchunk_start)]
   if value == 0 then
      -- We have to force a flush to get the DB in sync with the removal of the
      -- node's entry in the cache.
      --
      -- If this isn't done, Citadella would reload the value from the DB, which
      -- is almost certainly not coherent with the current state of the cache.
      if chunk_reinf.reinforcements[vtos(pos)] then
         chunk_reinf.reinforcements[vtos(pos)].value = 0
         ct.flush_reinf(chunk_reinf.reinforcements[vtos(pos)])
      end

      -- Once the cache has been flushed, this reinforcement entry is removed.
      chunk_reinf.reinforcements[vtos(pos)] = nil
   else
      chunk_reinf.reinforcements[vtos(pos)].value = value
   end
   return value
end


function ct.register_reinforcement(pos, ctgroup_id, item_name, resource_limit)
   local reinf = ct.get_reinforcement(pos)
   if not reinf then
      local time = os.time(os.date("!*t"))
      local vchunk = get_pos_chunk(pos)
      chunk_reinf_cache[vtos(vchunk)].reinforcements[vtos(pos)] = {
         x = pos.x, y = pos.y, z = pos.z,
         value = 1,
         material = item_name,
         ctgroup_id = ctgroup_id,
         last_update = time,
         creation_date = time,
         last_stacked = time,
         new = true
      }
   end
end

function ct.update_reinforcement_group(reinf, pos, ctgroup_id)
   ctdb.update_reinforcement_group(
      pos, reinf.ctgroup_id, ctgroup_id
   )

   local vchunk = get_pos_chunk(pos)
   local cached_reinf = chunk_reinf_cache[vtos(vchunk)].reinforcements[vtos(pos)]
   if cached_reinf then
      cached_reinf.ctgroup_id = ctgroup_id
   end
end
