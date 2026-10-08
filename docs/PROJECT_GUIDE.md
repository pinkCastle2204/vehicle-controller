# Project guide

## 🧩 Requirements

- **Godot 4.7**: declared in `project.godot`.
- **Forward Plus** renderer and **Jolt** 3D physics: selected in the project settings.
- **Git** is optional for opening and running the project.

## 🚀 Open and run

1. Open Godot's Project Manager and import this repository by selecting its `project.godot`.
2. Wait for asset import to finish.
3. Resolve the [debug-draw add-on location](#debug-draw-add-on) if the editor or runtime reports an unknown `DebugDraw3D` identifier.
4. Run the project with **F5** to start its configured main scene or **F6** to run the currently open scene.

The test scene contains a flat ground plane, a physics body for the car, and a simple raised obstacle. Use the [controls reference](CONTROLS.md) to drive.

## 🧪 Debug-draw add-on

The car controller calls the `DebugDraw3D` singleton to draw velocity, suspension, motor, and traction arrows. The project setting points the add-on root at:

```text
res://addons/debug_draw_3d
```

The bundled add-on files are currently located at:

```text
res://debug_draw_3d-1.7.3/addons/debug_draw_3d
```

These locations do not match. If `DebugDraw3D` is unavailable, install the bundled `addons/debug_draw_3d` folder at the configured project path (create the top-level `addons` folder if needed), then reopen or rescan the project. Keep the add-on's folder contents together, including its `.gdextension` file and `libs` directory. The project also includes the vendor's [README](../debug_draw_3d-1.7.3/addons/debug_draw_3d/README.md) and [license](../debug_draw_3d-1.7.3/addons/debug_draw_3d/LICENSE).

## 🏗️ Scene and scripts

```text
World                                      scenes/test_world.tscn
├── WorldEnvironment / DirectionalLight3D
├── StaticBody3D                           Ground and collision
├── carMesh : RigidBody3D                  scripts/raycast_car.gd
│   ├── body                                Imported body model
│   ├── WheelFL / WheelFR                   RaycastWheel; steer
│   ├── WheelRL / WheelRR                   RaycastWheel; motor
│   ├── skidparticles                       Four skid particle emitters
│   └── Camera3D                            scripts/camera.gd
└── speedBreaker                            Static-body test obstacle

RaycastWheel : RayCast3D                   scripts/raycast_wheel.gd
```

`raycast_wheel.gd` defines the `RaycastWheel` type and wheel-level suspension/grip properties. `raycast_car.gd` updates the suspension and applies motor and tire forces for each configured wheel. `camera.gd` follows the rigid body and handles free look, zoom, collision clipping, and speed/impact effects.

## ⚙️ Vehicle physics and tuning

The vehicle is a `RigidBody3D` with four downward `RayCast3D` wheel nodes. Each ray checks for ground contact; when grounded, the controller computes spring and damping forces, then applies traction and (on the rear pair) motor force at the wheel positions. The controller also rotates the wheel meshes based on forward motion. Press **F3** to toggle Debug Draw 3D rendering for the force and velocity arrows; see the [controls reference](CONTROLS.md).

| Setting | Where to tune | Notes |
|---|---|---|
| Vehicle mass | `carMesh` in `scenes/test_world.tscn` | Set to `50` in the test scene. |
| Acceleration | `acceleration` on `raycast_car.gd` | Script default is `600`; force is scaled by motor input and the acceleration curve. |
| `maxSpeed` | `raycast_car.gd` | Script default is `20`; used to normalize the acceleration-curve sample. It is not a strict speed limiter. |
| Suspension | Each wheel node in `scenes/test_world.tscn` | Scene values include `springConstant = 2000`, `springDamping = 300`, and `overExtend = 0.4`. |
| Wheel radius | Each `RaycastWheel` | `wheelRad` affects suspension contact and visual rolling. |
| Grip response | Wheel `gripCurve` | Shapes lateral traction based on the tire's lateral-slip ratio. |
| Steering | `tireTurnSpeed`, `tireMaxTurnDegrees` | Script defaults are `2.0` and `25` degrees. Steering is applied to `WheelFL` and `WheelFR`. |
| Camera | Exports in `camera.gd` | Adjust follow distance, smoothing, free-look, collision, FOV, and shake in the Inspector. |

> [!WARNING]
> The controller expects the wheel nodes named `WheelFL`, `WheelFR`, `WheelRL`, and `WheelRR`, with a wheel visual as the first child of each ray. It also indexes four skid emitters in the same order as the exported `wheels` array. Preserve these scene/script relationships when restructuring the car.

### Tuning workflow

1. Duplicate the test scene before making large physics changes.
2. Change a small group of related Inspector values at a time (for example, suspension stiffness and damping).
3. Run the scene and observe both handling and the debug arrows.
4. If the vehicle does not accelerate, first confirm rear-wheel `is_motor` is enabled and the add-on is installed. If suspension does not react, check ray direction, contact distance, and wheel radius.

## 📦 Exporting

The repository has a **Windows Desktop** export preset configured for 64-bit x86. In Godot, open **Project → Export**, select that preset, and verify the output path before exporting:

```text
../Games/vehicle/vehicle.exe
```

Install the matching Godot export templates if the editor requests them. The preset is a Windows target; other platforms need their own export preset and a compatible build of the native debug-draw extension.

## 🖼️ Third-party assets

- The Kenney Prototype Textures used in the scene include a [CC0 license](../assets/tex/kenney_prototype-textures/License.txt).
- The bundled Debug Draw 3D add-on includes its own [license](../debug_draw_3d-1.7.3/addons/debug_draw_3d/LICENSE) and [upstream documentation](../debug_draw_3d-1.7.3/addons/debug_draw_3d/README.md). Consult those materials for the add-on's terms and usage details.

## 🛠️ Troubleshooting

| Symptom | Check |
|---|---|
| `DebugDraw3D` is unknown | Confirm the add-on is installed at `res://addons/debug_draw_3d` and that its native library supports your current platform/editor. |
| Car falls through the test ground | Confirm the scene finished importing, and inspect the ground collision shape and wheel ray collision masks. |
| Car does not steer | Check that the front ray nodes retain the exact names `WheelFL` and `WheelFR`. |
| Handbrake does not make skid marks | Check the Space/button binding, four skid emitters, and the array order on `carMesh`. |
| Export fails | Install matching export templates and confirm the Windows Desktop preset's output path is writable. |
