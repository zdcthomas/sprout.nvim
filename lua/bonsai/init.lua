-- bonsai.nvim: ascii art that grows with the hour of the day.
local Bonsai = {}

-- Registry of art sets. A set is a table with a `stages` list of
-- multiline strings, ordered youngest to oldest. Any stage count works;
-- the 24 hours are split evenly across the stages.
Bonsai.sets = {
	bonsai = require("bonsai.sets.bonsai"),
	bonsai_boxed = require("bonsai.sets.bonsai_boxed"),
}

local config = {
	set = "bonsai",
}

-- Register a custom art set under a name, so pick() can use it.
-- def: { stages = { "...", "..." } }, ordered youngest to oldest.
Bonsai.register = function(name, def)
	assert(type(name) == "string" and name ~= "", "bonsai: a set name must be a non-empty string")
	assert(
		type(def) == "table" and type(def.stages) == "table" and #def.stages > 0,
		"bonsai: a set needs a non-empty `stages` list"
	)
	Bonsai.sets[name] = def
end

-- opts.set: the set name that pick() uses by default. The name resolves
-- at pick() time, so setup() may run before register().
Bonsai.setup = function(opts)
	opts = opts or {}
	if opts.set ~= nil then
		config.set = opts.set
	end
end

local resolve_set = function(set)
	if type(set) == "table" then
		return set
	end
	return Bonsai.sets[set]
end

-- Pick the art stage that matches an hour of the day (0-23).
-- opts.hour: the hour. The default is the current hour.
-- opts.set: a set name, or a set table passed directly. The default is
--   the setup() set ("bonsai" out of the box).
-- opts.boxed: shorthand for set = "bonsai_boxed" (kept for old configs).
-- opts.default: the fallback ascii for a bad hour value or unknown set.
Bonsai.pick = function(opts)
	opts = opts or {}
	local hour = tonumber(opts.hour) or tonumber(vim.fn.strftime("%H"))
	local set = resolve_set(opts.set or (opts.boxed and "bonsai_boxed") or config.set)
	local stages = set and set.stages
	if not stages or #stages == 0 then
		return opts.default
	end

	local interval = 24 / #stages
	local index = math.floor(hour / interval)
	return stages[index + 1] or opts.default
end

return Bonsai
