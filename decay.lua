
local function compute_decay(time, timestamp, interval)
   local diff = time - timestamp
   local count = math.floor(diff / interval)
   return count
end

function ct.try_catchup_reinforcement(pos, reinf)
   if not reinf then
      return
   end

   local creation_date = math.max(
      reinf.last_stacked or 0, reinf.creation_date
   )

   local last_update = reinf.last_update
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

   local warmup_time = reinf_def.warmup_time
   local decay_after_time = reinf_def.decay_after_time

   local reinf_value = reinf.value

   if warmup_time == 0 then
      -- No warmup time specified, instantly warm-up the reinforcement.
      reinf.last_update = time
      ct.modify_reinforcement(pos, reinf_def.value)

   elseif elapsed_from_creation > decay_after_time
      and reinf_value > reinf_def.decay_to_value
   then
      -- Handle reinf decay. Nothing special here: compute decay since
      -- last_update, apply it, and update the last_update timestamp.
      local decay = compute_decay(
         time, last_update, reinf_def.decay_time_interval
      )
      if decay > 0 then
         reinf.last_update = time
         ct.modify_reinforcement(
            pos, math.max(reinf_value - decay, reinf_def.decay_to_value)
         )
      end

   elseif elapsed_from_creation < warmup_time
      and reinf_value < reinf_def.value then
         -- Here the reinf is warming up, or has warmed up. We calculate the
         -- warmup interval based on warmup time (which is always non-zero here).
         local warmup_val = compute_decay(
            time, last_update, warmup_time / reinf_def.value
         )

         if warmup_val > 0 then
            reinf.last_update = time
            ct.modify_reinforcement(
               pos, math.min(reinf_value + warmup_val, reinf_def.value)
            )
         end
   end
end

function ct.get_current_reinforcement_warmup(pos, reinf)
   local time = os.time(os.date("!*t"))
   local creation_time = math.max(reinf.creation_date, reinf.last_stacked or 0)
   local elapsed_from_creation = time - creation_time
   return elapsed_from_creation
end

function ct.is_reinforcement_warming_up(pos, reinf)
   local elapsed_from_creation = ct.get_current_reinforcement_warmup(pos, reinf)
   local reinf_def = ct.reinforcement_types[reinf.material]
   return elapsed_from_creation < reinf_def.warmup_time
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
   -- Duplicated from civtest_game/mods/farming/api.lua
   local divisor = 1
   local unit = "seconds"
   local over_three_months = false
   if time > (60 * 60 * 24 * 7 * 4 * 3) then
      over_three_months = true
      divisor = (60 * 60 * 24 * 7 * 4)
      unit =  "months"
   elseif time > (60 * 60 * 24 * 7) then
      divisor = (60 * 60 * 24 * 7)
      unit = "weeks"
   elseif time > (60 * 60 * 24) then
      divisor = (60 * 60 * 24)
      unit = "days"
   elseif time > (60 * 60) then
      divisor = (60 * 60)
      unit = "hours"
   elseif time > 60 then
      divisor = 60
      unit = "minutes"
   end
   return divisor, unit, over_three_months
end

local function pretty_timescale(time)
   local divisor, unit, over_three_months = growth_timescale(time)
   if over_three_months then
      return over_three_months
   else
      return math.floor(time / divisor) .. " " .. unit
   end
end

function ct.warmup_and_decay_info(material, reinf, pos)
   local reinf_def = ct.reinforcement_types[material]

   local info = {}

   if reinf_def.warmup_time ~= 0 then
      if reinf then
         local elapsed = ct.get_current_reinforcement_warmup(pos, reinf)
         local elapsed_pct
            = math.floor(math.min(1, elapsed / reinf_def.warmup_time) * 100)

         info[#info + 1] = "It has a warm-up time of "
            .. pretty_timescale(reinf_def.warmup_time)
            .. " (" .. tostring(elapsed_pct) .. "% warmed-up)."
      else
         info[#info + 1] = "It has a warm-up time of "
            .. pretty_timescale(reinf_def.warmup_time) .. "."
      end
   end

   if reinf_def.value_limit > reinf_def.value then
      info[#info + 1] = "It can stack "
         .. math.floor(reinf_def.value_limit / reinf_def.value) .. " times "
         .. "up to a total of " .. reinf_def.value_limit .. "."
   end

   if reinf_def.decay_after_time ~= 999999999999
      and reinf_def.decay_time_interval ~= 999999999999
   then
      if reinf then
         local elapsed = ct.get_current_reinforcement_warmup(pos, reinf)

         if elapsed > reinf_def.decay_after_time then
            info[#info + 1] = "It has started decaying after "
               .. pretty_timescale(reinf_def.decay_after_time)
               .. ". It decays every "
               .. pretty_timescale(reinf_def.decay_time_interval)
               .. " down to a value of " .. reinf_def.decay_to_value .. "."
         else
            local elapsed_pct = math.floor(
               math.min(1, elapsed / reinf_def.decay_after_time) * 100
            )

            info[#info + 1] = "It will decay after "
               .. pretty_timescale(reinf_def.decay_after_time) .. " "
               .. "every " .. pretty_timescale(reinf_def.decay_time_interval)
               .. " to a value of " .. reinf_def.decay_to_value .. "\n"
               .. "It is " .. elapsed_pct .. "% of the way to starting to decay."
         end
      else
         info[#info + 1] = "It will decay after "
            .. pretty_timescale(reinf_def.decay_after_time) .. " "
            .. "every " .. pretty_timescale(reinf_def.decay_time_interval) .. " "
            .. "to a value of " .. reinf_def.decay_to_value .. "."
      end
   end

   return (next(info) and table.concat(info, "\n")) or ""
end
