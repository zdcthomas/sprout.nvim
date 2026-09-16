# TODO

## Animated stages — built

The animation layer is in. `pick` resolves a frame after the stage, and
`animate` owns a timer for consumers that can redraw. Both are documented
in the README. `spiro` is the first set that uses it.

Animation stays optional. Nothing starts a timer unless a caller asks, and
`pick` still returns a plain string.

### What the prototypes settled

Two probes ran before any of this was written, and both changed the design.

**mini.starter works, with two hazards.** `refresh()` does re-evaluate a
function header, and costs about 1 ms, so speed was never the problem. But:

- Every `refresh()` forces a redraw and echoes the query, which overwrites
  the command line 2-4 times a second. `silent = true` fixes it.
- `refresh()` resets the selected item to the first one on every call, even
  with a completely static header. Confirmed in isolation, so this is
  `refresh()` itself and not the animation. At 4 fps you cannot navigate
  with `j` and `k`. The README recipe walks the selection back.

**`os.time()` is not enough.** It resolves only to the second, which is too
coarse below a 1s frame period. `uv.gettimeofday()` gives wall clock
milliseconds. Wall clock matters rather than monotonic time, so two Neovim
instances agree on the frame.

**Generate one stage at a time.** A whole 96-stage generated set costs 45
to 215 ms depending on the generator. Per stage it is 1 to 2 ms. Stages
build on demand and are kept.

**Baking the spirograph into a static file was tried and rejected.** A
build script rendered the art to literal Lua, so `spiro` could be plain
data like the bonsai sets and the runtime would need no generator concept
at all. The art is what killed it:

| Shape | File |
|---|---|
| 24 stages x 8 frames, 40x18 | 141 KB |
| 96 stages x 16 frames, 44x20 | 1.3 MB |

Load time was never the problem — 0.7 ms and 5.9 ms respectively, because
Lua parses long strings fast. The problem is repo weight. The rest of the
plugin is about 12 KB, so even the small version is ten times the size of
everything else, and it would have to be regenerated and re-committed for
any change to the art or its size. The generator is 40 lines and costs
1.4 ms per stage on demand. Keep it generated.

### Open questions, now answered

- Speed scope: the call, then the set, then `setup()`, then 400ms. Per-stage
  timing was dropped as YAGNI.
- Data shape: Option A. A `stages` entry is a string or a list of frames,
  in one field. One source of truth, and the two cannot drift.
- `MiniStarter.refresh()` at 2-4 fps: yes, about 1 ms per call.

### Deviations from the original spec

- `animate` does not idle until the stage boundary when the stage is
  static. The change check already reduces a static stage to one comparison
  per tick, so the extra scheduling logic bought nothing.

## Still to do

- [ ] Hand-drawn animation frames for the bonsai sets. The data model
      accepts them now; the art does not exist. Four candidate sway
      techniques were prototyped and are worth a look before drawing a full
      set: a narrow canopy shift, a graded bend, glyph flips with no
      movement, and a bend with a petal blowing off. The bend plus the
      drifting petal read as wind most clearly, because the petal gives the
      motion a direction that a bend alone does not.
- [ ] `make_gif.py` renders one frame per stage. Update it to play each
      stage's loop a few times before advancing, so the gif shows the
      animation. It also hard-codes a macOS font path.
- [ ] More generated sets. The logistic map and a travelling wind field
      were both prototyped and both worked. The logistic map is the
      interesting one: its animation period doubles as the day goes on and
      then breaks into chaos, with no extra design. Its loop does not close
      in the chaotic band, which may be right rather than broken.
