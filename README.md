# bonsai.nvim

![The bonsai grows from a sprout to an old tree, then dies](assets/bonsai.gif)

An ascii bonsai that grows with the hour of the day. Six stages, from a
sprout at midnight to an old tree at night. Boxed variants included.

## Usage

```lua
-- lazy.nvim
{ dir = "~/dev/bonsai.nvim", name = "bonsai.nvim", lazy = true }
```

```lua
local header = require("bonsai").pick({
	hour = tonumber(vim.fn.strftime("%H")), -- default: current hour
	boxed = false,                          -- default: false
	default = some_fallback_ascii,          -- returned for a bad hour
})
```

`pick` returns the tree for the hour as a multiline string. The raw art is
available as `require("bonsai").trees.unboxed` and `.boxed`, each ordered
youngest to oldest.
