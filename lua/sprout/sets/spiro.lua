-- A generated art set: the hypotrochoid, the curve a spirograph draws.
--
--   x = (R-r)*cos(th) + d*cos(((R-r)/r)*th)
--   y = (R-r)*sin(th) - d*sin(((R-r)/r)*th)
--
-- R is the fixed outer circle, r the small circle rolling inside it, and d
-- the pen's distance from that small circle's centre.
--
-- Two variables, two roles, which is what makes this work as an art set:
--
--   The stage sets the shape. The lobe count steps from 3 to 6 across the
--   day, and d grows without a break underneath it. The curve closes on the
--   ratio R/r alone, so d is free to take any value: the figure runs from a
--   near circle, through sharp cusps at d = r, into a looped rosette past
--   it, and stays a closed curve the whole way.
--
--   The frame sets the rotation, and nothing else. The figure has n-fold
--   symmetry, so turning it by exactly one lobe over the loop maps it back
--   onto itself. The loop closes and each step stays small.
--
-- Stages build on demand. A stage costs a millisecond or two, so building
-- all 96 up front would stall startup for art the reader may never see.

local M = {}

local DEFAULTS = {
	count = 96, -- stages per day: one every 15 minutes
	frames = 16, -- frames in each stage's loop
	width = 44,
	height = 20,
	steps = 1500, -- samples along the curve
	frame_ms = 120,
}

local blank = function(w, h)
	local grid = {}
	for r = 1, h do
		grid[r] = {}
		for c = 1, w do
			grid[r][c] = " "
		end
	end
	return grid
end

local plot = function(grid, x, y, ch)
	local c = math.floor(x + 0.5)
	local r = math.floor(y + 0.5)
	if grid[r] and grid[r][c] then
		grid[r][c] = ch
	end
end

local to_art = function(grid)
	local rows = {}
	for i, row in ipairs(grid) do
		rows[i] = table.concat(row)
	end
	return table.concat(rows, "\n")
end

local render = function(o, index, count, frame)
	local t = count > 1 and index / (count - 1) or 0
	local n = 3 + math.floor(t * 3.999) -- 3 to 6 lobes
	local d = (0.3 + 2.9 * t) / n -- pen distance, as a multiple of r = 1/n
	local rim = 1 - 1 / n -- R - r, with R = 1 and r = 1/n

	local spin = (2 * math.pi / n) * frame / o.frames
	local cs, sn = math.cos(spin), math.sin(spin)

	local grid = blank(o.width, o.height)
	local cx, cy = o.width / 2 + 0.5, o.height / 2 + 0.5
	-- Terminal cells are about twice as tall as they are wide. Fit to
	-- whichever axis binds, then halve the vertical radius, so the figure
	-- stays round instead of stretching sideways.
	local base = math.min(o.width / 2 - 1, o.height - 1)
	local rx = base / (rim + d)
	local ry = rx / 2

	for i = 0, o.steps do
		local th = 2 * math.pi * i / o.steps
		local x = rim * math.cos(th) + d * math.cos((n - 1) * th)
		local y = rim * math.sin(th) - d * math.sin((n - 1) * th)
		-- Rotate the finished point, so the shape itself does not change.
		local xr = x * cs - y * sn
		local yr = x * sn + y * cs
		-- The outer reaches read as leaves, the inner loops as blooms, which
		-- reuses the character alphabet the bonsai sets already use.
		local far = (x * x + y * y) > rim * rim
		plot(grid, cx + rx * xr, cy + ry * yr, far and "&" or "*")
	end

	return to_art(grid)
end

-- Build a spirograph set. Override any of DEFAULTS, for instance to fit a
-- narrower dashboard: require("sprout.sets.spiro").new({ width = 32 }).
M.new = function(opts)
	local o = vim.tbl_extend("force", DEFAULTS, opts or {})
	return {
		count = o.count,
		frame_ms = o.frame_ms,
		stage = function(index, count)
			local loop = {}
			for frame = 0, o.frames - 1 do
				loop[frame + 1] = render(o, index, count, frame)
			end
			return loop
		end,
	}
end

local default = M.new()
default.new = M.new

return default
