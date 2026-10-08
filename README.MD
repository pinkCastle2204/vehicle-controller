# Vehicle Controller

A small **Godot 3D vehicle-physics prototype** built around a raycast-suspension car, a chase camera, and a simple test course.

> [!NOTE]
> This repository is a playable prototype, not a finished racing game. The scene is a physics test area; there is no menu, race loop, or in-game controls screen.

## 🚗 Quick start

1. Install **Godot 4.7** (the project configuration declares Godot `4.7` and the **Forward Plus** renderer).
2. Open the repository as a project in Godot and allow the editor to import its assets.
3. Check the [debug-draw add-on setup](docs/PROJECT_GUIDE.md#debug-draw-add-on) before running. The car script uses `DebugDraw3D`, and the bundled add-on is not currently in the path configured by the project.
4. Run the project with **F5** (project main scene) or **F6** (the currently open scene). The configured main scene is `scenes/test_world.tscn`.
5. Drive with the [keyboard controls](docs/CONTROLS.md#keyboard-and-mouse) or a compatible gamepad.

📖 **Documentation**

| Guide | What's inside |
|---|---|
| [Controls](docs/CONTROLS.md) | Keyboard, mouse, and gamepad bindings; camera behavior |
| [Project guide](docs/PROJECT_GUIDE.md) | Setup, scene layout, vehicle physics, tuning, exports, and troubleshooting |

## ✨ What’s in the prototype

- Four raycast wheel assemblies with spring-and-damper suspension.
- Rear-wheel motor force, curve-driven acceleration, tire traction, and handbrake slip.
- Speed-aware chase camera with free look, zoom, collision clipping, and impact shake.
- Test ground, a simple obstacle, particle skid effects, and debug force/velocity arrows.
- A Windows Desktop export preset.

## 🗂️ Project layout

```text
.
├── README.MD
├── docs/
│   ├── CONTROLS.md
│   └── PROJECT_GUIDE.md
├── scenes/
│   └── test_world.tscn
├── scripts/
│   ├── camera.gd
│   ├── raycast_car.gd
│   └── raycast_wheel.gd
├── assets/
│   ├── models/                 # Car body and wheel models
│   └── tex/kenney_prototype-textures/
├── material/
├── debug_draw_3d-1.7.3/        # Bundled debug-draw add-on
├── project.godot
└── export_presets.cfg
```

## 🧰 Technology and assets

- **Engine:** Godot 4.7
- **Renderer:** Forward Plus
- **3D physics:** Jolt
- **Vehicle logic:** GDScript
- **Prototype textures:** Kenney Prototype Textures, distributed under **CC0**; see [the included license](assets/tex/kenney_prototype-textures/License.txt).
- **Debug drawing:** Debug Draw 3D is bundled under `debug_draw_3d-1.7.3/`; see its [included README](debug_draw_3d-1.7.3/addons/debug_draw_3d/README.md) and [license](debug_draw_3d-1.7.3/addons/debug_draw_3d/LICENSE).

## 📦 Export

The repository includes a **Windows Desktop** preset. Set or confirm its output path in **Project → Export** before exporting; the checked-in preset points to `../Games/vehicle/vehicle.exe`. Godot export templates must be installed for the selected engine version.

For add-on installation details, input mappings, and tuning notes, see the [project guide](docs/PROJECT_GUIDE.md).
