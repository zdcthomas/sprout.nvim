-- sprout.nvim: ascii art that grows with the hour of the day.
local Sprout = {}

-- Strip the trailing newline that a `[[ ... ]]` block ending on its own
-- line leaves behind, so a stage renders without a blank last line.
local normalize = function(def)
	local stages = {}
	for i, stage in ipairs(def.stages) do
		stages[i] = (stage:gsub("\n$", ""))
	end
	return { stages = stages }
end

-- Registry of art sets. A set is a table with a `stages` list of
-- multiline strings, ordered youngest to oldest. Any stage count works;
-- the 24 hours are split evenly across the stages.
Sprout.sets = {
	bonsai = normalize(require("sprout.sets.bonsai")),
	bonsai_boxed = normalize(require("sprout.sets.bonsai_boxed")),
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
	for i, stage in ipairs(def.stages) do
		assert(type(stage) == "string", ("sprout: stage %d of set %q is not a string"):format(i, name))
	end
	Sprout.sets[name] = normalize(def)
end

-- opts.set: the set name that pick() uses by default. The name resolves
-- at pick() time, so setup() may run before register().
Sprout.setup = function(opts)
	opts = opts or {}
	if opts.set ~= nil then
		config.set = opts.set
	end
end

-- Warn once per unknown set name, so a dashboard that calls pick() on
-- every redraw does not flood the message area.
local warned = {}
local warn_unknown = function(name)
	if warned[name] then
		return
	end
	warned[name] = true
	vim.notify(("sprout: unknown art set %q"):format(tostring(name)), vim.log.levels.WARN)
end

local resolve_set = function(set)
	if type(set) == "table" then
		return set
	end
	local found = Sprout.sets[set]
	if not found then
		warn_unknown(set)
	end
	return found
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
	local hour = fractional_hour()
	if opts.hour ~= nil then
		hour = tonumber(opts.hour)
		if hour == nil then
			return opts.default
		end
	end
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
