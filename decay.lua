
local function compute_decay(time, timestamp, interval)
   local diff = time - timestamp
   local count = math.floor(diff / interval)
   return count
end

function ct.try_catchup_reinforcement(pos, reinf)
   if not reinf then
      return
   end

   local creation_date = reinf.creation_date
   local last_update = reinf.last_update
   local last_stacked = reinf.last_stacked or creation_date
   if not creation_date or not last_update then
      -- This node predates the decay system. Ignore it for now.
      return
   end

   local reinf_def = ct.reinforcement_types[reinf.material]
   if not reinf_def then
      minetest.log(
         "warning", "Reinforcement with invalid material at "
            .. minetest.pos_to_string(pos) .. "."
      )
      return
   end

   local time = os.time(os.date("!*t"))

   local elapsed_from_creation = time - creation_date
   local elapsed_from_last_update = time - last_update
   local elapsed_from_last_stacked = time - last_stacked

   local warmup_time = reinf_def.warmup_time
   local decay_after_time = reinf_def.decay_after_time

   local reinf_value = reinf.value

   if warmup_time == 1
      and elapsed_from_creation == elapsed_from_last_update
   then
      -- This is triggered at the first update of an instant-warmup reinf.
      -- No warmup time is specified, so instantly warm-up the reinforcement.
      ct.modify_reinforcement(pos, reinf_def.value, time)

   elseif elapsed_from_last_stacked > decay_after_time
      and reinf_value > reinf_def.decay_to_value
   then
      -- Handle reinf decay.
      local decay = compute_decay(
         -- last_updated counts from the warmup's completion (or last stack)
         -- meaning that it's severely out-of-date when we first compute decay.
         -- However, we can rely on it once decay has been triggered.
         time, math.max(last_stacked + decay_after_time, last_update),
            reinf_def.decay_length /
               (reinf_def.value_limit - reinf_def.decay_to_value)
      )

      if decay > 0 then
         ct.modify_reinforcement(
            pos, math.max(reinf_value - decay, reinf_def.decay_to_value), time
         )
      end

   elseif reinf_value < reinf_def.value then
      -- Here the reinf is warming up, or has warmed up. We calculate the
      -- warmup interval based on warmup time.

      local elapsed_before_update
         = elapsed_from_creation - elapsed_from_last_update

      if elapsed_before_update < warmup_time then
         local warmup_val = compute_decay(
            time, last_update, warmup_time / reinf_def.value
         )

         if warmup_val > 0 then
            ct.modify_reinforcement(
               pos, math.min(reinf_value + warmup_val, reinf_def.value), time
            )
         end
      end
   end
end

function ct.get_current_reinforcement_postdecay(pos, reinf)
   local time = os.time(os.date("!*t"))
   local reinf_def = ct.reinforcement_types[reinf.material]
   local decay_after_time = reinf_def.decay_after_time
   local creation_date = reinf.creation_date
   local last_stacked = reinf.last_stacked or creation_date

   if not creation_date then
      return nil
   end

   local decay_time = last_stacked + decay_after_time

   local elapsed_since_decay = time - decay_time

   return elapsed_since_decay
end

function ct.get_current_reinforcement_predecay(pos, reinf)
   local time = os.time(os.date("!*t"))
   local last_stacked = reinf.last_stacked
   if not last_stacked then
      return nil
   end

   local elapsed_from_last_stacked = time - last_stacked
   return elapsed_from_last_stacked
end

function ct.get_current_reinforcement_warmup(pos, reinf)
   local time = os.time(os.date("!*t"))
   local creation_time = reinf.creation_date
   if not creation_time then
      return nil
   end

   local elapsed_from_creation = time - creation_time
   return elapsed_from_creation
end

function ct.is_reinforcement_warming_up(pos, reinf)
   local elapsed_from_creation = ct.get_current_reinforcement_warmup(pos, reinf)
   local reinf_def = ct.reinforcement_types[reinf.material]

   return elapsed_from_creation
      and elapsed_from_creation < reinf_def.warmup_time
end

function ct.compute_break_value(pos, reinf)
   local break_value = 1
   if ct.is_reinforcement_warming_up(pos, reinf) then
      -- Breaking blocks during their warmup should be really punishing. 5x as
      -- much damage seems good enough to me.
      break_value = 5
   end

   return break_value
end

--------------------------------------------------------------------------------

local function growth_timescale(time)
   -- Somewhat duplicated from civtest_game/mods/farming/api.lua
   local divisor = 1
   local unit = "second"
   if time > (60 * 60 * 24 * 7 * 4) then
      divisor = (60 * 60 * 24 * 7 * 4)
      unit = "month"
   elseif time > (60 * 60 * 24 * 7) then
      divisor = (60 * 60 * 24 * 7)
      unit = "week"
   elseif time > (60 * 60 * 24) then
      divisor = (60 * 60 * 24)
      unit = "day"
   elseif time > (60 * 60) then
      divisor = (60 * 60)
      unit = "hour"
   elseif time > 60 then
      divisor = 60
      unit = "minute"
   end

   if divisor > 1 then
      unit = unit .. "s"
   end

   return divisor, unit
end

local function pretty_timescale(time)
   local divisor, unit = growth_timescale(time)
   return math.ceil(time / divisor) .. " " .. unit
end

---- Provides a descriptive message about reinforcement warm-up info.
-- @param reinf_def the reinforcement's definition
-- @param[opt] reinf an instance of a reinforcement
-- @param[opt] pos the position of the supplied 'reinf'
-- @return information string
function ct.warmup_desc(reinf_def, reinf, pos)
   if reinf_def.warmup_time > 1 then
      if reinf then
         local elapsed = ct.get_current_reinforcement_warmup(pos, reinf)
         local elapsed_pct = math.floor(
            math.min(1, elapsed / reinf_def.warmup_time) * 100
         )
         return "It has warm-up time of "
            .. pretty_timescale(reinf_def.warmup_time)
            .. " (" .. tostring(elapsed_pct) .. "% warmed-up)."
      else
         return "It has a warm-up time of "
            .. pretty_timescale(reinf_def.warmup_time) .. "."
      end
   end
   return "It warms up instantly."
end

function ct.warmup_and_decay_info(material, reinf, pos)
   local reinf_def = ct.reinforcement_types[material]

   local info = {}

   local warmup_desc = ct.warmup_desc(reinf_def, reinf, pos)
   info[#info + 1] = warmup_desc

   if reinf_def.value_limit > reinf_def.value then
      info[#info + 1] = "It can stack "
         .. math.floor(reinf_def.value_limit / reinf_def.value) .. " times "
         .. "up to a total of " .. reinf_def.value_limit .. "."
   end

   if reinf_def.decay_after_time ~= 999999999999
      and reinf_def.decay_length ~= 999999999999
   then
      local decay_time_interval
         = (reinf_def.value_limit - reinf_def.decay_to_value)
           / reinf_def.decay_length

      if reinf then
         local elapsed_pre = ct.get_current_reinforcement_predecay(pos, reinf)

         if elapsed_pre > reinf_def.decay_after_time then

            -- There's a minor bug here if /ctei is repeatedly used. It seems
            -- that the reported reinforcement drifts from this percentage. Not
            -- entirely sure why...
            local since = ct.get_current_reinforcement_postdecay(pos, reinf)
            local decay_pct = math.floor(
               math.min(1, since / reinf_def.decay_length) * 100
            )

            info[#info + 1] = "Decay began after "
               .. pretty_timescale(reinf_def.decay_after_time) .. ".\n"
               .. "It will decay over "
               .. pretty_timescale(reinf_def.decay_length) .. " "
               .. "down to a value of " .. reinf_def.decay_to_value .. ".\n"
               .. "It is " .. decay_pct .. "% decayed."
         else
            local elapsed_pct = math.floor(
               math.min(1, elapsed_pre / reinf_def.decay_after_time) * 100
            )

            info[#info + 1] = "It will decay after "
               .. pretty_timescale(reinf_def.decay_after_time) .. " "
               .. "over " .. pretty_timescale(reinf_def.decay_length) .. " "
               .. "to a value of " .. reinf_def.decay_to_value .. ".\n"
               .. "It is " .. elapsed_pct .. "% of the way to starting to decay."
         end
      else
         info[#info + 1] = "It will decay after "
            .. pretty_timescale(reinf_def.decay_after_time) .. " "
            .. "over " .. pretty_timescale(reinf_def.decay_length) .. " "
            .. "to a value of " .. reinf_def.decay_to_value .. "."
      end
   end

   return (next(info) and table.concat(info, "\n")) or ""
end
