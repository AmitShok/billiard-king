# Vertical Billiard design

You are the cue ball, and you have to climb a pool hall tower. The design takes from three games:

- **Jump King**: you charge a shot and release it. There is no air control and no checkpoints. The camera shows one screen at a time; where Jump King cuts, this camera glides to the next screen in about a third of a second so the ball is never lost (see Camera). A missed shot can drop you several screens. Falls and time are counted. Your position is saved where the ball rests.
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
| Training: plant flag / back to flag / remove flag | C / R / X | Y / X / LB |

Holding Look pans the camera up to 56 px toward the next or previous screen, easing in at 160 px/s and back at 260 px/s. It never peeks below the bottom floor or above the summit. Looking is view only: the screen change, the ball and its physics are untouched. You can aim and set spin at any time. You can only strike while the ball sits on felt that is flatter than about 30°, so on slopes you slide just like in Jump King. If you are holding the charge button when the ball lands, the charge starts on touchdown. A full charge fires by itself.

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

In Hardcore your ball plays exactly as in Classic mode. The white ball starts 28 px above your ball at the spawn, so a soft straight-up shot knocks it. Every new climb (no strokes yet) opens a short goal pop-up for its mode. Classic shows "The climb" with your ball and "Reach the gold pocket at the top of the tower". Hardcore shows the white ball and "Push the white ball up the tower into the gold pocket at the top". The pop-up pauses the game and closes on button release, so the press that dismisses it can't start a charge. Continuing a climb skips it. The difference is a second ball, a plain white one (Ball Rack skin 16), that has **no gravity**. Felt drag of 260 px/s² slows it in every direction until it stops, even in mid-air. Its contacts are all wall-style: wood rails at 0.5, rubber cushions at 0.9, and bumpers kick it. Pockets send it down the ball return; it reappears at the exit at rest, and that counts as a fall. You win only by sinking the **white ball** in the gold pocket. Your own ball rolls straight over it.

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

## Levels and the level select

The title's **Normal mode** and **Hardcore mode** buttons each open a small felt panel with one numbered ball per level. A level shows **Start**, or **Continue** and **New** (press New twice to confirm), and the focused level's best result. Every mode + level has its own run in the save file (`[run]`, `[run_hardcore]`, `[run_l2]`, `[run_hardcore_l2]`), including where the moving things were.

Levels are ASCII files baked by `tools/build_tower.gd`. Moving things are `@` lines under a screen header (syntax at the top of that script).

**Unlocking.** Each level shows as locked until the one before it has been finished in either mode, and finishing in one mode opens it in both. A run already under way stays playable, so nobody is locked out of their own save.

## The Long Rack (level 2)

20 screens, twice The Tower, with 31 moving things:

| Screens | Zone | Twist |
| --- | --- | --- |
| 0–6 | The Cellar | Learn carriages, then the first spinning arms and spike rail |
| 7–13 | The Jukebox Floor | Spike rails, spinners, bumpers and pockets on the route |
| 14–18 | The Grand Salon | Fast felt, trays on carriages' paths, spinners over long shots |
| 19 | The Rooftop Final | A last carriage, a spinner, and the gold pocket |

**Carriages** sweep along their rail with eased ends, as a pure function of the world clock. They are solid on every side. Landing on one carries the ball: while riding, the ball's velocity is relative to the deck, and leaving or being struck converts it back. Shots keep the carriage's momentum, so a shot from a rising elevator goes higher.

**Traps** fling the ball at 430 px/s away from the contact point (plus half the trap's own speed, capped at 620). They don't scratch or reset you; the fall is the penalty. Hazard colours (hot red, warning yellow) are reserved for traps, which also pulse a red glow and draw in front of everything. Spinners show their reach with a dotted red ring; spike balls run on a dotted red rail.

The clock only ticks with the physics, so pausing freezes everything, and it is saved with the run so moving things resume where they were.

## Route solver with moving things

Moving things are deterministic, so the solver replays them exactly. A spot on a carriage counts as one spot wherever the carriage is. Near moving things, each spot's shot sweep is repeated at several moments (a player can wait for the right one), and a move's score is its working shots at the best moment. In wind it tries six moments spread over one gust and calm, starting as the gust begins, the way a player watches the rhythm before shooting. To keep this tractable it writes off shots that fall over 300 px and doesn't explore from spots more than 48 px below the current one; that can only hide routes, never invent one. `--from-screen` and `--to-screen` check a stretch while tuning.

## Lost balls and the rainbow ball

Every level hides exactly six lost balls, spread through its whole height: 24 in all (`BallRack.LOST_IN`). Balls above 15 are placed with `@ lost x y number` lines, and most are patterns painted on the sphere in `tools/art_balls.lua`. They can be collected in either mode, and either ball can pick them up.

Winning The Long Rack on Hardcore earns **the rainbow ball** (skin 27). Its skin is greyscale; `shaders/ball.gdshader` tints it with a hue that runs around the ball and drifts over time, so colours shimmer as it rolls. `BallVisual` adds a soft glow behind it that cycles through the colours and pulses. The Ball Rack has 32 slots.

## Low gravity

`@ gravity scale` makes a whole screen low-gravity: 0.45 on the moon (zone 4) and 0.35 in open space (zone 6). Gravity is looked up by the screen the ball is on, so it changes the moment you cross a screen edge. Top speed when falling scales with its square root. Those screens always use the moon or space backdrops, and specks of chalk dust hang in the air.

## Wind

`@ wind dir strength on off phase` gives a screen gusts that always blow the same way (`R`, `L`, `U` or `D`), as in Jump King, where each windy stretch has its own direction. The gust blows for `on` seconds, swells in and out over 0.35 s, then drops to dead calm for `off` seconds. It is a pure function of the world clock like everything else that moves, so the player can watch the rhythm and time a shot into the gust or into the calm. It accelerates your ball only while it is in the air. Hardcore's white ball never feels it. Strengths run 200 to 320 px/s² against gravity's 900, enough that a full shot lands well off where it would in still air.

The Gale changes direction stretch by stretch: a tailwind right then a headwind left on the fire escape, an updraft that carries jumps higher on the first rooftops, a downdraft that cuts them short, and so on, with all four directions used. The Bell Tower in the middle is calm.

The wind is visible: pale streaks race along it, and `feel_wind` tells every prop on screen. Socks stream out, bunting ripples, vanes turn, hanging lamps sway, and a gust sound follows its strength.

## New zones

| Zone | Backdrop | Tile palette | Music |
| --- | --- | --- | --- |
| 4 Moon | `bg_moon`: stars, a green-felt world, cratered ground | Silver felt, titanium rails, pitted rock | Felt of Tranquility |
| 5 Storm | `bg_storm`: cloud bands, rain, rooftops and water towers | Teal felt, weathered rails, slate shingles | Rooftop Gale |
| 6 Space | `bg_space`: nebula, stars, a ringed nine-ball planet | Same as the moon | Felt of Tranquility |
| 7 Observatory | `bg_observatory`: a dome with gold ribs, a slit open to the stars, constellations | Midnight-blue felt, bronze rails, riveted navy plate | Felt of Tranquility |
| 8 Station | `bg_station`: steel hull panels, portholes onto stars and a green planet | Teal felt on white hull panels | Felt of Tranquility |
| 9 Fire Escape | `bg_fire_escape`: a brick block at night, lit windows, iron stairs, rain | Moss felt on rusted iron grating | Rooftop Gale |
| 10 Bell Tower | `bg_bell_tower`: timber frame, louvred openings, a great bell | Plum felt on old timber | Rooftop Gale |

Levels 3 and 4 don't reuse any of levels 1 and 2's rooms or decor: The Moon Shot starts in the Observatory and refuels on the Launch Deck (Station), The Gale starts on the Fire Escape and rests in the Bell Tower.

New responsive decor: **A** asteroid, **G** satellite, **N** moon flag (`SpaceProp`); **V** wind sock, **U** bunting, **Y** weather vane (`WindProp`); **I** lantern and **h** bell (`SwingProp`, the bell rings when hit); **M** star chart and **X** porthole (`TiltProp`); **g** flower pot (`KnockProp`); **D** telescope that scans the sky, **J** orrery with orbiting planets, **Z** console with blinking lights, **j** turning gear (`GadgetProp`).

## Camera

Each screen is still a fixed frame, but crossing an edge glides the camera there instead of cutting. The glide takes 0.32 s with a cubic ease-out: it starts fast so the new screen is in view almost at once, then settles exactly on the frame. A fall across several screens takes a little longer, up to 0.6 s. Loading a run or restarting snaps straight to the right screen. The glide runs on physics ticks with physics interpolation, so it stays smooth at any frame rate. Look (peek) and screen shake are camera offsets on top of it and are unchanged.

## Training mode

A practice mode modelled on Geometry Dash's. There you press Z to place a checkpoint and X to remove the last one, a crash respawns you at the newest checkpoint, collectibles are only decoration, and practice progress never counts. Vertical Billiard has no deaths, only falls, so returning is a key instead of automatic:

| Key | Pad | Does |
| --- | --- | --- |
| C | Y | Plants a flag where the ball rests. Not mid-air, not on a carriage. Planting on an existing flag (within 12 px) makes it the newest again. |
| R | X | Puts the ball back on the newest flag, or the start if there are none. The camera glides there. |
| X | LB | Pulls up the newest flag, so R falls back to the one before. |

Z is already a strike key here, so C is the plant key.

- **Opening it:** the title's **Training** button opens the level list, which shows only levels already opened in Normal or Hardcore. Each has a single **Practise** button that always starts fresh.
- **Nothing counts:** the `training` mode never writes a run section to the save. Winning shows a "Training run complete" card with the run's numbers but changes no records, balls or unlocks. There are no lost balls: every one is hidden and left out of the physics.
- **The flag** (`CheckpointFlag`, a `Prop`) is a brass pole with a cue-ball finial and a felt swallowtail pennant (`tools/art_checkpoint.lua`). The pennant is drawn one pixel column at a time, each shifted by a travelling sine wave that grows toward the fly end. Wind speeds the wave up and flattens the sag, flips the pennant downwind, and lifts it in an updraft. A ball rolling past or a heavy landing makes it flutter. It pops up with green sparks when planted, folds down when removed, and waves when you return to it. Only the newest flag is lit green and pulsing; older ones fade but stay standing to mark your route. Like all props it never touches the physics.
- **Hints:** the training keys stay on the top line of the screen with the flag count. The normal controls line shows whenever the ball rests anywhere, not only on the bottom floor.

## Rain

The Rooftops storm and the Fire Escape used to have rain streaks painted into their backdrops, which looked frozen. The backdrops are now dry, and `RainLayer` draws about 170 falling drops just above the backdrop and behind the ledges and decor. It draws only on screens whose zone is rainy, so the rain stops cleanly at a zone edge even while the camera glides. Drops fall at up to 380 px/s, slanting one pixel across for every three down, like the old painted streaks, and nearer drops are lighter and faster. The gust on screen bends them: a crosswind slants them hard, an updraft slows them almost to a hang, and a downdraft drives them down. The Bell Tower is indoors and dry.
