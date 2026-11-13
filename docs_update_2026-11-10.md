# Project materials update (2026-11-10 / hakubo-death-movie branch)

Text to paste into the claude.ai Project materials. Delete this file once pasted (it isn't committed).

---

## Additions to "Current implementation snapshot"

### Hakubo's defeat sequence (rebuilt)
- `script/stage/hakubo_defeat_sequence.gd` (`HakuboDefeatSequence`, at `Battle/DefeatSequence` in `boss_stage.tscn`)
  - `battle_manager._end_battle(true)` runs `await defeat_sequence.play(ctx)` → checks the generation number → `battle_finished.emit(true)`
  - Timeline (real seconds, all `@export`): 0.00 hard stop + indigo flash + SE `hakubo_defeat` → 0.12 silence (`stop_bgm(0.05)`), 0.3x slow motion, camera moves in to 1.3x, letterbox bars → 0.3 main mana bar shatters, HUD fades out → 1.2 indigo wave (paint_blob r=60→300) → 2.0 "討" + one line per form → 2.8 bird calls + time-of-day color brightened → 3.5 bars retract → dialogue (about 3.9s in total)
  - `reset()` runs on room re-entry and on return to title, and restores time_scale, bars, text, HUD transparency, and time-of-day color
  - Ambient sound (mystery_se) is muted during the sequence (`boss_stage.set_ambient_muted()`)
- New components: `scene/component/letterbox.tscn` (`Letterbox`), `scene/component/defeat_banner.tscn` (`DefeatBanner`)
- `boss_ui_manager`: added `burst_hakubo_main_bar()` / `fade_out_hud()` / `reset_hud_look()`. `boss_stage.set_hud_visible()` resets the transparency every time
- After defeat, `hakubo._physics_process` only handles the knockback movement (no AI, regen, or retreat to center)

### Effects time management
- `Effects.set_time_scale_for(scale, real_seconds, force, pausable)` is the single entry point. `slowmotion()` is a thin wrapper around it
- Restoring only happens when the generation number matches, and always restores to **1.0** (never to the value at call time). `force` overrides a running slow-motion
- `reset_transient_effects()` / `reset_time_scale()` restore time_scale too
- Added `ignore_time_scale` to `flash_impact()` and `Camera.set_zoom_value()`. BGM fades always run in real time

### Hakubo's per-form look
- `HakuboFormLook` (`script/data/hakubo_form_look.gd`) + `data/hakubo_form_look_0..2.tres` / `_freed.tres`
- `HakuboAppearance` (`hakubo/Appearance`) handles corruption, eye, drips, afterimages, glitch, shadow, and light
  - `hakubo.apply_form_look()` / `tween_corruption()`; corruption +0.05 each time the 1st and 2nd bars break
- `shader/hakubo_corruption.gdshader`: darkens the body. The deep crimson clothing stays as pulsing crimson veins, and the outer edge is rimmed in dark crimson
- `HakuboEye` (`Visual/HakuboEye`): one red eye. Position comes from a per-animation, per-frame table (down (1,-13), right (2,-13), left (-3,-13); walk adds the vertical bob; facing up hides it)
- Story tie-ins: `loop0_post_aura` → form 1 / `loop1_post_aura` → form 2 (1.5s). New signal `Dialogue.loop2_post_disperse` (on the 「呪いが離散してきている。」 line in `loop2_post`) clears the curse over 2s, plus rising crimson particles. During the defeat sequence the final form only drops to 0.6

### Fixed
- **§6-7 (dash sign): fixed.** `_play_death()` now flies away from the player. `dash()`'s "no direction given" is now `NAN` (0.0 = straight right)

### Scope change
- **The flashback rematch with Hakubo and the player's weapon evolution are dropped entirely.** Delete or mark as dropped any plans, TODOs, or design notes that assume them

---

## Additions to "Design lessons and pitfalls (Godot)"

- **Tweens are affected by `Engine.time_scale`.** During a 0.15x slow-motion, a 0.5s tween takes about 3.3s of real time. Use `set_ignore_time_scale(true)` on effect tweens that should run in real time
- **When restoring a slow-motion, never restore "the value at call time."** If they overlap, it gets stuck at 0.4x and so on. Restore to the base value 1.0, and only from the latest generation
- **Use `create_timer(t, false, false, true)` for effect timers.** Arguments: process_always=false (stops while paused) / ignore_time_scale=true
- **A killed tween's `finished` never fires.** Awaiting it can hang forever, so wait on a timer and check the generation number after you resume
- **A child of a `clip_children` sprite gets clipped.** The eye, light, and particles go next to it instead, and copy the sprite's `transform` every frame (equivalent to being a child, without the clipping)
- **A ShaderMaterial inside a `.tscn` is shared by every instance.** For per-instance parameters, set `resource_local_to_scene = true`
- **The built-in `TEXTURE` can't be passed as a function argument** (`custom_samplers` error). Sample it directly in `fragment()`
- **In a canvas_item shader, `COLOR` in `vertex()` includes modulate.** If you overwrite `COLOR` in fragment, pass it through a varying and multiply it back in
- **Code that assumes the default value 0.0 means "not given" breaks on legitimate values (straight right = 0 rad).** Use NAN or a dedicated flag for "not given"
- **Starting `battle_test.tscn` writes the real save file** (via `reset_room()` → `save_game()`). Back it up before automated tests
