# Billiard King design

You are the cue ball, and you have to climb a pool hall tower. The design takes from three games:

- **Jump King**: you charge a shot and release it. There is no air control and no checkpoints. The camera is fixed to one screen at a time and cuts when the ball crosses an edge. A missed shot can drop you several screens. Falls and time are counted. Your position is saved where the ball rests.
- **Fallosophy**: pinball-style vertical climbing. Brass-collared bumper balls kick you away, rubber cushions stay lively, and pockets swallow the ball and drop it far below through the ball return.
- **Ballgame**: you *are* the ball, and you shape your bounces and rolls with english. Strokes are counted like golf. Lost balls are hidden around the course and unlock as skins in the Ball Rack.

## Controls

| Action | Keyboard | Gamepad |
| --- | --- | --- |
| Aim one 5° notch | A / D or Left / Right (hold to sweep) | D-pad / left stick |
| English: follow / draw | W / S or Up / Down | D-pad / left stick |
| Charge, release to strike | Space, Z or J (hold) | A |
| Pause | Esc or P | Start |

You can aim and set spin at any time. You can only strike while the ball sits on felt that is flatter than about 30°, so on slopes you slide just like in Jump King. If you are holding the charge button when the ball lands, the charge starts on touchdown. A full charge fires by itself.

## Tuning

| Parameter | Value |
| --- | --- |
| Physics step | fixed 1/120 s, deterministic |
| Gravity / max fall | 900 / 640 px/s² |
| Shot speed | 150 to 580 px/s, linear over a 0.7 s charge (84 ticks) |
| Full-power height | 187 px (about 11.7 tiles, 0.65 screen) |
| Aim | ±80° from vertical, 5° notches |
| English | ±2 levels, 75 px/s per level added along the shot on first touchdown |
| Felt rolling drag | 420 / 380 / 150 px/s² (Back Room / Neon Bar / Royal Club fast felt) |
| Landing grip | 40% of tangential speed kept on hard landings (>260 px/s), 75% on soft ones |
| Floor bounce | 0.3, dead below 140 px/s |
| Wood rail / rubber cushion bounce | 0.5 / 0.9 |
| Bumper kick | at least 340 px/s along the normal |
| Splat (counted fall) | landing more than 200 px below the takeoff point; 0.4 s control lock |
| Ball radius | 7 px collision, 16 px sprite |

The cue sprite never affects collision. Squash, dust and screen shake are purely cosmetic. Shake is capped at 2 px and can be turned off in Options.

## Rolling-ball rendering

Each ball skin is an *equirectangular* texture (64×32, longitude across and latitude down), drawn in Aseprite by `tools/art_balls.lua`. `shaders/ball.gdshader` treats the 16 px quad as a sphere. For every pixel it rebuilds the sphere normal, rotates it by the inverse of the ball's orientation, and looks up the skin. This is called spherical UV mapping, or sphere mapping. The orientation is a 3D basis. It turns with the rolling speed when the ball is on the felt (`v / r`) and keeps its spin in the air. A cue strike also adds tumble. The view is pitched 24° downward so that rolls along the screen still read as 3D. Lighting is quantised into four bands, with a hard 1 px rim and a pixel glint, so the ball matches the rest of the pixel art. The same shader draws the player, the bumper balls, the lost balls and the Ball Rack.

## Physics architecture

`BallSim` (scripts/core) is plain data and has no nodes. It steps at a fixed 1/120 s against `CollisionWorld`, which holds the terrain cells read from the tower's TileMapLayer plus the bumpers, pockets and lost balls. Collision is circle against convex tile (box or 45° triangle). Seams between neighbouring tiles are masked, so a row of tiles behaves like one surface and the ball never snags. `PlayerBall` wraps `BallSim` with input and juice. The headless route solver drives the exact same `BallSim`, so its verdicts match what a player can actually do.

## The tower

There are 10 screens of 32×18 tiles, written as ASCII in `levels/tower.txt` and baked to `scenes/world/tower.tscn` by `tools/build_tower.gd`. Solid tiles are autotiled from their neighbours.

| Screens | Zone | Twist |
| --- | --- | --- |
| 0–2 | The Back Room | Walnut tables, brick walls, slopes, the first pocket, a cushion cup |
| 3–5 | Lucky's Neon Bar | Bumpers, a pocket guarding a platform edge, longer traverses |
| 6–8 | The Royal Club | Fast blue felt (the ball slides), trays with lips, cushion ramps |
| 9 | The King's Table | Rooftop under the moon; the gold pocket ends the climb |

Lost balls 1–10 are hidden around the tower. Balls 11–15 are earned by finishing: any finish, under 400 strokes, under 30 minutes, 10 falls or fewer, and holding balls 1–10.

## Audio

All foley is synthesised by `tools/build_sfx.gd` using modal synthesis: the cue tip on phenolic, the ball-on-ball clack, walnut rail knocks, rubber cushions, felt landings, the splat, the pocket rattling down the ball return, the bumper bell, the lost-ball chime and the felt roll loop. There are ambience beds for each zone: room tone with fluorescent hum, neon buzz with a jukebox through the wall, and a hushed club with a long-case clock. The summit wind, UI blips and the win jingle come from the CC0 Ninja Adventure pack.
