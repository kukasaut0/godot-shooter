# FPS Project — Godot 4.6

A first-person shooter prototype built entirely with procedural geometry (no external 3D models).

## Project Setup

- **Engine:** Godot 4.6
- **Renderer:** Forward Plus
- **Physics:** Jolt Physics
- **Main scene:** `world.tscn`

## File Structure

```
fps/
├── project.godot       # Project config (Godot 4.6, Forward Plus, Jolt)
├── world.tscn          # Main scene (arena, player, targets, lights)
├── player.gd           # Player controller + weapon system + HUD
└── target.gd           # Destructible target logic
```

## Scene Structure (world.tscn)

- **World** (Node3D) — root
  - **WorldEnvironment** — procedural sky, ambient light 0.65
  - **DirectionalLight3D** — sun, energy 1.5, shadows on
  - **DirectionalLight3D_Fill** — fill light, energy 0.4, no shadows
  - **Player** (CharacterBody3D) at (0, 1, 30)
    - CapsuleShape3D: radius 0.4, height 1.8
    - Camera3D at (0, 0.7, 0)
    - RayCast3D: 50 units forward
  - **Floor** (StaticBody3D) — 80×80×0.2 green box
  - **Target1–10** (StaticBody3D) — 1×1.5×1 orange boxes, `target.gd` attached
    - Targets 1–2, 5, 8–9 at ground level (y=0.85), spread across arena
    - Targets 3–4, 6–7 elevated on cover blocks (y=2.75)
    - Target10 on top of tower (y=12.75) — bonus hard shot
  - **Wall_Back/Front/Left/Right** — 80×8×0.5 brown boundary walls at y=4
  - **Tower** (StaticBody3D) — 5×12×5 dark gray box at (0, 6, -15), central landmark
  - **Cover_A–G** (StaticBody3D) — 2.5×2×2.5 gray blocks scattered as obstacles/cover

## Scripts

### player.gd
Full player controller. All weapons and HUD are created procedurally in code.

**Movement:**
- Speed: 5.0, jump velocity: 5.0
- Mouse look sensitivity: 0.002, vertical clamp ±90°
- ESC toggles mouse capture

**Weapons (switch with 1/2/3 or Enter to cycle):**
| Weapon      | Ammo | Damage          | Fire rate       |
|-------------|------|-----------------|-----------------|
| Pistol      | 15   | 30              | single          |
| Machine Gun | 60   | 15              | 0.1s auto       |
| Shotgun     | 6    | 14 × 8 pellets  | 0.75s semi-auto |

**Visual effects (all procedural):**
- Muzzle flash: OmniLight3D, intensity 5.0, range 4.0, fades in 0.05s
- Bullet tracer: yellow emissive ImmediateMesh line, fades in 0.1s
- Impact flash: OmniLight3D at hit point, intensity 8.0, fades in 0.05s

**HUD (code-only, no UI scene):**
- Health, ammo, weapon name — bottom-left
- Crosshair "+" — center
- Control hints — top-left

**Hit detection:** RayCast3D from camera, 50 unit range, calls `take_damage()` on hit body.

### target.gd
- Extends StaticBody3D
- Health: 100
- Red flash (0.15s) on hit
- `queue_free()` at 0 HP

## Gameplay

Arena: 80×80 floor enclosed by four 8-unit-tall walls. Ten orange targets spread across the space — 6 at ground level, 4 elevated on gray cover blocks, and a bonus target on top of the central tower (y=12.75). Player spawns at (0, 1, 30) facing the arena. Seven cover blocks provide obstacles and tactical positioning.
