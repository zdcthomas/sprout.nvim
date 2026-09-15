-- sprout.nvim: ascii art that grows with the hour of the day.
local Sprout = {}

-- Registry of art sets. A set is a table with a `stages` list of
-- multiline strings, ordered youngest to oldest. Any stage count works;
-- the 24 hours are split evenly across the stages.
Sprout.sets = {
	bonsai = require("sprout.sets.bonsai"),
	bonsai_boxed = require("sprout.sets.bonsai_boxed"),
}

local config = {
	set = "bonsai",
}

-- Register a custom art set under a name, so pick() can use it.
-- def: { stages = { "...", "..." } }, ordered youngest to oldest.
Sprout.register = function(name, def)
	assert(type(name) == "string" and name ~= "", "sprout: a set name must be a non-empty string")
	assert(
		type(def) == "table" and type(def.stages) == "table" and #def.stages > 0,
		"sprout: a set needs a non-empty `stages` list"
	)
	Sprout.sets[name] = def
end

-- opts.set: the set name that pick() uses by default. The name resolves
-- at pick() time, so setup() may run before register().
Sprout.setup = function(opts)
	opts = opts or {}
	if opts.set ~= nil then
		config.set = opts.set
	end
end

local resolve_set = function(set)
	if type(set) == "table" then
		return set
	end
	return Sprout.sets[set]
end

-- The time of day as a fractional hour, e.g. 13.5 for 13:30. Minutes and
-- seconds count, so a set with more than 24 stages still subdivides the
-- day evenly.
local fractional_hour = function()
	local t = os.date("*t")
	return t.hour + t.min / 60 + t.sec / 3600
end

-- Pick the art stage that matches the time of day.
-- opts.hour: the hour, whole or fractional (0 <= hour < 24). The default
--   is the current time.
-- opts.set: a set name, or a set table passed directly. The default is
--   the setup() set ("bonsai" out of the box).
-- opts.boxed: shorthand for set = "bonsai_boxed" (kept for old configs).
-- opts.default: the fallback ascii for a bad hour value or unknown set.
Sprout.pick = function(opts)
	opts = opts or {}
	local hour = tonumber(opts.hour) or fractional_hour()
	local set = resolve_set(opts.set or (opts.boxed and "bonsai_boxed") or config.set)
	local stages = set and set.stages
	if not stages or #stages == 0 then
		return opts.default
	end

	-- Each stage covers an even slice of the day: 24 / #stages hours.
	local index = math.floor(hour / 24 * #stages)
	return stages[index + 1] or opts.default
end

return Sprout
