# Controls

The bindings below match the project's `[input]` map in `project.godot`.

## ⌨️ Keyboard and mouse

| Action | Key / input | Effect |
|---|---|---|
| Accelerate | **W** | Apply forward motor input |
| Decelerate / reverse | **S** | Apply opposite motor input |
| Steer left | **A** | Turn the front wheels left |
| Steer right | **D** | Turn the front wheels right |
| Handbrake | **Space** | Reduce tire grip and enable skid particles |
| Toggle debug drawing | **F3** | Show or hide the vehicle's 3D debug arrows |
| Free-look | Move the mouse while captured | Orbit the chase-camera view |
| Camera zoom | Mouse wheel up / down | Move the chase camera closer / farther |
| Capture / release mouse | **Esc** | Toggle mouse capture |

> [!TIP]
> The camera starts with the mouse captured for free-look. Press **Esc** to release it; press **Esc** again to capture it.

## 🎮 Gamepad

| Action | Gamepad input |
|---|---|
| Accelerate | Right trigger (axis 5) |
| Decelerate / reverse | Left trigger (axis 4) |
| Steer | Left stick, horizontal axis |
| Handbrake | Button index 2 |
| Camera free-look | Right stick |

The camera uses the first connected gamepad's right stick for free-look. Gamepad zoom and a look-behind action are not currently mapped.

## ℹ️ Behavior notes

- Acceleration and steering are polled continuously; the car uses a physics-driven, raycast-wheel controller rather than built-in vehicle wheel nodes.
- The handbrake changes tire traction. Skid particles emit while the handbrake is held and stop when the tires regain grip.
- The camera recenters after look input has been idle while the car is moving. Its distance and field of view also adjust with speed.
- Press **F3** to toggle Debug Draw 3D rendering for the vehicle's force and velocity arrows.
