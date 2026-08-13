# Flapjack

Flapjack is a 2D, vertically scrolling boat action game built with Godot. The
player steers through scrolling stages, fights enemy formations, collects
pickups, and upgrades weapons.

## Requirements

- [Godot 4.7](https://godotengine.org/) or a compatible Godot 4 release
- The **Compatibility** renderer (already configured in `project.godot`)

The project has no separate package or dependency installation step.

## Getting started

1. Clone the repository.
2. Open Godot and import `project.godot` from the repository root.
3. Allow Godot to finish importing the assets.
4. Press **F6** to run the open scene or **F5** to start from the main menu.

## Controls

| Action | Keyboard | Controller |
| --- | --- | --- |
| Move | W, A, S, D | Left stick |
| Shoot | Space | Right trigger |
| Pause/back | Escape | — |

## Project layout

| Path | Purpose |
| --- | --- |
| `Actors/` | Player, enemies, projectiles, pickups, cameras, and hazards |
| `Assets/` | Textures, fonts, shaders, and cinematic artwork |
| `Data/` | Godot resources defining enemies, weapons, projectiles, and pickups |
| `Levels/` | Menus, reusable level systems, and stage scenes/scripts |
| `Systems/` | Shared combat, environment, event, and debug systems |

Gameplay behaviour is split between actor scripts and small reusable
components. For example, the Player node runs `Actors/Player/player.gd`, while
its child `HealthComponent` and `ShieldComponent` nodes manage their individual
pieces of combat state.

## Pixel-art rules

The game uses a strict two-source-pixel art grid. Every logical art pixel is a
uniform `2x2` block at the `1920x1080` design resolution. The Player texture is
the one exception: it uses `4x4` source blocks because its parent scene renders
at `0.5` scale, resulting in the same `2x2` screen pixels. Main-menu, pause,
and death-screen PNGs also use a deliberate `4x4` UI grid so their pixels stay
readable against the full-resolution gameplay canvas.

- Draw and export sprites on the existing grid; do not resize finished PNGs
  with smooth or fractional scaling.
- Use hard alpha edges for solid sprites and UI. Pixel effects may use only the
  deliberate alpha steps `0`, `85`, `170`, and `255`.
- Use limited palettes without color dithering or antialiasing.
- Display PNGs at their authored size. If a different size is needed, bake
  that final size into the asset and keep the scene scale at `1`.
- Keep authored positions on the `2x2` design grid. Godot's nearest filtering,
  transform snapping, and viewport stretching are configured globally.
- The global `PixelArtRenderer` composites the finished frame back onto that
  grid before the finished viewport is scaled to the current window.
- The desktop window is resizable. The game always renders a complete 16:9
  canvas and adds letterboxing or pillarboxing when the window has another
  shape; it never stretches or crops gameplay to fill the window.

After adding or changing PNG artwork, run the authoring check (requires
[Pillow](https://pillow.readthedocs.io/)):

```bash
python3 tools/normalize_pixel_art.py --check
```

To normalize newly added art onto the canonical grid, run the same command
without `--check`. Review the result in-game before committing it.

## Creating a new stage

The simplest approach is to duplicate an existing stage in the Godot editor.
`Levels/Stage2/stage_2.tscn` contains the core node and Inspector bindings and is
a useful starting point.

1. Create `Levels/StageN/` for the new stage.
2. Duplicate an existing `.tscn` and its stage script into that directory, then
   rename them to `stage_n.tscn` and `stage_n.gd`.
3. Open the new scene and rename its root node to `StageN`.
4. Attach `stage_n.gd` to the root and make the script extend `LevelManager`.
5. Configure the required scene tree and Inspector bindings described below.
6. Add enemy wave timing to the stage script.
7. Run the stage directly with **F6** before connecting it to a menu or the
   previous stage.

### Required scene tree

```text
StageN (Node2D, stage_n.gd)
├── ShakeCamera (Camera2D, shake_camera.gd)
├── EnemyController (instance of Levels/enemy_controller.tscn)
├── ScrollDirector (instance of Actors/Camera/ScrollDirector.tscn)
├── CanvasLayer
│   └── WaterBack (instance of Actors/Camera/water_background.tscn)
├── HUD (instance of Levels/hud.tscn)
├── World (Node2D)
│   └── Player (instance of Actors/Player/player.tscn)
└── SettingsPanel (instance of Levels/settings_panel.tscn)
```

Pickups, hazards, environment layers, and spawners are optional additions. Put
gameplay objects that should move in world space under `World`; keep the HUD and
menus outside it.

### Required Inspector bindings

These references are not discovered automatically and must be assigned in the
Inspector:

| Node | Property | Value |
| --- | --- | --- |
| `StageN` | `scroll_director` | `ScrollDirector` |
| `StageN` | `enemy_controller` | `EnemyController` |
| `EnemyController` | `spawn_parent` | `../World` |
| `EnemyController` | `enemy_types` | One or more `EnemyData` resources |
| `ScrollDirector` | `camera` | `../ShakeCamera` |
| `WaterBack` | `camera` | `../../ShakeCamera` |
| `Player` | `camera` | `../../ShakeCamera` |
| `Player` | `weapons` | The starting `WeaponData` resources |

Also add `ShakeCamera` to the `shake_camera` group if the stage should support
screen shake.

The Player camera assignment is mandatory. Movement clamps the boat to the
active camera viewport, so a missing camera reference stops the Player script
during physics processing.

The root of `Actors/Player/player.tscn` must use
`Actors/Player/player.gd`. `HealthComponent.gd` and `ShieldComponent.gd` belong
only on their corresponding child nodes; attaching either component script to
the Player root disables movement and weapons.

### Stage script example

Stage scripts extend `LevelManager`, use `ScrollDirector` to move the camera,
and ask `EnemyController` to create formations from `EnemyData` resources:

```gdscript
extends LevelManager


func _ready() -> void:
	assert(scroll_director != null, "Stage needs a ScrollDirector")
	assert(enemy_controller != null, "Stage needs an EnemyController")
	assert(not enemy_controller.enemy_types.is_empty(), "Stage needs an enemy type")

	var basic_enemy := enemy_controller.enemy_types[0]
	var first_wave: Array[EnemyData] = [
		basic_enemy,
		basic_enemy,
		basic_enemy,
	]

	# Stages currently progress upward into negative Y coordinates.
	scroll_director.move_to(Vector2(0, -2400))
	enemy_controller.spawn_pack(
		first_wave,
		Vector2(0, -600),
		EnemyController.Formation.V_SHAPE
	)

	await wait_until(func() -> bool:
		return scroll_director.has_reached(Vector2(0, -600))
	)

	enemy_controller.spawn_pack(
		first_wave,
		Vector2(0, -1200),
		EnemyController.Formation.LINE
	)
```

Available formations are `LINE`, `V_SHAPE`, `GRID`, and `CIRCLE`. Formation
spacing and radius are configured on `EnemyController`.

### Connecting the stage

To make the main menu launch the new stage, update the scene path in
`Levels/main_menu.gd`:

```gdscript
get_tree().change_scene_to_file("res://Levels/StageN/stage_n.tscn")
```

If the stage should follow another stage instead, call the same method from the
previous stage's completion flow.

## Common stage problems

- **The boat does not move:** verify that the Player root uses `player.gd` and
  that its `camera` property points to `ShakeCamera`.
- **Enemies do not appear:** assign at least one `EnemyData`, set
  `spawn_parent` to `World`, and ensure each enemy resource has a valid scene.
- **The camera does not scroll:** assign `ScrollDirector.camera`, set a positive
  `scroll_speed`, and call `move_to()` with a destination.
- **The water does not follow the camera:** assign `WaterBack.camera` and check
  that its material uses the water shader.
- **Screen shake does nothing:** add the active camera to the `shake_camera`
  group and give `max_offset` a non-zero value.
