# GARAGE

A first-person car mechanic simulator for Windows PC, built with **Godot 4** and typed GDScript.

Two complete, playable repair jobs on two vehicles:

* **JOB 001 — Charging System Failure** on *Project C01* (fictional coupe): diagnose a failed
  alternator with the scanner, isolate the battery, strip the accessory drive, swap and torque
  the alternator, prove the repair with a charging-system test, sign off.
* **JOB 101 — LT Coolant Leak** on the *BMW M4 Competition (G82)*: find a seeping charge-cooler
  hose with the flashlight or a pressure test, isolate the trunk-mounted battery, remove the
  strut brace, drain the low-temperature circuit into a pan, swap the hose and clamps, refill,
  bleed with the scanner routine, top up, pressure-test, sign off.

The Porsche 911 GT3 (992) and Audi RS 3 (8Y) exist as catalogue entries (engine/drivetrain
architecture defined, not playable yet). All vehicle art is **original procedural placeholder
geometry** — see [What is placeholder](#what-is-placeholder).

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
| 1 – 7 | Ratchet · Torque wrench · Flashlight · Scanner · Socket set · Hose clamp pliers · Pressure tester |
| H | Holster (hands) |
| [ / ] | Change socket fitted to the ratchet / torque wrench |
| Mouse wheel | Torque-wrench setting (or socket, for the ratchet) |
| Tab | Inventory (tools, sockets, parts, fastener tray) |
| J | Work order (objectives, sign-off) |
| Esc | Close panel / pause menu (save, load, settings, **workshop jobs**, quit) |
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

## JOB 101 in short (BMW M4)

Pause menu → Workshop jobs → JOB 101. Open the hood; flashlight (3) + F on the charge-cooler
hose reveals the seepage. Open the trunk and remove the battery's negative clamp (10 mm).
Remove brace bolts BR1–BR4 (13 mm, RMB) and lift the brace off (E). E on the auxiliary radiator
places the drain pan; E on the expansion tank opens the cap; remove the drain plug (10 mm) and
wait for the circuit to empty. Hose clamp pliers (6): E on both clamps, E on the hose. Take the
new hose and the coolant jug from the shelf, fit the hose, refit clamps and drain plug, pour
coolant (E on the open tank). Refit the brace and torque its bolts to 28 N·m (demo), reconnect
the battery, close the cap, run *Scanner → Bleed*, top up, pressure-test (7, LMB on the open
tank), close the cap, sign off. The **lift control** on the right post raises the car; wheel
bolts (17 mm) can only be removed with the car raised.

## What is placeholder

Everything visual is original procedural geometry: lofted bodies with separate panels, lathe-built
wheels, profile-driven engine assemblies, procedural noise textures and a procedural sky. It is
structured for detailed models (see [`docs/ASSET_PIPELINE.md`](docs/ASSET_PIPELINE.md)) but it
is **not** photorealistic and does not reproduce the real cars' design. No licensed vehicle
models, HDRIs or PBR texture sets are included — the build environment could not reach the free
asset sites, and real BMW/Porsche/Audi depictions need manufacturer trademark licences for a
commercial release. See [`docs/ASSETS_AND_LICENSES.md`](docs/ASSETS_AND_LICENSES.md).

## Project layout

```
project.godot
scenes/
  main.tscn                  root scene (Main)
  vehicles/project_c01.tscn  vehicle mount points (Marker3D) — edit positions here
scripts/
  core/        GameSession (composition root), ContentDatabase, InteractionResolver, InputConfig
  data/        immutable definition Resources (tools, fasteners, components, vehicles, jobs, faults,
               fluid circuits, engine/drivetrain configurations, body profiles)
  assets/      vehicle model convention, validator, loader (GLB), binder, template exporter
  mechanics/   runtime state + rules: ComponentInstance, FastenerInstance, VehicleState,
               ConditionEvaluator, MechanicalDependencyValidator, AssemblyService
  systems/     InventoryManager, ToolManager, ElectricalSystem, FluidSystem, DiagnosticManager,
               JobManager, SaveManager
  player/      PlayerController, InteractionManager, ToolViewmodel
  world/       Main, GarageBuilder, WorkshopProps, VehicleView, VehicleMaterials, Interactable, MeshKit
    procedural/  ProcMesh (lathe/loft/tube), VehicleBodyBuilder, WheelBuilder, InteriorBuilder,
                 EngineAssemblyBuilder, EngineBayDressing
  ui/          UIManager, HUD and panels, UITheme
data/          the definition .tres files (the content)
tests/         headless test runner and suites
tools/         capture_screenshots.gd, export_vehicle_template.gd, validate_vehicle_model.gd,
               blender/garage_vehicle_tools.py, blender/roundtrip_test.sh
docs/          ARCHITECTURE.md, ASSET_PIPELINE.md, VEHICLES.md, ASSETS_AND_LICENSES.md, TESTING.md
```

## Running the tests

```bash
godot --headless --path . --import                       # first time only: builds the class cache
godot --headless --path . --script res://tests/run_tests.gd
godot --headless --path . --script res://tests/run_tests.gd -- --only=mechanics
```

The runner exits with code 0 when every test passes. See `docs/TESTING.md` for what is covered
and the last recorded results. The Blender round trip (needs Blender or `pip install bpy`):

```bash
tools/blender/roundtrip_test.sh <godot> <blender-or-bpy-python> /tmp/garage_rt
GARAGE_BLENDER_GLB=/tmp/garage_rt/bmw_m4_g82_from_blender.glb godot --headless --path . --script res://tests/run_tests.gd
```

## Saves and settings

* One save slot per vehicle: `user://saves/<vehicle_id>.json` (on Windows:
  `%APPDATA%\Godot\app_userdata\GARAGE\saves\`). Format version 2; version-1 saves are migrated.
* Settings: `user://settings.cfg`.

## Further reading

* [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md) — systems, data model, dependency engine, save format, how to add content.
* [`docs/ASSET_PIPELINE.md`](docs/ASSET_PIPELINE.md) — GLB/Blender workflow, naming convention, validator.
* [`docs/VEHICLES.md`](docs/VEHICLES.md) — vehicles, what is reference data and what is fictional.
* [`docs/ASSETS_AND_LICENSES.md`](docs/ASSETS_AND_LICENSES.md) — asset log and the assets still needed.
* [`docs/TESTING.md`](docs/TESTING.md) — test inventory, results and known limitations.
