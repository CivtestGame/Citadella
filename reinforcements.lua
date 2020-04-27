
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

   -- Is this reinforcement disabled?
   def.disabled = def.disabled or false

   -- Grab a description of the reinforcement from somewhere.
   def.name = def.name
      or minetest.registered_items[def.item_name].description
      or def.item_name

   -- Reinf must also always have a value.
   def.value = def.value
      or error("ct.register_reinforcement_type: definition for "
                  .. def.item_name .." has no 'value' property.")

   -- Reinf warmup defaults to one
   def.warmup_time = def.warmup_time or 1

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

local function seconds(n) return               n end
local function minutes(n) return seconds(60) * n end
local function hours(n)   return minutes(60) * n end
local function days(n)    return hours(24)   * n end
local function weeks(n)   return days(7)     * n end

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

--       -- Reinf begins decaying after 30 days over a 3h period
--       decay_after_time = days(30),
--       decay_length = hours(3),
-- })

-- Example
-- ct.register_reinforcement_type({
--       name = "Meme Reinforcement",
--       item_name = "default:cobble",
--       disabled = true,

--       value = 50,

--       warmup_time = seconds(15),

--       decay_to_value = 0,
--       decay_after_time = seconds(30),

--       decay_length = minutes(2)
-- })


--------------------------------------------------------------------------------
--
-- Civtest Citadella reinforcements
--
--------------------------------------------------------------------------------

-- Legacy ones: transitioning to new system

ct.register_reinforcement_type({
      item_name = "default:copper_ingot",
      value = 250,
      -- disabled = true,

      decay_to_value = 25,
      decay_after_time = days(30),
      decay_length = days(30)
})

ct.register_reinforcement_type({
      item_name = "default:tin_ingot",
      value = 250,
      -- disabled = true,

      decay_to_value = 25,
      decay_after_time = days(30),
      decay_length = days(30)
})

ct.register_reinforcement_type({
      item_name = "default:steel_ingot",
      value = 1800,
      -- disabled = true,

      decay_to_value = 250,
      decay_after_time = days(60),
      decay_length = days(60)
})

--
-- New reinforcement system
--

-- Stone

ct.register_reinforcement_type({
      item_name = "default:stone",
      value = 25,
      warmup_time = hours(48),

      decay_to_value = 2,
      decay_after_time = days(180),
      decay_length = days(90)
})

-- Tin Plating

minetest.register_craftitem("citadella:reinf_plating_tin", {
	description = "Tin Plating",
	inventory_image = "citadella_plating_tin.png",
	groups = { reinforcement = 1 }
})

ct.register_reinforcement_type({
      name = "Tin Plating",
      item_name = "citadella:reinf_plating_tin",
      value = 250,

      warmup_time = hours(24),

      decay_to_value = 12,
      decay_after_time = weeks(4),
      decay_length = weeks(4)
})

-- Bronze Rebar

minetest.register_craftitem("citadella:reinf_rebar_bronze", {
	description = "Bronze Rebar",
	inventory_image = "citadella_rebar_bronze.png",
	groups = { reinforcement = 1 }
})

ct.register_reinforcement_type({
      name = "Bronze Rebar",
      item_name = "citadella:reinf_rebar_bronze",
      value = 150,
      value_limit = 300,

      warmup_time = hours(72),

      decay_to_value = 15,
      decay_after_time = days(180),
      decay_length = days(90)
})

-- Grout

minetest.register_craftitem("citadella:reinf_grout", {
	description = "Grout",
	inventory_image = "citadella_grout.png",
	groups = { reinforcement = 1 }
})

ct.register_reinforcement_type({
      name = "Grout",
      item_name = "citadella:reinf_grout",
      value = 50,

      warmup_time = weeks(3),
})

-- Wrought Iron Rebar

minetest.register_craftitem("citadella:reinf_rebar_wrought_iron", {
	description = "Wrought Iron Rebar",
	inventory_image = "citadella_rebar_wrought_iron.png",
	groups = { reinforcement = 1 }
})

ct.register_reinforcement_type({
      name = "Wrought Iron Rebar",
      item_name = "citadella:reinf_rebar_wrought_iron",
      value = 200,
      value_limit = 400,

      warmup_time = hours(72),

      decay_to_value = 20,
      decay_after_time = days(180),
      decay_length = days(90)
})

-- Fine Steel Rebar

minetest.register_craftitem("citadella:reinf_rebar_fine_steel", {
	description = "Fine Steel Rebar",
	inventory_image = "citadella_rebar_fine_steel.png",
	groups = { reinforcement = 1 }
})

ct.register_reinforcement_type({
      name = "Fine Steel Rebar",
      item_name = "citadella:reinf_rebar_fine_steel",
      value = 300,
      value_limit = 1200,

      warmup_time = hours(72),

      decay_to_value = 60,
      decay_after_time = days(180),
      decay_length = days(90)
})

-- Cement

minetest.register_craftitem("citadella:reinf_cement", {
	description = "Cement",
	inventory_image = "citadella_cement.png",
	groups = { reinforcement = 1 }
})

ct.register_reinforcement_type({
      name = "Cement",
      item_name = "citadella:reinf_cement",
      value = 75,

      warmup_time = weeks(3),
})

-- Brass Plating

minetest.register_craftitem("citadella:reinf_plating_brass", {
	description = "Brass Plating",
	inventory_image = "citadella_plating_brass.png",
	groups = { reinforcement = 1 }
})

ct.register_reinforcement_type({
      name = "Brass Plating",
      item_name = "citadella:reinf_plating_brass",
      value = 200,

      warmup_time = hours(4),

      decay_to_value = 10,
      decay_after_time = weeks(2),
      decay_after_time = weeks(1),
})

-- Stainless Steel Rebar

minetest.register_craftitem("citadella:reinf_rebar_stainless_steel", {
	description = "Stainless Steel Rebar",
        -- TODO: citadella_rebar_stainless_steel.png
	inventory_image = "citadella_rebar_fine_steel.png",
	groups = { reinforcement = 1 }
})

ct.register_reinforcement_type({
      name = "Stainless Steel Rebar",
      item_name = "citadella:reinf_rebar_stainless_steel",
      value = 500,
      value_limit = 2000,

      warmup_time = hours(72),

      decay_to_value = 100,
      decay_after_time = days(180),
      decay_length = days(90)
})

-- Aluminium Bronze Plating

minetest.register_craftitem("citadella:reinf_plating_alubronze", {
	description = "Aluminium Bronze Plating",
	inventory_image = "citadella_plating_alubronze.png",
	groups = { reinforcement = 1 }
})

ct.register_reinforcement_type({
      name = "Aluminium Bronze Plating",
      item_name = "citadella:reinf_plating_alubronze",
      value = 200,

      decay_to_value = 100,
      decay_after_time = weeks(1),
      decay_length = days(3)
})
