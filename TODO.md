# TODO

## Animated stages (spec, undecided)

Status: idea only. It might be too heavy-handed; per-stage art cost is
real. Spec kept here so the design is ready if it ever feels worth it.

### The idea

Each stage is itself a small animation loop, while the stage still
advances only with the time of day. The sprout sways in the wind. The
full tree rustles and drops leaves. Two clocks, two speeds:

- Stage clock: the existing time-of-day slice. Slow. Unchanged.
- Frame clock: a loop of frames inside the current stage. Fast (~2-4 fps).

### Data model

A stage becomes either a string (static, exactly as today) or a list of
frame strings (an animation loop). Mixed sets are allowed:

```lua
require("sprout").register("bonsai_windy", {
  stages = {
    { sprout_1, sprout_2, sprout_3 }, -- swaying loop
    baby,                             -- static stage, still fine
    { full_1, full_2 },               -- rustling loop
  },
  frame_ms = 400, -- optional, per set; default TBD (~400ms)
})
```

Rules:

- All frames in one stage should share the same line count and width,
  so the layout does not shift mid-loop. `register` could warn.
- `register` validation: a stage is a string, or a non-empty list of
  strings.

### Design decision: frames are a function of the clock

No animation state anywhere. Extend `pick` so the frame, like the
stage, derives from the current time:

```
stage = floor(hour / 24 * #stages)            -- existing
frame = floor(now_seconds / frame_ms_in_s) % #stage_frames
```

Consequences:

- `pick()` stays the single entry point. Called once, it returns a
  coherent frame. Called on a timer, it animates. Nothing to sync.
- Static consumers (dashboards that render once) need zero changes and
  never see a half-baked API. They just get whatever frame the clock
  says.
- Deterministic and testable: pass a fake time, get a known frame.
- Needs a "now" with sub-second or second resolution in addition to the
  fractional hour. `os.time()` is enough at >= 1s frame periods;
  `vim.uv.now()` if faster loops ever matter.

### API surface

- `pick(opts)`: unchanged signature. Resolves stage, then frame.
  Possibly `opts.frame` to force a frame index (mirrors `opts.hour`).
- `animate(opts)`: the opt-in layer, hidden behind explicit use so
  every existing consumer keeps both options.
  - `opts.set`, same resolution rules as `pick`.
  - `opts.on_frame(art)`: called with the new frame only when it
    differs from the last one delivered.
  - `opts.frame_ms`: override the set's timing.
  - Returns a handle with `stop()`.
  - Timer via `vim.uv.new_timer`; every callback wrapped in
    `vim.schedule`.
  - Self-stopping: stop when `on_frame` errors (dead buffer) or when a
    caller-provided `opts.while_buf` buffer unloads. A leaked timer
    writing to a dead buffer throws on every tick.
  - If the resolved stage is static (a plain string), fire `on_frame`
    once and idle until the stage boundary instead of ticking.

### Dashboard integration

- mini.starter (the target): README recipe. `header` as a function that
  calls `pick`, plus `animate` with `on_frame = MiniStarter.refresh`.
  Check: does `refresh` move the cursor or fight with query input?
- dashboard-nvim / startify: no refresh API, render once. They keep
  working automatically because `pick` returns a valid frame. No direct
  buffer-writing support; not worth the fragility.

### Art cost (the real blocker)

- 6 stages x 3-4 frames each is ~20 hand-drawn variants per set.
- Wind/leaf-fall reads well with tiny diffs: shift a few `&` and `\`
  characters per frame. Maybe a helper script to preview loops in the
  terminal.
- `make_gif.py` update: render each stage's loop a few times before
  advancing, so the gif shows the animation.

### Open questions

- [ ] Global default `frame_ms`, or per set, or per stage?
- [ ] Should frame timing pause when Neovim loses focus? (battery)
- [ ] Does `MiniStarter.refresh()` re-evaluate the header cheaply
      enough at 2-4 fps?
- [ ] Is the `{ frames... }` nested-list format right, or should
      animation live in a parallel `loops` field so `stages` stays
      flat?

### Decision checklist before building

- [ ] Draw one swaying-sprout loop by hand and eyeball it in a buffer.
      If the art does not read as wind, stop here.
- [ ] Prototype the mini.starter refresh timer with two dummy frames.
      If it flickers or fights the cursor, stop here.
- [ ] Only then extend `pick` and `register`.
