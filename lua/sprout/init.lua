-- sprout.nvim: ascii art that grows with the hour of the day.
local Sprout = {}

local uv = vim.uv or vim.loop

-- Registry of art sets. A set is a table with a `stages` list of stages,
-- ordered youngest to oldest. Any stage count works; the 24 hours are split
-- evenly across the stages.
--
-- A stage is either a multiline string, or a list of multiline strings that
-- form an animation loop. A set may instead generate its stages on demand,
-- with `count` and a `stage(index, count)` function.
Sprout.sets = {
	bonsai = require("sprout.sets.bonsai"),
	bonsai_boxed = require("sprout.sets.bonsai_boxed"),
	spiro = require("sprout.sets.spiro"),
}

local DEFAULT_FRAME_MS = 400

local config = {
	set = "bonsai",
	frame_ms = DEFAULT_FRAME_MS,
}

local is_generated = function(set)
	return type(set.stage) == "function"
end

-- A stage is a string, or a non-empty list of strings.
local valid_stage = function(stage)
	if type(stage) == "string" then
		return true
	end
	if type(stage) ~= "table" or #stage == 0 then
		return false
	end
	for _, frame in ipairs(stage) do
		if type(frame) ~= "string" then
			return false
		end
	end
	return true
end

local shape_of = function(art)
	local lines = vim.split(art, "\n", { plain = true })
	local width = 0
	for _, line in ipairs(lines) do
		width = math.max(width, #line)
	end
	return #lines, width
end

-- Every frame in one stage should share a line count and a width. A frame
-- that does not match makes the layout jump halfway through the loop, which
-- is hard to trace back to the art. Warn once and carry on.
local warn_ragged = function(name, stages)
	for i, stage in ipairs(stages) do
		if type(stage) == "table" then
			local rows, cols = shape_of(stage[1])
			for f = 2, #stage do
				local r, c = shape_of(stage[f])
				if r ~= rows or c ~= cols then
					vim.notify(
						string.format(
							"sprout: in set %q stage %d, frame %d is %dx%d but frame 1 is %dx%d. "
								.. "The layout will jump mid-loop.",
							name,
							i,
							f,
							r,
							c,
							rows,
							cols
						),
						vim.log.levels.WARN
					)
					return
				end
			end
		end
	end
end

-- Register a custom art set under a name, so pick() can use it.
-- def: { stages = { <stage>, ... } }, ordered youngest to oldest, where a
--   stage is a string or a list of frame strings.
-- def: { count = N, stage = function(index, count) end } for a set that
--   builds its stages on demand.
-- def.frame_ms: this set's animation speed. Optional.
Sprout.register = function(name, def)
	assert(type(name) == "string" and name ~= "", "sprout: a set name must be a non-empty string")
	assert(type(def) == "table", "sprout: a set must be a table")

	if is_generated(def) then
		assert(
			type(def.count) == "number" and def.count > 0,
			"sprout: a set with a `stage` function needs a positive `count`"
		)
	else
		assert(
			type(def.stages) == "table" and #def.stages > 0,
			"sprout: a set needs a non-empty `stages` list, or a `stage` function and a `count`"
		)
		for i, stage in ipairs(def.stages) do
			assert(
				valid_stage(stage),
				string.format("sprout: stage %d must be a string, or a non-empty list of strings", i)
			)
		end
		warn_ragged(name, def.stages)
	end

	Sprout.sets[name] = def
	return def
end

-- opts.set: the set name that pick() uses by default. The name resolves
-- at pick() time, so setup() may run before register().
-- opts.frame_ms: the default animation speed, for sets that do not set one.
Sprout.setup = function(opts)
	opts = opts or {}
	if opts.set ~= nil then
		config.set = opts.set
	end
	if opts.frame_ms ~= nil then
		config.frame_ms = opts.frame_ms
	end
end

local resolve_set = function(set)
	if type(set) == "table" then
		return set
	end
	return Sprout.sets[set]
end

local stage_count = function(set)
	if is_generated(set) then
		return set.count or 0
	end
	return set.stages and #set.stages or 0
end

-- Generated stages are kept after the first build. A set like `spiro` costs
-- a millisecond or two per stage, which is nothing on demand. Baking the
-- whole set into the repo instead was tried and rejected: see TODO.md.
-- Weak keys let a set table that goes out of scope drop its cache.
local memo = setmetatable({}, { __mode = "k" })

local stage_at = function(set, index)
	if not is_generated(set) then
		return set.stages[index + 1]
	end
	local cache = memo[set]
	if not cache then
		cache = {}
		memo[set] = cache
	end
	if cache[index] == nil then
		cache[index] = set.stage(index, set.count)
	end
	return cache[index]
end

-- The time of day as a fractional hour, e.g. 13.5 for 13:30. Minutes and
-- seconds count, so a set with more than 24 stages still subdivides the
-- day evenly.
local fractional_hour = function()
	local t = os.date("*t")
	return t.hour + t.min / 60 + t.sec / 3600
end

-- Wall clock milliseconds. os.time() resolves only to the second, which is
-- too coarse for a frame period under a second. This is wall clock rather
-- than monotonic time, so two Neovim instances agree on the frame.
local now_ms = function()
	local sec, usec = uv.gettimeofday()
	return sec * 1000 + math.floor(usec / 1000)
end

-- Speed resolves from the narrowest scope outwards: the call, then the set,
-- then setup(), then the built-in default.
local resolve_frame_ms = function(opts, set)
	local ms = tonumber(opts.frame_ms) or tonumber(set and set.frame_ms) or tonumber(config.frame_ms)
	if not ms or ms <= 0 then
		return DEFAULT_FRAME_MS
	end
	return ms
end

-- Pick the art stage that matches the time of day.
-- opts.hour: the hour, whole or fractional (0 <= hour < 24). The default
--   is the current time.
-- opts.set: a set name, or a set table passed directly. The default is
--   the setup() set ("bonsai" out of the box).
-- opts.boxed: shorthand for set = "bonsai_boxed" (kept for old configs).
-- opts.default: the fallback ascii for a bad hour value or unknown set.
-- opts.frame: force a frame index on an animated stage, the way opts.hour
--   forces the stage. The default is the current time.
-- opts.frame_ms: this call's animation speed.
-- opts.now_ms: force the clock that picks the frame. For tests.
Sprout.pick = function(opts)
	opts = opts or {}
	local hour = tonumber(opts.hour) or fractional_hour()
	local set = resolve_set(opts.set or (opts.boxed and "bonsai_boxed") or config.set)
	local count = set and stage_count(set) or 0
	if count == 0 then
		return opts.default
	end

	-- Each stage covers an even slice of the day: 24 / count hours.
	local index = math.floor(hour / 24 * count)
	if index < 0 or index >= count then
		return opts.default
	end

	local stage = stage_at(set, index)
	if type(stage) == "string" then
		return stage
	end
	if type(stage) ~= "table" or #stage == 0 then
		return opts.default
	end

	-- An animated stage holds a loop of frames. The frame comes from the
	-- clock, exactly as the stage does. So pick() called once returns a
	-- coherent frame, and pick() called on a timer animates. There is no
	-- animation state anywhere and nothing to keep in sync.
	local frame = tonumber(opts.frame)
	if not frame then
		local at = tonumber(opts.now_ms) or now_ms()
		frame = math.floor(at / resolve_frame_ms(opts, set))
	end
	return stage[math.floor(frame) % #stage + 1] or opts.default
end

local animate_seq = 0

-- animate(opts): drive a consumer from the frame clock.
--
-- This is the opt-in layer. Nothing starts a timer unless a caller asks for
-- it, so pick() remains the whole API for anyone who renders once.
--
-- opts.on_frame(art): required. Called with the new art, and only when it
--   differs from the art last delivered. A static stage therefore costs one
--   comparison per tick and no redraws at all.
-- opts.while_buf: stop when this buffer unloads.
-- opts.set, opts.frame_ms, opts.hour, opts.default: as pick().
--
-- Returns a handle with stop().
Sprout.animate = function(opts)
	opts = opts or {}
	assert(type(opts.on_frame) == "function", "sprout: animate needs an `on_frame` function")

	local set = resolve_set(opts.set or (opts.boxed and "bonsai_boxed") or config.set)
	local period = resolve_frame_ms(opts, set)
	local timer = uv.new_timer()

	animate_seq = animate_seq + 1
	local group = vim.api.nvim_create_augroup("SproutAnimate" .. animate_seq, { clear = true })

	local handle = { stopped = false }
	local last = nil

	function handle.stop()
		if handle.stopped then
			return
		end
		handle.stopped = true
		timer:stop()
		if not timer:is_closing() then
			timer:close()
		end
		pcall(vim.api.nvim_del_augroup_by_id, group)
	end

	local tick = function()
		if handle.stopped then
			return
		end
		local art = Sprout.pick(opts)
		if art == nil or art == last then
			return
		end
		last = art
		-- A leaked timer writing to a dead buffer throws on every tick. Stop
		-- on the first failure rather than repeat it several times a second.
		local ok, err = pcall(opts.on_frame, art)
		if not ok then
			handle.stop()
			vim.notify("sprout: animation stopped, on_frame failed: " .. tostring(err), vim.log.levels.WARN)
		end
	end

	local start = function()
		if handle.stopped then
			return
		end
		timer:stop()
		-- Tick faster than the frame period, so a frame boundary is never
		-- missed by a whole frame.
		timer:start(0, math.max(20, math.floor(period / 4)), vim.schedule_wrap(tick))
	end

	-- Pause while Neovim does not have focus. The frames come from the
	-- clock, so the loop lands on the right frame when focus returns and
	-- needs no catch-up.
	vim.api.nvim_create_autocmd("FocusLost", {
		group = group,
		callback = function()
			timer:stop()
		end,
	})
	vim.api.nvim_create_autocmd("FocusGained", { group = group, callback = start })

	if opts.while_buf then
		vim.api.nvim_create_autocmd({ "BufUnload", "BufDelete" }, {
			group = group,
			buffer = opts.while_buf,
			callback = function()
				handle.stop()
			end,
		})
	end

	start()
	return handle
end

return Sprout
