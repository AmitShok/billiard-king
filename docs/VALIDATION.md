# Validation: 2 November 2026

Run with Godot 4.7 stable (official) on Windows. Rendered checks used the Compatibility renderer on an NVIDIA RTX 5060 Laptop GPU. All suites run with `powershell -File tools/run_tests.ps1`. Every test uses an isolated save profile, so the player's save file is never touched.

## Gameplay suite: 37 / 37 passed

`tests/gameplay_test.tscn` exercises the physics with small hand-built worlds, then plays through the real game scene using synthetic input.

- **Resting and striking:** the ball settles on flat felt and can be struck from there.
- **Shot strength:** a full-power jump reaches the designed 187 px, and charge maps linearly onto speed.
- **Rolling:** the ball rolls across tile seams without hopping (variation under 0.6 px), and the felt stops a 400 px/s roll at the designed distance.
- **Bounces:** wood rails rebound at about 50%, rubber cushions at about 90%.
- **Slopes:** the ball rolls downhill and cannot be struck from a 45° slope.
- **English:** follow lands beyond plain, and plain lands beyond draw.
- **Falls:** a long drop registers as a splat; a short drop is a normal landing.
- **Objects:** bumpers kick at 340 px/s or more. Pockets swallow the ball and the ball return releases it at the exit. Lost balls are collected exactly once.
- **Determinism:** identical shots give identical results.
- **Real-input checks:** a tap moves the aim one notch, spin input works, holding charges, a full charge auto-fires, releasing fires, there is no air control, and the ball lands and rests.
- **Camera, saving and pause:** the camera cuts both ways between screens, resting saves the position, and pause and resume work.
- **Save data:** the run, rack and skin survive save and load. A locked skin falls back to the cue ball. Finishing a climb clears the run and records it.

## Menus and ending: 14 / 14 passed

`tests/menu_test.tscn` covers the following:

- **Title:** the menu shows no Continue without a run, has its expected buttons, and gives the first button focus.
- **Ball Rack:** locked balls cannot be picked, found balls can be, and the choice persists.
- **Options:** screen shake toggles, and the settings persist.
- **Winning:** rolling into the gold pocket wins, and all five awards are granted when their conditions are met. The run is then closed and recorded, the ending card appears, and controls lock.

## Climbability: route solver passed

`tests/route_solver.gd` uses the real `BallSim`. From every resting spot reachable from the spawn, it fires 17 aim notches × 14 charge levels (238 shots, english off). It follows each shot until the ball rests, pockets or wins.

- 494 resting spots explored; every screen reached; the gold pocket reached.
- All 10 lost balls can be reached.
- On the most forgiving route, the hardest required stroke on every screen still has at least 5 of the 238 coarse shots working (s0 9, s1 9, s2 5, s3 5, s4 5, s5 5, s6 7, s7 5, s8 5, s9 5). At full resolution (5° notches × every charge tick) that is roughly 30 or more aim/power combinations per jump. That is firm but not pixel-perfect. The solver fails if any required stroke drops below 5.

## Rendered review

`tests/capture.tscn` captured all ten screens, a live charged shot with its flight, the title, the pause menu and the Ball Rack (`docs/screenshots/`). I checked these visually for the following:

- The ball reads as a lit 3D sphere and its dots roll.
- The cue draws at any angle and pulls back with the charge.
- Pockets sit in the felt with their nets.
- Lamp light cones are warm, and neon and chandeliers glow.
- The menus are centred and themed.
- Locked rack balls render as silhouettes.

## Import

A fresh import (with `.godot/imported` removed) produces no errors or script warnings.

## Not verified

- **Feel:** human playtesting is still needed for charge timing, how punishing the falls are, and sound balance. The synthetic input confirms the controls work, not that they feel right.
- **Audio playback:** headless runs check that sounds dispatch, not how they sound.
- **Gamepad:** gamepad bindings are registered but were not tested with a physical controller.

## Reactive decor and controls hint: 2 November 2026

`tests/props_test.tscn`: 27 / 27 passed.

- The tower contains all seven prop kinds.
- **No effect on the ball.** For flights through a window, a hanging lamp and a score wire, the ball overlaps the prop and its position and velocity match a bare `BallSim` (same terrain, no props) exactly on every tick.
- **Windows:** a slow brush leaves the window intact and a fast ball smashes it. The break is saved, survives a reload, and a new climb restores whole windows.
- **Lamps:** they swing when clipped and settle back.
- **Other props:** neon shorts out, hung pictures swing, beads slide and keep their order on the wire, and chalk is knocked flying, then lands and rests on solid terrain.
- **Controls hint:** it shows on the bottom floor and hides once the ball climbs. It stays hidden while the ball falls and returns when the ball lands back on the bottom floor. It switches between gamepad and keyboard prompts.

Regression: gameplay 37/37, menus 14/14, route solver PASS with identical results (494 spots, hardest stroke per screen unchanged). Rendered captures: `hint.png` and `props_react.png`. Every test suite now runs with a frame limit (`--quit-after`), so a script error can't hang the runner.

## Camera look: 2 November 2026

The gameplay suite is now 43 / 43. The up arrow is bound to look, not spin. Holding look pans the camera a full 56 px up or down and it eases back to rest on release. Looking leaves the ball's position, spin and screen unchanged. Looking below the bottom floor is blocked.

## Hardcore mode and music: 3 November 2026

`tests/hardcore_test.tscn` passed 35 of 35 checks.

**White ball physics**
- It hangs in mid-air with no gravity, and felt drag stops it at the predicted distance.
- It banks off rails.
- A ball-on-ball knock conserves momentum, transfers the expected 96%, separates the balls, and isn't counted twice.
- Your ball rolls over the gold pocket while the white ball sinks it.
- The ball return releases it at rest.

**Hardcore game**
- A fresh Hardcore run starts without touching the Classic run in progress.
- The white ball is placed beside the spawn and stays put.
- Your normal ball is partnered to it, and a real strike knocks it so it travels and then stops.
- The edge arrow counts screens, and Re-rack works and counts a fall.
- The white ball's position is saved, and sinking it in the gold pocket wins the run, unlocks the white ball and records the win separately.
- Classic games have no white ball.

**Music**
- The title and the Back Room play the Back Room theme, and the Neon Bar and the summit switch tracks.
- All four tracks exist and are 30 seconds or longer.
- Options has a Music volume, and it persists.

**Not proven:** whether Hardcore can be completed. The route solver covers only the single-ball Classic climb. A two-ball search (where you must stand to reach the floating ball, and every knock) is a much larger problem. Re-rack is there as the escape hatch, and Hardcore needs human playtesting for difficulty.

**Update, 4 November 2026:** the Hardcore suite is now 40 / 40. New checks: the white ball starts just above your ball; the goal pop-up opens on a fresh climb, closes on release without starting a charge, and is skipped when continuing; a soft straight-up shot knocks the white ball upward.

**Update:** each mode now has its own short goal pop-up (`GoalIntro`). The Hardcore suite is 44 / 44, checking that Classic opens its own pop-up (your ball, "reach the gold pocket at the top", no white ball) and that the Hardcore one is short and shows the white ball. Gameplay 43, menus 14, props 27. Captures: `classic_intro.png` and `hardcore_intro.png`.

## Level 2, moving things and the level select

`tests/level2_test.tscn`: 49 / 49 passed. It covers the following:

- **Carriages:** the ball rides them sideways and up and down without dropping, keeps its spot on the deck, and can be struck from them. Shots inherit their momentum, and they are solid from the side and below. Moving worlds replay identically.
- **Traps:** spinner arms and spike balls catch the ball, fling it once at the expected speed, and do nothing outside their reach. A trap knocks you off a carriage. In the real level a trap flings the ball and flashes, without counting as a fall.
- **Level 2:** at least twice as long as level 1, with sideways and vertical carriages, spinners and spike rails. Level 1 has no movers.
- **Saves:** every mode + level keeps its own run. The world clock is saved and moving things resume from it. Wins are recorded per level, and level 1's awards aren't handed out on level 2.
- **Hardcore:** level 2 plays with the white ball, and sinking it wins.
- **Level select:** both modes list both levels with a numbered ball each, and starting one sets the mode and level.

**Route solver.** Level 2 passed: 854 resting spots explored in about 22 minutes, a 79-stroke route to the gold pocket, and the hardest required stroke has 5 of 238 working shots at its best moment (s0=9, s1=5, s2=5, s3=5, s4=5, s5=5, s6=13, s7=5, s8=6, s9=9, s10=5, s11=5, s12=5, s13=7, s14=5, s15=7, s16=5, s17=5, s18=6, s19=11). Level 1 also passed, with the same per-screen numbers as before.

**Regression:** gameplay 43, menus 14, props 27, Hardcore and music 44.

**Not verified:** how the timing feels, whether Hardcore can be completed on either level (the solver covers only your ball), and new sounds by ear. All of these need playtesting.

## Level 2 lock, lost balls and the rainbow ball

The level 2 suite is now 64 / 64. New checks:

- **Lock:** level 2 is locked on a fresh game, and the level select shows it unpressable with how to open it. Finishing level 1 in either mode opens it. A run already under way stays playable.
- **Lost balls:** ten new ones (17–26), none buried in terrain.
- **Rainbow ball:** Normal mode doesn't earn it, and winning level 2 on Hardcore does. It turns on its shader and glow, the glow cycles through colours, and other balls don't glow.
- **Ball Rack:** 28 slots, with the new balls named.

Route solver, run by stretches on level 2: all five pass, and all ten new lost balls are reachable by the real physics (17, then 18–19, 20–22, 22–24, 24–26). Physics and terrain did not change, so the earlier full-level proofs still stand and were not re-run.

Regression: gameplay 43, menus 19, props 27, Hardcore and music 44. Rendered check: `ball_rack.png`, `level_select_locked.png`.

Not verified: how the rainbow ball looks in motion over a full climb, and whether Hardcore on level 2 (the only way to earn it) can be finished, which needs playtesting.

## Levels 3 and 4, low gravity, wind, lost-ball spread

`tests/conditions_test.tscn`: 59 / 59 passed. It covers the following:

- **Low gravity:** a full shot rises about 2.2 times as high at 0.45 gravity. Gravity is set per screen, and a ball falls slowly there. Low gravity is on exactly the moon and space screens.
- **Wind:** a stretch's wind only ever blows one way, peaks at the set strength, drops to dead calm between gusts and blows for its `on` time each cycle. Wind only exists on windy screens. A gust pushes a ball in the air, the same shot in the lull flies exactly as in still air, an updraft carries a jump higher, and a ball resting on the felt ignores it. Hardcore's white ball stays put in a 600 px/s² gale from each of the four directions. Windy shots replay identically.
- **Themes:** level 3 starts in the Observatory and passes the Station, level 4 starts on the Fire Escape and rests in the Bell Tower, and neither level's map uses any of levels 1 and 2's decor. Every level-4 windy stretch blows one way with an on and off time, and all four directions are used.
- **Lost balls:** each of the four levels hides exactly 6, spread over at least half its height and none buried. There are 24 different balls, matching the Ball Rack's list.
- **Locks:** a fresh game opens only level 1, and each finish (in either mode) opens only the next level.
- **In the game:** the pop-ups warn about low gravity and gusts, the observatory has normal gravity, the rooftop gust is an updraft, and the moon and rooftops have their own music. Bumped asteroids drift and struck satellites spin up. The weather layer, wind socks and vanes follow the gust, and bunting reacts to a knock. Hardcore plays the new levels.

**Route solver, whole level, real gravity and wind:**

| Level | Spots explored | Route | Hardest stroke | Lost balls reachable |
| --- | --- | --- | --- | --- |
| 1 | 493 | 46 strokes | 5 of 238 | all 6 |
| 3 | 574 | 40 strokes | 6 of 238 | all 6 |
| 4 | 642 | 56 strokes | 6 of 238 | all 6 |

Level 2's terrain and physics did not change, so its earlier proof stands and was not re-run. Its six balls now sit at positions from the earlier ten, all of which the solver reached.

**Regression:** gameplay 43, menus 19, props 27, Hardcore and music 47, level 2 64.

**Web export, sound:** superseded, see "Web audio on itch.io" below. Those checks ran in the app's built-in browser, which plays audio without a click, and measured inside the mix rather than at the speakers, so they missed the real problem.

**Not verified:** the feel of low gravity and wind, the new music and ambience by ear, whether Hardcore can be completed on any level (the solver covers only your ball), and how the props look in motion beyond captures. All of these need playtesting.

## Unlock and reset

The menus suite is now 35 / 35. New checks:

- **Test: unlock everything:** shows in debug builds, opens every level and fills the Ball Rack including the rainbow ball. It keeps your run and records, and survives a restart.
- **Reset all progress:** the real button's first press only asks, and moving away cancels. The second press wipes the rack, skin, records and every mode + level run, and locks the levels again. Settings are kept, the game unpauses and returns to the title, and the wipe survives a restart.
- **Options panel:** it still fits on screen with the new buttons.

**Not verified:** that a release export hides the unlock button. It relies on `OS.is_debug_build()`, and this project has no release export to test against.

## Themed levels 3 and 4, one-way wind: 9 November 2026

Levels 3 and 4 no longer reuse the Back Room, Neon Bar or Royal Club. Level 3 now starts in the Observatory and passes the Station (Launch Deck). Level 4 starts on the Fire Escape and rests in the Bell Tower. Every windy stretch of level 4 blows one way (R, L, U or D) for about 3 s, then drops to calm for about 3 s. The white ball ignores wind. Some level 4 ledges were widened or given lips at their downwind end, so a gust carries you onto the ledge instead of off it.

The route solver now tries six moments spread across each gust cycle in wind, the way a player waits for the rhythm.

| Level | Spots explored | Route | Hardest stroke | Lost balls reachable |
| --- | --- | --- | --- | --- |
| 3 | 575 | 43 strokes | 6 of 238 | all 6 |
| 4 | 686 | 56 strokes | 5 of 238 | all 6 |

The condition tests (67) cover one-way wind, the lull, updrafts, the white ball in a gale from every direction, the new zones, and that no bar or club decor appears in levels 3 or 4.

**Web export:** The export now ships a `default_bus_layout.tres` and leaves out `tests/`, `tools/`, `docs/` and `builds/`. `builds/` is git-ignored.

## Camera glide and Training mode: 9 November 2026

`tests/training_test.tscn`: 38 / 38 passed.

- **Menus:** the title has Training. Its level list offers Practise only on opened levels; with only level 1 open, levels 2 to 4 stay Locked. There is no Continue or New.
- **Pop-up and hints:** the training pop-up explains flags and that nothing counts. The top line names C, R and X and counts the flags.
- **No lost balls:** none are visible and none are in the physics.
- **Flags:** you can't plant one mid-air. C (sent as a real input action) plants on the resting spot, inside the tower's decor and outside the physics. The flag pops to full height. A second flag lights while the first fades, and planting on a flag doesn't stack another. A gust turns the pennant downwind, and a passing ball makes it flutter.
- **Return and remove:** R returns to the newest flag and the camera follows. X removes it, it folds away, and R then goes to the flag before. With no flags, R goes to the start.
- **Pause:** shows Training and the flag count, and offers Quit, not Save and quit.
- **Nothing counts:** no training section is ever written to the save. A training win says it's practice, opens no level, records no win, gives no balls and leaves the Normal run untouched.

**Camera** (gameplay suite, now 46): crossing into screen 1 sets the target. The camera is partway there 3 ticks later, never doubles back, and settles exactly on the screen.

**Regression:** gameplay 46, menus 35, props 27, Hardcore and music 51, conditions 67, level 2 64, training 38. All pass.

**Rendered:** `training.png` (two flags, newest lit), `training_wind.png` and `title.png` (six-button menu fits).

**Not verified:** how the glide and the flags feel in real play at full frame rate, gamepad buttons for flags on real hardware, and Training on the web build. These need playtesting.

## Web audio on itch.io: 9 November 2026

**Problem:** the user's itch.io build was silent in Chrome: no music, no ambience, no effects.

**Reproduced** in the user's real Chrome (Claude in Chrome) on the build itch serves. An analyser on everything connected to the speakers (`AudioDestinationNode`) read:
- before any click: audio `suspended` (Chrome's autoplay block, as expected);
- after clicking into the game: audio `running`, but **peak 0**, idle and during menu blips;
- a test tone injected into the same context: 0.05, so the measurement works.

The game used Godot's default web **Sample** playback (`AudioBufferSourceNode`s), and every gain was set to 1 and then to 0 a second later. The built-in browser had hidden this: it plays audio without a click, and earlier checks there tapped nodes inside the mix, not the output.

**Fix:** `audio/general/default_playback_type.web=0` (Stream). Web audio now goes through Godot's own mixer in an AudioWorklet, like desktop.

**Verified** in the user's Chrome on a release export with the fix: no sample sources start, audio is suspended until the first click, and then the output peaks at 0.45 idle on the title (music and ambience) and 0.45 in level 1. **Not checked:** Firefox, Safari, mobile, and the re-uploaded itch.io page itself (it needs the user's upload).

## Animated rain: 9 November 2026

The rain painted into `bg_storm` and `bg_fire_escape` is gone, and `RainLayer` animates it instead. The level 4 tests (conditions suite, now 74) check that:
- it rains on the rooftops and on the fire escape, but not in the bell tower;
- the drops actually move;
- an updraft slows them, a crosswind slants them and a downdraft speeds them up.

The rendered fire escape and rooftop screens show the rain behind the ledges. All suites pass: gameplay 46, menus 35, props 27, Hardcore 51, conditions 74, level 2 64, training 38.

## Touch controls: 13 November 2026

**Touch suite (57 checks, `tests/touch_test.gd`).** Touches are pushed into the root viewport the way a phone delivers them. The suite checks:
- On a computer (no touchscreen): no buttons, the keyboard hint stays, and a mouse click where a button would be presses nothing.
- Turned on: one button per action; holding the arrow turns the aim; a spin tap adds one spin; the eye peeks the camera.
- Holding the cue button charges, and letting go strikes. Two fingers press two buttons at once.
- Pause opens the menu, the buttons hide and let go under it, then come back. They also hide while the ending is up.
- Layout: every button is on screen and no two touch areas overlap. A button fades while the ball is behind it.
- Auto mode: a touch shows the buttons, a key press hides them and releases what they held, and the hint text follows. Off ignores touches, and On shows them at once.
- Training: the flag buttons plant, return and remove a flag, and a tap dismisses the goal pop-up.
- Options cycles Auto, On and Off, and the setting is saved.

**In the browser** (release web export, built-in browser): emulated as an Android phone at 740×360 with touch, driven by real `TouchEvent`s.
- The game filled the height at 2.5×.
- Taps opened Normal mode and continued a run.
- The buttons showed with the touch hint, and the strike and look buttons faded over the ball.
- Holding the arrow, then the cue button, fired the ball up and to the left.
- The pause button opened the pause menu with the buttons hidden, and Options showed "Touch controls: Auto" with room to spare.
- At 360×740 portrait, "Turn your device sideways" appeared.
- In the same browser back at desktop size (no touch points), there were no buttons in the game.

**All suites pass:** gameplay 46, menus 35, props 27, Hardcore 51, conditions 74, level 2 64, training 38, touch 57.

**Not checked:** a real phone or tablet (iOS Safari especially), and a touchscreen laptop.
