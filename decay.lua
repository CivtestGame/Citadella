
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

function ct.compute_break_value(pos, reinf)
   local break_value = 1

   local time = os.time(os.date("!*t"))
   local elapsed_from_creation = time - reinf.creation_date
   local reinf_def = ct.reinforcement_types[reinf.material]

   if elapsed_from_creation < reinf_def.warmup_time then
      -- Breaking blocks during their warmup should be really punishing. 5x as
      -- much damage seems good enough to me.
      break_value = 5
   end

   return break_value
end
