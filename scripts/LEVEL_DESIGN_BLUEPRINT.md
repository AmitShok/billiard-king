# Scratch Bound — Level Design & Editor Setup Blueprint

## 1. Project setup

1. **Project Settings → Autoload** → add `scripts/GameManager.gd` as `GameManager`.
   Every script above calls `GameManager.xxx()` directly, so this step is required
   before anything else works.
2. **Project Settings → Physics → 2D** → set `Default Gravity` to `0`. We don't use
   engine gravity at all — `PlayerCueBall._integrate_forces()` applies a custom
   tilt-table gravity vector (`GameManager.table_gravity_dir`) so each level can
   have a different slant without rotating the whole scene.
3. **Layers** (Project Settings → Layer Names → 2D Physics): define at minimum
   - `cue_ball`
   - `object_balls`
   - `cushions`
   - `pockets`
   - `hazards`

## 2. Scene tree for the Cue Ball (PlayerCueBall.tscn)

```
PlayerCueBall (RigidBody2D)  [script: PlayerCueBall.gd]
├─ CollisionShape2D (CircleShape2D, radius ≈ ball radius)
├─ Sprite2D (cue ball texture)
├─ AimLine (Line2D — dotted texture, width 3-4px)
├─ PowerIndicator (Node2D, optional cue-stick sprite child)
```

RigidBody2D settings:
- `Physics Material Override` → a "Ball" material with **bounce = 0.85–0.95**,
  **friction = 0.05–0.1** (billiard balls are slick).
- `Continuous CD` = **On** (thin cushions + a fast ball otherwise tunnel through).
- `Contact Monitor` = On, `Max Contacts Reported` = 4.
- Collision layer = `cue_ball`, mask = `cushions | object_balls | hazards`.

## 3. Object balls (ObjectBall.tscn)

```
ObjectBall (RigidBody2D) [script: ObjectBall.gd]
├─ CollisionShape2D (CircleShape2D)
├─ Sprite2D (numbered ball texture)
```
Same bounce/friction material as the cue ball. Layer = `object_balls`,
mask = `cushions | cue_ball | object_balls`.

## 4. Table cushions (bumpers)

Cushions are **StaticBody2D**, not RigidBody2D — they never move.

```
Cushion_TopWall (StaticBody2D)
├─ CollisionPolygon2D or CollisionShape2D (matches the rail shape)
├─ Sprite2D / Polygon2D (visual rail)
```

Create one shared `PhysicsMaterial` resource, `res://physics/cushion_rubber.tres`:
- **bounce**: `0.9` (rubber cushions are bouncy — this is what lets a missed shot
  send the ball careening across the whole level, the core punishment loop)
- **friction**: `0.15`
- **absorbent**: `false`

Assign it to every cushion StaticBody2D's `Physics Material Override`.

> Tip: build the table boundary as one long `CollisionPolygon2D` outline with
> gaps left open only at pocket mouths, rather than dozens of separate wall
> nodes — much easier to iterate on the level shape.

## 5. Pockets

```
Pocket_03 (Area2D) [script: Pocket.gd]
├─ CollisionShape2D (CircleShape2D, slightly smaller than the visual hole
│    so near-misses still look plausible)
├─ Sprite2D (dark hole visual)
```
Layer = `pockets`, mask = `cue_ball | object_balls`.
Set `is_goal_pocket = true` only on the final pocket of the level.

Scatter regular (non-goal) pockets along cushion edges and mid-table gaps —
these are your scratch traps. Cluster them near tempting shortcuts so players
are punished for greed, mirroring Jump King's "fake ledges."

## 6. Hazards

**SpinningChalk.tscn**
```
SpinningChalk (Node2D) [script: SpinningChalk.gd]
├─ Sprite2D (rotating chalk cube / triangle rack art)
├─ HitArea (Area2D)
│  └─ CollisionShape2D
```
Layer = `hazards`, mask = `cue_ball`. Place these at chokepoints where a
slightly-off shot should be catastrophic, not everywhere — overuse trains
players to distrust every screen element instead of respecting specific spots.

**FrictionZone.tscn**
```
FrictionZone (Area2D) [script: FrictionZone.gd]
├─ CollisionShape2D (large, marks the rough-felt/magnetic-chalk patch)
├─ ZoneVisual (Polygon2D or Sprite2D, tinted per visual_tint)
```
Layer = `hazards`, mask = `cue_ball | object_balls`. Use sparingly right
before a hard jump — they're most interesting when the player must decide
"do I risk a big shot through this patch, or a careful low-power tap?"

## 7. Checkpoints

```
Checkpoint_02 (Area2D) [script: Checkpoint.gd]
├─ CollisionShape2D (generous size — covers a small landing platform)
├─ Marker2D (exact respawn point, usually the center of a safe felt patch)
├─ Sprite2D (a chalk-mark / flag visual)
```
Layer = a dedicated `checkpoints` layer, mask = `cue_ball`.

**Design philosophy — "checkpoints that don't feel too forgiving":**
- Checkpoints only lock in when the ball **comes to rest** inside the zone
  (see `Checkpoint._try_lock_checkpoint`), not on touch. A ball that merely
  bounces through mid-flight doesn't bank progress — this preserves the
  tension of a single bad shot still costing real distance.
- Space checkpoints **after** the hardest gap of each "section," not before
  it. The player should feel the relief of a checkpoint as a reward for
  clearing a gauntlet, not as a safety net inside it.
- Never place a checkpoint where the very next shot is trivial — leave at
  least one meaningful decision between every checkpoint and the next hazard,
  so re-attempts still require skill, not just a free re-roll.
- Roughly 1 checkpoint per 45–90 seconds of expert-level play is a good
  starting cadence for a Jump-King-style difficulty curve; tighten it in early
  levels and loosen it drastically in "true final" gauntlet sections.

## 8. Wiring signals (GameManager)

In your level root script:
```gdscript
func _ready() -> void:
    GameManager.table_gravity_dir = Vector2(0.2, 1.0).normalized() # this level's tilt
    GameManager.table_gravity_strength = 950.0
    GameManager.total_ball_count_in_level = get_tree().get_nodes_in_group("object_balls").size()
    GameManager.start_run()
    GameManager.level_completed.connect(_on_level_completed)

func _on_level_completed(result: Dictionary) -> void:
    print("Grade: %s  Score: %.1f  Time: %s" % [
        result.grade, result.score, GameManager.format_time(result.time)
    ])
    # show end-of-level UI here
```

## 9. Difficulty pacing across a level

A proven Jump-King-style curve:
1. **Tutorial stretch** — wide table, gentle tilt, no hazards, teaches drag-to-aim.
2. **First hazard gauntlet** — introduce one FrictionZone or SpinningChalk at a
   time, never both together yet.
3. **Object ball puzzle sections** — table narrows, object balls block the only
   route, forcing precision strikes instead of just movement.
4. **Combined gauntlet** — hazards + narrow cushions + pockets close together;
   this is where most "rage-reset to checkpoint" moments happen.
5. **Final approach** — a long, clean, high-bounce cushion corridor leading to
   the goal pocket, so a strong final run feels like a triumphant sprint after
   the punishment of the gauntlet (mirrors Jump King's final tower push).
