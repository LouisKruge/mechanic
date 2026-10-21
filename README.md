# GARAGE

A first-person car mechanic simulator for Windows PC, built with **Godot 4** and typed GDScript.

**Milestone 1** is one complete, playable repair job: **JOB 001 — Charging System Failure** on
*Project C01*, a fictional front-engine, rear-wheel-drive sports coupe. You diagnose a failed
alternator with a scanner, isolate the battery, strip the accessory drive, swap the alternator,
torque everything back up, prove the repair with a charging-system test and sign off the work order.

> All torque figures, part numbers, prices and the vehicle itself are **fictional demonstration
> values**. Nothing in the game is a manufacturer specification. The diagnostic code used
> (P0562 *System Voltage Low*) is a generic SAE OBD-II code; everything the game says about it is simulated.

## Requirements

* Godot **4.3 stable** or newer 4.x (developed and tested against 4.3.stable.official.77dcf97d8).
* Forward+ renderer (Vulkan / D3D12). The project also runs on the Compatibility renderer
  (`--rendering-driver opengl3`); SSAO is unavailable there.
* No add-ons, plugins or external dependencies.

## Launching

1. Open Godot, **Import** → select this folder's `project.godot` → **Import & Edit**.
2. Press **F5** (Run Project). The main scene is `res://scenes/main.tscn`.

From a terminal:

```bat
godot --path C:\path\to\mechanic
```

### Exporting for Windows

Install the Godot export templates (Editor → Manage Export Templates), add a **Windows Desktop**
preset in Project → Export, then export. `export_presets.cfg` is intentionally not committed.

## Controls

| Input | Action |
|---|---|
| W A S D | Move |
| Mouse | Look (sensitivity in Esc → Settings) |
| Shift | Sprint |
| Ctrl | Crouch (hold) |
| Space | Jump |
| **E** | Interact: open hood, connectors, take/install parts, start engine… |
| **F** | Inspect the targeted component (opens the inspection panel) |
| **LMB** (hold) | Tool action — tighten, lever the tensioner, toggle flashlight, use scanner |
| **RMB** (hold) | Alternate action — loosen, disconnect scanner |
| 1 – 5 | Ratchet · Torque wrench · Flashlight · Scanner · Socket set |
| H | Holster (hands) |
| [ / ] | Change socket fitted to the ratchet / torque wrench |
| Mouse wheel | Torque-wrench setting (or socket, for the ratchet) |
| Tab | Inventory (tools, sockets, parts, fastener tray) |
| J | Work order (objectives, sign-off) |
| Esc | Close panel / pause menu (save, load, settings, quit) |
| F5 / F9 | Quick save / quick load |

## Walkthrough of JOB 001

1. Walk in, read the **information board** (right wall) or press **J**.
2. At the car: **E** on the hood to open it. Equip the **flashlight (3)**, LMB to switch it on,
   **F** on the alternator and battery to inspect them.
3. Equip the **scanner (4)**, **E** on the diagnostic port by the driver's window. Read codes.
4. **E** on the ignition switch to start the engine (it cranks slowly). Open the scanner again
   and run the **charging-system test** — it fails and identifies the alternator. Stop the engine.
5. **Ratchet (1)** with a **10 mm** socket, hold **RMB** on the battery's negative clamp until it lifts off.
6. LMB with the ratchet on the **belt tensioner**, then **E** on the belt to slip it off the alternator pulley.
7. **E** on the alternator connector. Switch to a **13 mm** socket and hold **RMB** on bolts **B01** and **B02**.
8. **E** on the alternator — it goes to your inventory. Optionally drop it in the **core return bin**.
9. **E** on the boxed alternator on the **parts shelf** (left wall). It is now held.
10. **E** on the empty mount to fit it. **E** on each bolt hole to start the bolts, LMB with the ratchet to run them down.
11. **Torque wrench (2)**, scroll to **45 N·m** (demo value), hold LMB on each bolt until it clicks.
12. **E** on the connector, **E** on the belt, LMB with the ratchet on the tensioner.
13. **E** on the battery clamp, then ratchet LMB until tight.
14. Start the engine, run the charging-system test (PASS), then **J → Sign off**.

If you drain the battery by running the engine with the faulty alternator, connect the
**battery maintainer** on the tool trolley (E).

## Project layout

```
project.godot
scenes/
  main.tscn                  root scene (Main)
  vehicles/project_c01.tscn  vehicle mount points (Marker3D) — edit positions here
scripts/
  core/        GameSession (composition root), ContentDatabase, InteractionResolver, InputConfig
  data/        immutable definition Resources (tools, fasteners, components, vehicles, jobs, faults)
  mechanics/   runtime state + rules: ComponentInstance, FastenerInstance, VehicleState,
               ConditionEvaluator, MechanicalDependencyValidator, AssemblyService
  systems/     InventoryManager, ToolManager, ElectricalSystem, DiagnosticManager, JobManager, SaveManager
  player/      PlayerController, InteractionManager, ToolViewmodel
  world/       Main, GarageBuilder, VehicleView, Interactable, MeshKit, WorkshopMaterials
  ui/          UIManager, HUD and panels, UITheme
data/          the definition .tres files (the content)
tests/         headless test runner and suites
tools/         capture_screenshots.gd (visual check under a display)
docs/          ARCHITECTURE.md, TESTING.md
```

## Running the tests

```bash
godot --headless --path . --import                       # first time only: builds the class cache
godot --headless --path . --script res://tests/run_tests.gd
godot --headless --path . --script res://tests/run_tests.gd -- --only=mechanics
```

The runner exits with code 0 when every test passes. See `docs/TESTING.md` for what is covered
and the last recorded results.

## Saves and settings

* Save slot: `user://saves/slot_1.json` (on Windows: `%APPDATA%\Godot\app_userdata\GARAGE\saves\`).
* Settings: `user://settings.cfg`.

## Further reading

* [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md) — systems, data model, dependency engine, save format, how to add content.
* [`docs/TESTING.md`](docs/TESTING.md) — test inventory, results and known limitations.
