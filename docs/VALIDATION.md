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
