# sprout.nvim
## Track your day, watch something live!

<p align="center">
    <img src="assets/bonsai.gif" alt="A gif of a bonsai growing from a sprout, to full, to dead">
</p>

It's 8:30 A.M. You're getting a head start on long day of writing TOML by hand.
You're greeted by a gentle sapling, just starting out it's life.

It's 11:45 A.M. No strings have been parsed correctly all in any bit of config
you've written. You're beginning to question what a string even is. But the
bonsai you see is strong. It's just begun to rise to meet the summer wind.

It's 7:52 P.M. Your phone has five missed calls from "Home" and your childrens
names are a blur. Was this YAML the whole time? What does QWEN think? Your
bonsai has begun to droop and drop it's leaves. Where did the time go?

It's 11:59 P.M. Chaos reigns. Single, double, even triple quotes dot the
pockmarked landscape of your buffers. Numbers are strings are blocks are files
are ... Your bonsai is dead. Just wood where life was. A cold draft sweeps
through and seems to turn the hands of the clock itself. 

12:00 A.M. A new day is here. You blink, rub, shake your head. The scales have fallen
from your eyes. The file parses clean, it was JSON all along! Ship it! Go Home!
Swim through the still blue midnight air to the warm embrace of _home_,
meatloaf still there in the microwave, _waiting_. Your bonsai is reborn. Just a
sprig now, but ready to grow strong while you sleep.


## Yeah but what is it?
It's a way to have an image grow over time in your dashboard. It handles picking
an image from a list of any length based on what time it is.

I wrote this description and the bonsai art and the original local version by
hand. I packaged it all up using Claude so others could use it.

## Usage

```lua
-- lazy.nvim
{  "zdcthomas/sprout.nvim", lazy = true }
```

Basic usage:
```lua
local header = require("sprout").pick({})
```

`pick` returns the stage for the time of day as a multiline string. The
day is split evenly across the stages of the set, so a set can have any
number of stages. Minutes and seconds count: a set with 48 stages moves
to the next stage every 30 minutes. To pick for another time, pass a
whole or fractional hour: `pick({ hour = 13.5 })` is 13:30.

## Art sets

Set a default set once:

```lua
require("sprout").setup({ set = "bonsai_boxed" })
```

Supply your own set with `register`. Stages are ordered youngest to
oldest:

```lua
require("sprout").register("cactus", {
	stages = { seed_art, sprout_art, full_art },
})

local header = require("sprout").pick({ set = "cactus" })
```

`pick` also accepts a set table directly: `pick({ set = { stages = {...} } })`.
The raw art is available in the `require("sprout").sets` registry, e.g.
`sets.bonsai.stages`.

### The spirograph set

`spiro` is a generated set. Nobody drew it; it is the curve a spirograph
draws, sampled into characters:

```lua
require("sprout").setup({ set = "spiro" })
```

It has 96 stages, one every 15 minutes, and each one animates. Across the
day the figure runs from a near circle, through sharp cusps, into a looped
rosette. Stages build the first time you ask for them, so the set costs
nothing until you use it.

Resize it to fit your dashboard:

```lua
require("sprout").register("spiro_narrow",
  require("sprout.sets.spiro").new({ width = 32, height = 16 }))
```

`new` also takes `count`, `frames`, `steps` and `frame_ms`.

## Animation

Animation is optional and off by default. If you never call `animate`, no
timer runs and nothing changes: `pick` returns a string, as it always has.

A stage may be a single string, as above, or a list of strings that form a
loop. The two mix freely in one set:

```lua
require("sprout").register("bonsai_windy", {
  stages = {
    { sprout_1, sprout_2, sprout_3 }, -- a swaying loop
    baby,                             -- a static stage, still fine
    { full_1, full_2 },               -- a rustling loop
  },
  frame_ms = 400,
})
```

Keep every frame of one stage the same width and line count, or the layout
jumps halfway through the loop. `register` warns if they do not match.

### Two clocks

The stage still advances only with the time of day. The frame is a second,
faster clock. Both derive from the current time, so there is no animation
state anywhere:

```
stage = floor(hour / 24 * stage_count)
frame = floor(now_ms / frame_ms) % frame_count
```

That means `pick` alone already animates. Call it once and it returns a
coherent frame. Call it on a timer and the art moves. `animate` is a
convenience that owns the timer for you.

Speed resolves from the narrowest scope outwards: the `pick` or `animate`
call, then the set's `frame_ms`, then `setup({ frame_ms = ... })`, then
400ms.

### `animate`

```lua
local handle = require("sprout").animate({
  set = "spiro",
  on_frame = function(art) --[[ redraw with art ]] end,
  while_buf = buf,   -- optional: stop when this buffer unloads
})

handle.stop()
```

`on_frame` runs only when the art differs from the last art delivered, so a
static stage costs one comparison per tick and no redraws. The animation
also:

- pauses while Neovim does not have focus, and resumes on the frame the
  clock says, with no catch-up,
- stops itself if `on_frame` throws, rather than repeating the failure
  several times a second,
- stops itself when `while_buf` unloads.

`animate` takes the same `set`, `hour`, `frame_ms` and `default` options as
`pick`.

### With mini.starter

```lua
local sprout = require("sprout")
local starter = require("mini.starter")

starter.setup({
  header = function() return sprout.pick({ set = "spiro" }) end,
  silent = true,  -- see below
})

vim.api.nvim_create_autocmd("User", {
  pattern = "MiniStarterOpened",
  callback = function(args)
    -- MiniStarter.refresh() resets the selected item, so put the cursor
    -- back where it was.
    local refresh = function()
      local row = vim.api.nvim_win_get_cursor(0)[1]
      starter.refresh(args.buf)
      for _ = 1, 32 do
        if vim.api.nvim_win_get_cursor(0)[1] == row then break end
        starter.update_current_item("next")
      end
    end
    sprout.animate({
      set = "spiro",
      while_buf = args.buf,
      on_frame = refresh,
    })
  end,
})
```

Two things in that recipe are not obvious, and both bite hard at 4 frames
per second:

1. **Set `silent = true`.** Every `MiniStarter.refresh()` forces a redraw
   and echoes the current query. Without `silent`, an animated header
   overwrites your command line several times a second.
2. **Put the cursor back.** `refresh()` resets the selected item to the
   first one on every call, even when the header did not change. Without
   the loop above you cannot navigate the dashboard with `j` and `k`,
   because the selection snaps back to the top between keystrokes.

Dashboards with no refresh API, such as dashboard-nvim and startify, render
once and keep working unchanged. `pick` returns a valid frame, so they show
a still image rather than a broken one.

## Tests

```
nvim --headless -u NONE -c "set rtp+=." -S scripts/test.lua
```
