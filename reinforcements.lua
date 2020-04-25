
ct.reinforcement_types = {}

function ct.register_reinforcement_type(def)
   --
   -- NOTE: we purposely don't use nils in the 'corrected' def to remove the
   -- burden of nil-checking from the decay/stacking/new-value calculations.
   -- This is mostly for code clarity reasons.
   --

   -- Reinforcement must at least have an item_name as a resource.
   def.item_name = def.item_name
      or error("ct.register_reinforcement_type: definition has no 'item_name'.")

   -- The item returned by /ctb. Default to the same item used to reinforce.
   def.return_item = def.return_item or def.item_name

   -- Grab a description of the reinforcement from somewhere.
   def.name = def.name
      or minetest.registered_items[def.item_name].description
      or def.item_name

   -- Reinf must also always have a value.
   def.value = def.value
      or error("ct.register_reinforcement_type: definition for "
                  .. def.item_name .." has no 'value' property.")

   -- Reinf warmup defaults to zero
   def.warmup_time = def.warmup_time or 0

   -- Used in stacking reinfs: if value_limit is higher than value, the reinf
   -- can be stacked up to value_limit.
   def.value_limit = def.value_limit or def.value

   -- Decay is stopped if it would drop below this point. decay = 0 means that
   -- the reinforcement will eventually disappear. Default to having no decay by
   -- specifying decay = value.
   def.decay_to_value = def.decay_to_value or def.value

   -- Decay after X seconds, every Y seconds. Default both to a long time away.
   def.decay_after_time = def.decay_after_time or 999999999999
   def.decay_length = def.decay_length or 999999999999

   ct.reinforcement_types[def.item_name] = def
end

--------------------------------------------------------------------------------
--
-- CONFIG
--
--------------------------------------------------------------------------------

local function seconds(n) return n end
local function minutes(n) return 60 * n end
local function hours(n) return 60 * 60 * n end
local function days(n) return 60 * 60 * 24 * n end

ct.register_reinforcement_type({
      item_name = "default:stone",
      value = 25,
})
ct.register_reinforcement_type({
      item_name = "default:copper_ingot",
      value = 250,
})
ct.register_reinforcement_type({
      item_name = "default:tin_ingot",
      value = 250,
})
ct.register_reinforcement_type({
      item_name = "default:steel_ingot",
      value = 1800,
})

-- Example
-- ct.register_reinforcement_type({
--       name = "Stackable Reinforcement",
--       item_name = "citadella:reinforcement_stackable",
--       return_item = "citadella:reinforcement_stackable",

--       -- Reinf adds 250 digs until the block is removed
--       value = 250,
--       -- Reinf decays to a value of 750
--       decay_to_value = 750,
--       -- Reinf can be stacked all the way to 2500
--       value_limit = 2500,

--       -- Reinf only becomes useful after 24h
--       warmup_time = hours(24),

--       -- Reinf begins decaying after 30 days in 3h intervals
--       decay_after_time = days(30),
--       decay_time_interval = hours(3),
-- })

-- Example
-- ct.register_reinforcement_type({
--       name = "Meme Reinforcement",
--       item_name = "default:cobble",
--       value = 10,

--       -- warmup_time = minutes(2),

--       decay_to_value = 0,
--       decay_after_time = minutes(2),
--       decay_time_interval = seconds(30)
-- })
