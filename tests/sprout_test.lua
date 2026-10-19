-- Run with: nvim --clean -l tests/sprout_test.lua
-- Exits non-zero on the first failed check.
package.path = "./lua/?.lua;./lua/?/init.lua;" .. package.path

local sprout = require("sprout")
local failures = 0

local function check(name, got, want)
	if got ~= want then
		failures = failures + 1
		print(("FAIL %s: got %s, want %s"):format(name, vim.inspect(got), vim.inspect(want)))
	else
		print("ok   " .. name)
	end
end

local three = { stages = { "a", "b", "c" } }

-- Even split of the day across the stages.
check("hour 0 is the first stage", sprout.pick({ set = three, hour = 0 }), "a")
check("hour 7.99 is still the first stage", sprout.pick({ set = three, hour = 7.99 }), "a")
check("hour 8 is the second stage", sprout.pick({ set = three, hour = 8 }), "b")
check("hour 16 is the third stage", sprout.pick({ set = three, hour = 16 }), "c")
check("hour 23.999 is the last stage", sprout.pick({ set = three, hour = 23.999 }), "c")
check("a string hour parses", sprout.pick({ set = three, hour = "8" }), "b")

-- Bad hour values fall back to the default.
check("hour 24 falls back", sprout.pick({ set = three, hour = 24, default = "d" }), "d")
check("hour -1 falls back", sprout.pick({ set = three, hour = -1, default = "d" }), "d")
check("non-numeric hour falls back", sprout.pick({ set = three, hour = "noon", default = "d" }), "d")
check("fallback is nil without a default", sprout.pick({ set = three, hour = 24 }), nil)

-- Set resolution.
local notified = {}
vim.notify = function(msg)
	notified[#notified + 1] = msg
end
check("unknown set falls back", sprout.pick({ set = "nope", hour = 0, default = "d" }), "d")
check("unknown set warns", #notified, 1)
sprout.pick({ set = "nope", hour = 0 })
check("unknown set warns only once", #notified, 1)

check("boxed shorthand picks the boxed set", sprout.pick({ boxed = true, hour = 0 }), sprout.sets.bonsai_boxed.stages[1])
check("default set is bonsai", sprout.pick({ hour = 0 }), sprout.sets.bonsai.stages[1])

sprout.setup({ set = "bonsai_boxed" })
check("setup changes the default set", sprout.pick({ hour = 0 }), sprout.sets.bonsai_boxed.stages[1])
sprout.setup({ set = "bonsai" })

sprout.register("cactus", { stages = { "x\n", "y" } })
check("register makes a set available", sprout.pick({ set = "cactus", hour = 12 }), "y")
check("register strips a trailing newline", sprout.pick({ set = "cactus", hour = 0 }), "x")
check("register rejects an empty list", pcall(sprout.register, "empty", { stages = {} }), false)
check("register rejects a non-string stage", pcall(sprout.register, "bad", { stages = { 1 } }), false)
check("register rejects an empty name", pcall(sprout.register, "", three), false)

-- Built-in art has no leading tabs and no trailing blank line.
for name, set in pairs(sprout.sets) do
	for i, stage in ipairs(set.stages) do
		check(("%s stage %d has no tab"):format(name, i), stage:find("\t") == nil, true)
		check(("%s stage %d has no trailing newline"):format(name, i), stage:sub(-1) ~= "\n", true)
	end
end
check("bonsai ends with the dead tree", #sprout.sets.bonsai.stages, 7)

-- Every row of a boxed stage has the same width, so the frame lines up.
for i, stage in ipairs(sprout.sets.bonsai_boxed.stages) do
	local lines = vim.split(stage, "\n")
	local widest = 0
	for _, l in ipairs(lines) do
		widest = math.max(widest, #l)
	end
	for j, l in ipairs(lines) do
		if #l > 0 and widest - #l <= 3 then
			check(("boxed stage %d row %d is full width"):format(i, j), #l, widest)
		end
	end
end

if failures > 0 then
	print(("%d check(s) failed"):format(failures))
	os.exit(1)
end
print("all checks passed")
