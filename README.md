<div align="center">

<img src="assets/textures/game_icon.png" alt="Billiard King icon" width="96">

# BILLIARD KING

### One ball. One tower. No checkpoints.

A pixel-art **precision climbing game** where you are the cue ball.<br>
It takes from *Jump King*, *Fallosophy* and *Ballgame*, and it's chalked up for the pool hall.

![Godot 4.7](https://img.shields.io/badge/Godot-4.7-478CBF?logo=godotengine&logoColor=white)
![GDScript](https://img.shields.io/badge/GDScript-typed-355570)
![Platform](https://img.shields.io/badge/platform-Windows-0078D6)
![Status](https://img.shields.io/badge/status-in%20development-f2c440)

<img src="docs/screenshots/screen_0.png" alt="The Back Room" width="860">

</div>

---

## About

Somewhere above the Back Room, past Lucky's Neon Bar and the Royal Club, there's a gold pocket on a table on the roof. You are a cue ball. You aim, you charge, you strike, and once you're in the air nothing can save a bad shot. Miss, and the climb hands you back to the felt you started from.

## Features

- **Jump King's commitment.** You charge a shot and release it, with no air control. The camera is fixed to one screen at a time and cuts as you cross. There are no checkpoints, and the game saves you wherever the ball comes to rest. Time, strokes and falls are tracked.
- **Billiard shot-making.** You aim in 5° notches and the cue pulls back as the shot charges. **English** shapes the landing: follow keeps you running forward and draw checks you up or rolls you back.
- **Fallosophy's pinball.** Big numbered bumper balls kick you away in their brass collars. Rubber cushions stay lively, and pockets swallow you and drop you far below through the ball return.
- **Ballgame's collection.** Ten lost balls are hidden in the tower and five more are earned by finishing. Each one becomes a ball you can climb as, picked from the **Ball Rack**.
- **Balls that really roll.** Every ball is a pixel-art sphere drawn with spherical UV mapping, so numbers, stripes and the cue ball's red dots roll across the surface.
- **A room that reacts.** Lamps and chandeliers swing on their chains, windows shatter and stay broken, neon shorts out, portraits hang crooked, beads slide along the score wire and chalk gets knocked off ledges. All of it is cosmetic: the ball's path never changes.
- **Three zones and a summit:** the Back Room, Lucky's Neon Bar, the Royal Club (fast felt) and the King's Table under the moon.
- **Proven climbable.** A headless solver fires every shot from every resting spot using the real physics. It checks that the gold pocket can be reached and measures how forgiving each jump is.

## Screenshots

| | |
| --- | --- |
| <img src="docs/screenshots/title.png" width="420"> | <img src="docs/screenshots/screen_4.png" width="420"> |
| *Title* | *Lucky's Neon Bar* |
| <img src="docs/screenshots/screen_6.png" width="420"> | <img src="docs/screenshots/screen_9.png" width="420"> |
| *The Royal Club* | *The King's Table* |
| <img src="docs/screenshots/ball_rack.png" width="420"> | <img src="docs/screenshots/pause.png" width="420"> |
| *Ball Rack* | *Pause and run stats* |
| <img src="docs/screenshots/props_react.png" width="420"> | <img src="docs/screenshots/hint.png" width="420"> |
| *A window gives way* | *Controls hint on the bottom rail* |

## Controls

| Action | Keyboard | Gamepad |
| --- | --- | --- |
| Aim (5° notches, hold to sweep) | A / D or ← / → | D-pad / left stick |
| English: follow / draw | W / S | D-pad / left stick |
| Look up / down (camera peek) | ↑ / ↓ (hold) | Right stick |
| Charge, release to strike | Space, Z or J (hold) | A |
| Pause | Esc or P | Start |

A controls hint appears on the rail of the bottom table while the ball sits there. It hides as you climb and comes back if you fall all the way down, switching to gamepad prompts when you use a pad.

You can only strike from flat felt; slopes make you slide. A full charge fires by itself. If you hold the charge button while you land, the charge starts on touchdown.

## The tower

| Screens | Zone | What's new |
| --- | --- | --- |
| 0–2 | **The Back Room** | Walnut tables under green billiard lamps, slopes, the first pocket, a cushion cup |
| 3–5 | **Lucky's Neon Bar** | Bumper balls, a pocket waiting on an edge, long traverses |
| 6–8 | **The Royal Club** | Fast blue felt, lipped trays, rubber cushion ramps, chandeliers |
| 9 | **The King's Table** | The rooftop and the gold pocket |

## The Ball Rack

| Ball | How to get it |
| --- | --- |
| Cue ball | Always yours |
| 1–10 | Lost somewhere in the tower; touch one to collect it |
| 11 | Finish the climb |
| 12 | Finish in under 400 strokes |
| 13 | Finish in under 30 minutes |
| 14 | Finish with 10 falls or fewer |
| 15 | Finish holding lost balls 1–10 |

## Getting started

1. Install **Godot 4.7** (the standard build; the project uses the Compatibility renderer).
2. Open `project.godot` and press **F5**.

The game renders at 512×288 and scales by whole numbers (1536×864 window by default). Fullscreen, volumes and screen shake are under **Options**.

## Saves & settings

Saves live in `user://billiard_king.cfg` (on Windows, `%APPDATA%\Godot\app_userdata\Billiard King\`). The file holds settings, the run in progress (ball position, aim, spin, time, strokes, falls, zones seen) and the Ball Rack. Tests use separate `test_*.cfg` profiles and never touch your save.

## Project structure

```
assets/        textures (exported PNGs), source/ (.aseprite), fonts/, audio/
levels/        tower.txt: the whole climb as ASCII screens
resources/     tiles.tres (generated), ui_theme.tres
scenes/        ui/title.tscn, world/game.tscn, world/tower.tscn (generated)
scripts/core   ball_sim.gd (physics), collision_world.gd (tiles, bumpers, pockets)
scripts/world  player_ball, ball_visual, cue_stick, tower, game, bumper, pocket, lost_ball
scripts/world/props  reactive decor (swing, window, neon, tilt, rattle, beads, knock)
scripts/ui     title, pause, options, ball rack, ending, ui_kit
scripts/autoload  save_data.gd, sfx.gd
shaders/       ball.gdshader (rolling-ball sphere mapping), vignette.gdshader
tools/         art_*.lua (Aseprite), build_tower.gd, build_sfx.gd, *.ps1 helpers
tests/         gameplay_test, menu_test, props_test, route_solver, capture
docs/          DESIGN.md, VALIDATION.md, screenshots/
```

## Content pipeline

| Task | Command |
| --- | --- |
| Rebuild all pixel art (Aseprite Lua) | `powershell -File tools/build_art.ps1` (add `-Preview` for 4× previews) |
| Rebuild the tower after editing `levels/tower.txt` | `powershell -File tools/godot.ps1 --headless --script tools/build_tower.gd` |
| Re-synthesise the sound effects | `powershell -File tools/godot.ps1 --headless --script tools/build_sfx.gd` |
| Run every test (with the climbability solver) | `powershell -File tools/run_tests.ps1` |
| Retake screenshots | `powershell -File tools/godot.ps1 res://tests/capture.tscn -- --save-profile=capture` |

The legend for the level map is at the top of `tools/build_tower.gd`. After any level edit, run the solver: it fails if the gold pocket can't be reached or if a required stroke has fewer than 5 working shots.

Tuning values and how the rolling ball is rendered are in [docs/DESIGN.md](docs/DESIGN.md).

## Credits

- **Game, code, pixel art and synthesised audio:** Floor 38 Studio. Art is authored in Aseprite via `tools/art_*.lua`, sounds are designed in `tools/build_sfx.gd`.
- **UI blips, win jingle and summit wind:** [Ninja Adventure Asset Pack](https://pixel-boy.itch.io/ninja-adventure-asset-pack) by Pixel-boy & AAA (CC0).
- **Billiard Kit** (the original prototype's sprites, kept in `assets/Billiard Kit/`): Luca Pixel (CC0).
- **Inspired by** *Jump King* (Nexile), *Fallosophy* (Reliable Plumbing Services) and *Ballgame* (Human Computer).

## License

Code and original art © Floor 38 Studio. Third-party assets keep their CC0 licences (see `assets/audio/NINJA_ADVENTURE_LICENSE.txt` and `assets/Billiard Kit/License CC0.txt`).
