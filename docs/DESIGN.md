# Billiard King design

You are the cue ball, and you have to climb a pool hall tower. The design takes from three games:

- **Jump King**: you charge a shot and release it. There is no air control and no checkpoints. The camera is fixed to one screen at a time and cuts when the ball crosses an edge. A missed shot can drop you several screens. Falls and time are counted. Your position is saved where the ball rests.
- **Fallosophy**: pinball-style vertical climbing. Brass-collared bumper balls kick you away, rubber cushions stay lively, and pockets swallow the ball and drop it far below through the ball return.
- **Ballgame**: you *are* the ball, and you shape your bounces and rolls with english. Strokes are counted like golf. Lost balls are hidden around the course and unlock as skins in the Ball Rack.

## Controls

| Action | Keyboard | Gamepad |
| --- | --- | --- |
| Aim one 5° notch | A / D or Left / Right (hold to sweep) | D-pad / left stick |
| English: follow / draw | W / S | D-pad / left stick |
| Look up / down | Up / Down arrows (hold) | Right stick |
| Charge, release to strike | Space, Z or J (hold) | A |
| Pause | Esc or P | Start |

Holding Look pans the camera up to 56 px toward the next or previous screen, easing in at 160 px/s and back at 260 px/s. It never peeks below the bottom floor or above the summit. Looking is view only: the screen cut, the ball and its physics are untouched. You can aim and set spin at any time. You can only strike while the ball sits on felt that is flatter than about 30°, so on slopes you slide just like in Jump King. If you are holding the charge button when the ball lands, the charge starts on touchdown. A full charge fires by itself.

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

## Reactive decor

The decor reacts to the ball but never pushes back. Every prop (`scripts/world/props/`) extends `Prop`. Each physics tick, `Game` checks which props on the current screen and its two neighbours overlap the ball and calls `poke(pos, vel)`. Hard landings, splats, bumper hits and big rail knocks call `rumble(pos, strength)` on props within 170 px. Props read the ball's state but never write to it, and they are not in the `CollisionWorld`. So the route solver, the physics and every trajectory are unaffected. `tests/props_test` checks this tick by tick against a bare simulation.

| Prop | Map char | When the ball touches it | When a big impact lands nearby |
| --- | --- | --- | --- |
| Billiard lamp / chandelier | L / H | Damped pendulum swing (chain, body and light cone swing together); clink or crystal tinkle | Sways |
| Window | W | Above 170 px/s it shatters into shards and stays broken for the rest of the climb (saved); slower brushes tick the glass | — |
| Neon sign | P / E | Sparks, zap, a jolt, then 1.5 to 3 s of sputtering darkness | Flickers |
| Portrait / wall clock | F / T | Swings on its nail; portraits settle crooked, clocks chime | Wobbles |
| Cue rack | R | Cues rattle and clatter | Rattles |
| Score wire | Q | Beads it touches slide, clack into their neighbours and bounce off the posts | Beads jiggle |
| Chalk cube / triangle rack | k / r | Knocked flying, tumbles and lands on whatever terrain is below, then stays there | Hops off the ledge |

## Controls hint

`Game` shows the controls as gold-keyed text on the rail of the bottom table. It appears only while the ball is grounded on the tower's bottom floor, fading in after 0.35 s. It fades out as soon as the ball leaves that floor and returns when the ball falls back to it. It switches between keyboard and gamepad prompts based on the last device used.

## Hardcore mode

In Hardcore your ball plays exactly as in Classic mode. The white ball starts 28 px above your ball at the spawn, so a soft straight-up shot knocks it. A fresh climb (no strokes yet) opens a pop-up explaining the goal. It pauses the game and closes on button release, so the press that dismisses it can't start a charge. The difference is a second ball, a plain white one (Ball Rack skin 16), that has **no gravity**. Felt drag of 260 px/s² slows it in every direction until it stops, even in mid-air. Its contacts are all wall-style: wood rails at 0.5, rubber cushions at 0.9, and bumpers kick it. Pockets send it down the ball return; it reappears at the exit at rest, and that counts as a fall. You win only by sinking the **white ball** in the gold pocket. Your own ball rolls straight over it.

The two balls collide as equal masses, with a restitution of 0.92 along the line of centres. A ball hit dead-on at 300 px/s sends the white ball off at about 288 px/s. Both balls step together in two half-ticks and collide after each one, so fast knocks can't pass through each other. Classic mode never gets a partner ball, so its physics are exactly as before.

Each mode keeps its own run in the save file (`[run]` for Classic, `[run_hardcore]` for Hardcore, which also stores the white ball's position) and its own best time. The pause menu has **Re-rack white ball**, which returns it beside the spawn and counts as a fall, for when it ends up somewhere out of reach. **Restart climb**, which asks you to press it twice, is available in both modes. Winning Hardcore adds the white ball to the Ball Rack.

## Music

`tools/build_music.gd` composes and synthesises four mono 22.05 kHz loops. The instruments are an FM Rhodes, an upright bass with finger thump, vibes with motor tremolo, a string section made of detuned partials, and a brush kit with a swung ride. A small comb-filter room reverb has its tail wrapped back onto the start, so each loop is seamless.

| Track | Zone | Feel |
| --- | --- | --- |
| Back Room Blues | Title, The Back Room | 76 BPM, D-minor ii–V–i, Rhodes comping, walking bass, brushes; vibes melody on the second chorus |
| Neon Shuffle | Lucky's Neon Bar | 108 BPM 12-bar blues in F, shuffle kit, vibes riff |
| Royal Waltz | The Royal Club | 3/4 at 132 BPM in C, strings, waltz bass, music-box vibes |
| Moon Over the Table | The King's Table | 60 BPM, floating string pads, sparse Rhodes motif |

Tracks crossfade over 2 s when you change zone, and fade out before the win jingle. The Music volume is under Options.
