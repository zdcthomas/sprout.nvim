-- Tests for sprout.nvim. Run from the repo root:
--
--   nvim --headless -u NONE -c "set rtp+=." -S scripts/test.lua
--
-- Exits non-zero if anything fails.

local passed, failed = 0, 0

local function check(name, fn)
	local ok, err = pcall(fn)
	if ok then
		passed = passed + 1
	else
		failed = failed + 1
		io.stdout:write("FAIL  " .. name .. "\n      " .. tostring(err) .. "\n")
	end
end

local function eq(got, want, what)
	if got ~= want then
		error(string.format("%s: got %s, want %s", what or "value", vim.inspect(got), vim.inspect(want)), 2)
	end
end

local function truthy(got, what)
	if not got then
		error((what or "value") .. " should be truthy, got " .. vim.inspect(got), 2)
	end
end

local sprout = require("sprout")

-- A static set, the shape every existing set uses.
local static = { stages = { "one", "two", "three", "four" } }
-- A set whose middle stage animates, to prove the two shapes mix.
local mixed = { stages = { "still", { "a", "b", "c" } }, frame_ms = 100 }

-- Stage selection -----------------------------------------------------

check("hour 0 picks the first stage", function()
	eq(sprout.pick({ set = static, hour = 0 }), "one")
end)

check("the day splits evenly across stages", function()
	eq(sprout.pick({ set = static, hour = 5.99 }), "one")
	eq(sprout.pick({ set = static, hour = 6 }), "two")
	eq(sprout.pick({ set = static, hour = 12 }), "three")
	eq(sprout.pick({ set = static, hour = 23.99 }), "four")
end)

check("an out of range hour falls back to the default", function()
	eq(sprout.pick({ set = static, hour = 24, default = "fallback" }), "fallback")
	eq(sprout.pick({ set = static, hour = -1, default = "fallback" }), "fallback")
end)

check("an unknown set falls back to the default", function()
	eq(sprout.pick({ set = "no-such-set", default = "fallback" }), "fallback")
end)

check("a fractional hour subdivides the day", function()
	local many = { stages = {} }
	for i = 1, 48 do
		many.stages[i] = "s" .. i
	end
	eq(sprout.pick({ set = many, hour = 0.49 }), "s1")
	eq(sprout.pick({ set = many, hour = 0.5 }), "s2")
end)

-- Frame selection -----------------------------------------------------

check("a static stage ignores the frame clock", function()
	eq(sprout.pick({ set = mixed, hour = 0, now_ms = 0 }), "still")
	eq(sprout.pick({ set = mixed, hour = 0, now_ms = 999999 }), "still")
end)

check("an animated stage picks its frame from the clock", function()
	local at = function(ms)
		return sprout.pick({ set = mixed, hour = 12, now_ms = ms })
	end
	eq(at(0), "a")
	eq(at(100), "b")
	eq(at(200), "c")
end)

check("the frame loop wraps", function()
	local at = function(ms)
		return sprout.pick({ set = mixed, hour = 12, now_ms = ms })
	end
	eq(at(300), "a", "frame 3 wraps to frame 0")
	eq(at(0), at(300), "one full loop returns the same art")
end)

check("opts.frame forces a frame, as opts.hour forces a stage", function()
	eq(sprout.pick({ set = mixed, hour = 12, frame = 0 }), "a")
	eq(sprout.pick({ set = mixed, hour = 12, frame = 1 }), "b")
	eq(sprout.pick({ set = mixed, hour = 12, frame = 5 }), "c", "frame 5 wraps to frame 2")
end)

check("frame_ms resolves call, then set, then setup", function()
	-- The set says 100ms, so at 150ms the set is one frame in.
	eq(sprout.pick({ set = mixed, hour = 12, now_ms = 150 }), "b")
	-- The call overrides the set: at 50ms per frame, 150ms is three frames.
	eq(sprout.pick({ set = mixed, hour = 12, now_ms = 150, frame_ms = 50 }), "a")

	-- A set with no frame_ms of its own falls through to setup().
	local bare = { stages = { { "x", "y" } } }
	sprout.setup({ frame_ms = 1000 })
	eq(sprout.pick({ set = bare, hour = 0, now_ms = 0 }), "x")
	eq(sprout.pick({ set = bare, hour = 0, now_ms = 1000 }), "y")
	sprout.setup({ frame_ms = 400 })
end)

-- register ------------------------------------------------------------

check("register accepts a mixed set", function()
	sprout.register("test_mixed", { stages = { "flat", { "p", "q" } } })
	eq(sprout.pick({ set = "test_mixed", hour = 0 }), "flat")
	eq(sprout.pick({ set = "test_mixed", hour = 18, frame = 1 }), "q")
end)

check("register rejects a set with no stages", function()
	truthy(not pcall(sprout.register, "bad", {}))
	truthy(not pcall(sprout.register, "bad", { stages = {} }))
end)

check("register rejects a stage that is not a string or a list of strings", function()
	truthy(not pcall(sprout.register, "bad", { stages = { 42 } }))
	truthy(not pcall(sprout.register, "bad", { stages = { {} } }))
	truthy(not pcall(sprout.register, "bad", { stages = { { "ok", 7 } } }))
end)

check("register rejects a generated set with no count", function()
	truthy(not pcall(sprout.register, "bad", { stage = function() end }))
end)

-- Generated sets ------------------------------------------------------

check("a generated set builds stages on demand and keeps them", function()
	local calls = 0
	local generated = {
		count = 4,
		stage = function(index)
			calls = calls + 1
			return "gen" .. index
		end,
	}
	eq(sprout.pick({ set = generated, hour = 0 }), "gen0")
	eq(calls, 1, "one stage built")
	eq(sprout.pick({ set = generated, hour = 0 }), "gen0")
	eq(calls, 1, "the second pick reuses the built stage")
	eq(sprout.pick({ set = generated, hour = 18 }), "gen3")
	eq(calls, 2, "a different stage builds once more")
end)

-- The spirograph set --------------------------------------------------

check("the spirograph set produces art at every stage", function()
	local spiro = require("sprout.sets.spiro")
	for _, hour in ipairs({ 0, 6, 12, 18, 23.9 }) do
		local art = sprout.pick({ set = spiro, hour = hour, frame = 0 })
		truthy(type(art) == "string" and #art > 0, "art at hour " .. hour)
		truthy(art:find("&", 1, true) or art:find("*", 1, true), "art at hour " .. hour .. " has ink")
	end
end)

check("every frame of every spirograph stage shares a shape", function()
	local spiro = require("sprout.sets.spiro")
	local shape = function(art)
		local lines = vim.split(art, "\n", { plain = true })
		local width = 0
		for _, line in ipairs(lines) do
			width = math.max(width, #line)
		end
		return #lines, width
	end
	for index = 0, spiro.count - 1 do
		local loop = spiro.stage(index, spiro.count)
		local rows, cols = shape(loop[1])
		for frame = 2, #loop do
			local r, c = shape(loop[frame])
			eq(r, rows, string.format("stage %d frame %d line count", index, frame))
			eq(c, cols, string.format("stage %d frame %d width", index, frame))
		end
	end
end)

check("a spirograph stage is an animation loop that closes", function()
	local spiro = require("sprout.sets.spiro")
	local loop = spiro.stage(0, spiro.count)
	truthy(#loop > 1, "a stage holds several frames")
	eq(
		sprout.pick({ set = spiro, hour = 0, frame = #loop }),
		sprout.pick({ set = spiro, hour = 0, frame = 0 }),
		"one full loop returns the same art"
	)
end)

check("the spirograph set is generated, not stored", function()
	local spiro = require("sprout.sets.spiro")
	eq(type(spiro.stage), "function", "it builds stages on demand")
	eq(spiro.stages, nil, "no art is baked into the repo")
	truthy(spiro.count > 1, "several stages")
	truthy(type(spiro.frame_ms) == "number", "the set carries its own speed")
end)

check("spiro.new resizes the art", function()
	local spiro = require("sprout.sets.spiro")
	local small = spiro.new({ width = 32, height = 16 })
	local lines = vim.split(sprout.pick({ set = small, hour = 20, frame = 0 }), "\n", { plain = true })
	eq(#lines, 16, "line count")
	eq(#lines[1], 32, "width")
end)

check("the spirograph changes shape across the day", function()
	local spiro = require("sprout.sets.spiro")
	local dawn = sprout.pick({ set = spiro, hour = 1, frame = 0 })
	local dusk = sprout.pick({ set = spiro, hour = 22, frame = 0 })
	truthy(dawn ~= dusk, "dawn and dusk differ")
end)

-- animate -------------------------------------------------------------

check("animate needs an on_frame function", function()
	truthy(not pcall(sprout.animate, {}))
end)

check("animate delivers frames and stop() ends it", function()
	local seen = {}
	local handle = sprout.animate({
		set = mixed,
		hour = 12,
		frame_ms = 30,
		on_frame = function(art)
			seen[#seen + 1] = art
		end,
	})
	vim.wait(400, function()
		return #seen >= 3
	end, 10)
	handle.stop()
	truthy(#seen >= 3, "at least three frames arrived, got " .. #seen)

	local after = #seen
	vim.wait(150)
	eq(#seen, after, "no frames arrive after stop()")
end)

check("animate reports the same art only once", function()
	local seen = 0
	local handle = sprout.animate({
		set = static, -- every stage is static, so the art never changes
		hour = 0,
		frame_ms = 30,
		on_frame = function()
			seen = seen + 1
		end,
	})
	vim.wait(250)
	handle.stop()
	eq(seen, 1, "a static stage delivers one frame and then stays quiet")
end)

check("animate stops when on_frame fails", function()
	local calls = 0
	local handle = sprout.animate({
		set = static,
		hour = 0,
		frame_ms = 30,
		on_frame = function()
			calls = calls + 1
			error("consumer is gone")
		end,
	})
	vim.wait(250)
	truthy(handle.stopped, "the handle reports itself stopped")
	eq(calls, 1, "the failing consumer is called once, not repeatedly")
	handle.stop()
end)

check("animate stops when its buffer unloads", function()
	local buf = vim.api.nvim_create_buf(false, true)
	local handle = sprout.animate({
		set = mixed,
		hour = 12,
		frame_ms = 30,
		while_buf = buf,
		on_frame = function() end,
	})
	vim.wait(100)
	truthy(not handle.stopped, "still running while the buffer lives")
	vim.api.nvim_buf_delete(buf, { force = true })
	vim.wait(200, function()
		return handle.stopped
	end, 10)
	truthy(handle.stopped, "stopped after the buffer went away")
end)

check("stop() is safe to call twice", function()
	local handle = sprout.animate({ set = static, hour = 0, on_frame = function() end })
	handle.stop()
	handle.stop()
end)

-- Existing behaviour --------------------------------------------------

check("the shipped bonsai sets still return plain strings", function()
	for _, name in ipairs({ "bonsai", "bonsai_boxed" }) do
		for hour = 0, 23 do
			local art = sprout.pick({ set = name, hour = hour })
			eq(type(art), "string", name .. " at hour " .. hour)
		end
	end
end)

check("pick with no arguments works", function()
	eq(type(sprout.pick()), "string")
	eq(type(sprout.pick({})), "string")
end)

-- ---------------------------------------------------------------------

io.stdout:write(string.format("\n%d passed, %d failed\n", passed, failed))
vim.cmd(failed == 0 and "qa!" or "cq!")
