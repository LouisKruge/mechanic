# GARAGE — Architecture notes

## Principles

* **Rules live in plain objects, visuals live in nodes.** Every gameplay rule runs inside a
  `GameSession` made of `RefCounted` systems. Scene nodes (player, vehicle view, UI) only read
  state and forward input. The entire repair job can therefore be driven headlessly in tests.
* **Definitions are immutable; state is per instance.** `*Definition` Resources describe *what a
  thing is*. `ComponentInstance`, `FastenerInstance` and `VehicleState` hold *what has happened to
  this car*. Nothing writes to a definition at runtime (asserted by `test_runtime_state_does_not_mutate_definitions`).
* **Procedures are data.** The alternator job is not coded anywhere as a sequence. It emerges from
  `DependencyCondition`s attached to components, fasteners and toggles, evaluated by one engine.
* **Fail closed.** Unknown condition kinds, missing IDs or unimplemented context queries evaluate
  to *blocked*, never to *allowed*.

## System map

```
Main (Node3D)                                 scenes/main.tscn
 ├─ GarageBuilder      workshop geometry, lights, fixtures (shelf, bin, board, maintainer)
 ├─ VehicleView        Project C01 from scenes/vehicles/project_c01.tscn markers
 ├─ PlayerController   CharacterBody3D, camera, flashlight, ToolViewmodel
 │   └─ InteractionManager   centre ray → Interactable → session input calls
 └─ UIManager (CanvasLayer)  HUD, InspectionPanel, Inventory, WorkOrder, Scanner, Pause, Completion

GameSession (extends ConditionContext)        the "GameManager"
 ├─ ContentDatabase     loads res://data/**.tres, indexes by ID
 ├─ VehicleState        ComponentInstance × n, FastenerInstance × n, assembly revision
 ├─ InventoryManager    tools, part records, fastener tray, core bin
 ├─ ToolManager         equipped tool, socket size, torque setting, flashlight
 ├─ AssemblyService     remove / install / toggle / turn fasteners (enforces rules)
 ├─ ElectricalSystem    battery SOC & voltage, alternator output, loads, cranking
 ├─ DiagnosticManager   scanner: codes, live data, charging test, fault discovery
 ├─ JobManager          objectives (latched) and sign-off (re-checked live)
 └─ InteractionResolver target + input → action; HUD/inspection descriptions
SaveManager (static)    versioned JSON ↔ GameSession.to_save_dict / apply_save_dict
```

Dependencies point one way: nodes → session → systems → data. Systems that need to query other
state do it through the `ConditionContext` interface rather than by referencing each other.
`GameSession.dispose()` breaks the remaining back-references (resolver ↔ session) on exit.

Signals carry state changes outward: `VehicleState.component_changed / fastener_changed /
revision_changed`, `ToolManager.changed`, `InventoryManager.changed`, `JobManager.progress_changed /
objective_completed / job_completed`, `GameSession.message_posted / inspect_requested /
panel_requested / engine_state_changed / world_changed`.

## Data model

| Resource | Key fields |
|---|---|
| `ToolDefinition` | id, category, actions, uses_socket, can_final_torque, hotbar_slot, ui_glyph, socket_sizes_mm |
| `FastenerDefinition` | id, kind (bolt/nut/screw/connector/clip), tool_type, tool_size_mm, torque_target_nm (demo), tolerance, requires_torque_wrench, thread_turns |
| `FastenerSlotDefinition` | slot_id, fastener, retains_component, removal/installation dependencies, initial_state |
| `ComponentToggleDefinition` | flag, labels, input (E or LMB), required_tools, set_true/set_false dependencies |
| `ComponentDefinition` | id, category, compatible_with, removable, required_tools, fasteners, removal/installation dependencies, toggles, wear_per_hour, min_functional_condition, fault_capabilities, purchase_price, mass_kg, performance |
| `FaultDefinition` | id, discovery_methods, visual_clue, output_factor |
| `VehicleDefinition` | components, initial_state overrides, initial_dtcs, initial SOC, start_requirements, battery_connection, charging_path, loads |
| `JobDefinition` | complaint, objectives (`JobObjectiveDefinition`: conditions + `after`), completion_requirements, supplied_parts |

Runtime:

| Class | State |
|---|---|
| `ComponentInstance` | installed, part_uid, condition, faults (hidden), discovered_faults, inspection (none/visual/tested), flags, parameters |
| `FastenerInstance` | removed, thread_progress (0–1), torque_nm → derived state REMOVED / LOOSE / TIGHT / OVERTIGHT |
| `VehicleState` | components, fasteners, `revision` (bumped on every mechanical change) |
| Part record (Dictionary) | uid, component_id, condition, faults, discovered_faults, inspection, is_new — a removed part keeps its identity |

Fastener runtime IDs are `"<component>.<slot>"`, e.g. `alternator.B01`, `battery.NEG`.

## The dependency engine

`DependencyCondition` kinds:

| kind | subject | key / expected |
|---|---|---|
| `component_installed` | component | expected bool |
| `component_flag` | component | key = flag, expected bool |
| `fastener_state` | fastener id | key = `removed` / `installed` / `tight` |
| `component_fasteners` | component | same keys, all retaining fasteners |
| `component_fault_free` | component | expected bool |
| `fault_discovered` | component | key = fault id |
| `engine_running` | — | expected bool |
| `charging_test_passed` | — | valid only for the current assembly revision |
| `event` | event id | — |
| `tool_equipped` | tool id | — |
| `part_in_inventory` | component | key = `new` or empty |
| `objective_complete` | objective id | — |

`ConditionEvaluator.evaluate()` answers *does it hold*; `describe_unmet()` explains *why not*
using the definition's own vocabulary (toggle state texts, fastener names), or a custom `message`.
`AssemblyService` composes these into actions:

* **Remove component** = removable ∧ installed ∧ removal_dependencies ∧ every *retaining* fastener removed ∧ tool.
* **Install component** = held part fits (ID + compatibility) ∧ installation_dependencies ∧ retaining fasteners clear.
* **Toggle** = installed ∧ tool ∧ set_true / set_false dependencies.
* **Fastener** = component installed ∧ correct tool & socket ∧ slot dependencies; hand-start → ratchet run-down → torque.

The alternator's procedure, as data (`data/components/*.tres`):

```
alternator.remove      requires hood.open, battery.NEG removed, belt_tensioner.released,
                       accessory_belt.on_alternator_pulley == false, + CONN, B01, B02 removed
alternator.CONN.remove requires battery.NEG removed
alternator.B0x.remove  requires belt off the pulley, battery.NEG removed
accessory_belt off     requires belt_tensioner.released, engine off
belt_tensioner release requires ratchet, hood.open, engine off
battery.NEG.remove     requires hood.open, engine off
accessory_belt on      requires tensioner released, alternator installed, B01/B02 fitted
```

Blocked actions report the first reason (`Cannot remove alternator: mounting bolt B02 is still
installed.`); the inspection panel lists every blocker.

### Validation

`MechanicalDependencyValidator.validate(db)` runs at startup (errors are logged and shown in the
HUD) and in tests. It checks unique IDs, known condition kinds, that every referenced component,
flag, fastener, fault and tool exists, fastener torque data, vehicle electrical roles, job objective
references — and **cycles**. It builds an action graph (`C:x:remove`, `C:x:install`,
`T:x:flag:true`, `F:x.y:remove`, `F:x.y:install`, `F:x.y:tight`) where an edge means "requires a
state only that action produces", plus the implicit edges (component removal → its fasteners'
removal; fastener fitting → component installed), and reports every cycle found by DFS.

## Electrical model (simulated)

* OCV = 11.89 V + 0.76 V × SOC. Internal resistance rises as battery condition falls.
* Alternator capability = rated × idle fraction × health(condition) × fault factor, and **zero**
  unless the vehicle's `charging_path` conditions hold (installed, connector on, belt on, tensioned).
* Running load 32 A. If capability ≥ load: surplus charges the battery (limited by acceptance),
  regulator holds ~14.2 V. Otherwise the battery supplies the deficit, voltage sags, SOC falls.
* Cranking: V = OCV − 150 A × R. Below 9.6 V the engine won't turn; below 10.5 V it "cranks slowly".
* Time runs 20× faster than real time for charge changes (`ElectricalSystem.SIM_TIME_SCALE`).
* Charge lamp = engine running ∧ not charging.

The scanner reads codes (symptom only), live data and runs a **charging-system test** which is
the only way to identify the `alternator_output_failure` fault. The flashlight gives a visual clue,
not a diagnosis. A test result is stamped with `VehicleState.revision`; any later mechanical change
invalidates it, so the job cannot be signed off on a stale pass.

## Save format (version 1)

```json
{
  "format": "garage-save", "version": 1, "game_version": "0.1.0", "saved_at_utc": "…",
  "player":      {"position": [x, y, z], "yaw": 0.0, "pitch": 0.0, "crouching": false},
  "inventory":   {"tools": [...], "parts": [part records], "fastener_tray": ["alternator.B01"], "held_part_uid": "", "core_bin": [...]},
  "tools":       {"equipped": "ratchet", "socket_mm": 13, "torque_setting_nm": 45.0, "flashlight_on": false},
  "vehicle":     {"vehicle_id": "project_c01", "revision": 42, "uid_counter": 9,
                  "components": {"alternator": {"installed": true, "condition": 100.0, "faults": [], "discovered_faults": [], "flags": {}, ...}},
                  "fasteners":  {"alternator.B01": {"removed": false, "thread_progress": 1.0, "torque_nm": 45.0}}},
  "electrical":  {"soc": 0.39, "engine_running": false, "charger_connected": false},
  "diagnostics": {"connected": true, "stored_codes": ["P0562"], "last_test": {...}},
  "job":         {"job_id": "job_001", "completed_objectives": [...], "signed_off": false},
  "events":      ["entered_workshop", ...],
  "world":       {"shelf_stock": {"alternator": 0}, "stock_counter": 1}
}
```

* Only stable IDs and primitive values are written — never engine objects.
* Written to `*.tmp` then renamed (a crash mid-write keeps the previous save).
* Loading: rejects corrupt JSON, wrong `format`, missing or newer `version`. `SaveManager.migrate()`
  is the hook for future versions. Unknown components/fasteners/tools/parts/objectives are skipped
  with warnings; numbers are clamped; undeclared flags are ignored; an invalid section keeps defaults.

## Adding content

* **New component**: create a `ComponentDefinition` .tres in `data/components/`, add it to the
  vehicle's `components`, add a `Marker3D` with the same name under `Mounts` in the vehicle scene
  (and child markers named after each fastener slot, local −Z pointing out of the hole). Add a
  placeholder builder in `VehicleView._build_components()` — or put an imported model under the
  marker as a child named `Model`, which is used automatically.
* **New job**: a `JobDefinition` with objectives built from the condition kinds above. Run the tests:
  the validator rejects unknown references and cycles.
* **New vehicle**: a `VehicleDefinition` + a vehicle scene with markers. Systems take IDs, not
  hardcoded alternator logic; the electrical roles are named in the definition.
* **New fault**: a `FaultDefinition` with discovery methods, listed in the component's
  `fault_capabilities`.

## Known simplifications

* Torque is a time-based accumulation while LMB is held, not a force simulation.
* Engine running is a state (idle only); there is no drivetrain or test drive yet.
* Removed parts are inventory records; they are not spawned as physics objects.
* The tensioner is modelled as "locked released" (pin), so it needn't be held while moving the belt.
