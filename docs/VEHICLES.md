# Vehicles

| ID | Vehicle | Status | Engine configuration | Drivetrain | Job |
|---|---|---|---|---|---|
| `project_c01` | Project C01 (fictional coupe) | Playable | Inline-4, NA, port injection (fictional) | Front-engine RWD, manual | JOB 001 — charging system |
| `bmw_m4_g82` | BMW M4 Competition (G82) | Playable (placeholder art) | S58-inspired inline-6, twin-turbo, water-to-air charge cooling, direct injection | Front-engine RWD, 8-speed automatic, active LSD | JOB 101 — LT coolant leak |
| `porsche_911_gt3_992` | Porsche 911 GT3 (992) | Catalogue only | Flat-6, NA, 180° banks, rear-mounted | Rear-engine RWD, 7-speed dual-clutch | — |
| `audi_rs3_8y` | Audi RS 3 Sportback (8Y) | Catalogue only | Inline-5, turbo, transverse, air-to-air intercooler | Front-engine AWD, 7-speed dual-clutch | — |

Each vehicle has its own definition, engine and drivetrain configuration,
component graph (IDs prefixed per vehicle, e.g. `m4_alternator`), compatible
parts (`compatible_with`), repair procedures (jobs), visual profile/model and
save slot (`user://saves/<vehicle_id>.json`). The engine builder lays out inline,
V and flat engines differently, so the GT3's flat-six cannot reuse the M4's
inline-six arrangement.

## What is real and what is not

**Reference figures** (`EngineConfiguration.reference_figures`) are widely
published architecture facts, stored for information only and never used as
specifications: S58 — 2,993 cc, six cylinders, two turbochargers; 992 GT3 —
3,996 cc flat-six; RS 3 8Y — 2,480 cc inline-five, one turbocharger.

**Fictional demonstration values** — everything the simulation uses:
all torque targets (e.g. 28 N·m brace bolts, 130 N·m wheel bolts), coolant
capacities and drain rates, alternator ratings, battery capacities, prices,
masses, positions and geometry. They are labelled as demo values in the UI
and in the data notes. They are **not** manufacturer specifications.

**Simulated diagnostics**: P0562 is a generic SAE OBD-II code; `SIM-LT01` is an
invented game code (prefixed `SIM-`), not a BMW fault code.

## BMW M4 (G82) — component graph

Modelled and interactive (scene markers / anchors): hood, trunk lid, engine
assembly, strut brace (4 bolts), LT expansion tank (cap), charge-cooler hose
(2 spring clamps, leak fault), auxiliary LT radiator (drain plug, drain pan),
alternator (connector + 2 bolts), bracket, belt tensioner, accessory belt,
battery in the trunk (negative terminal), starter, four road wheels (5 bolts
each, lift required).

Data only (stable IDs, condition, compatibility and dependencies; no model or
interaction yet): cylinder head, front/rear turbochargers, charge-air cooler,
intake manifold, HP fuel rail and injectors, HP fuel pump, ignition coils, oil
filter housing, main radiator, coolant pump, transmission, driveshaft, rear
differential, exhaust system, four brakes, four struts/dampers, seats,
dashboard. These validate in the dependency graph today and become serviceable
when their placeholders or models and procedures are added.

## Adding a vehicle

1. Engine and drivetrain configurations (`data/vehicles/engines`, `.../drivetrains`).
2. Component definitions in `data/components/<vehicle_id>/` with `visual` archetypes.
3. A `VehicleDefinition` with body profile, fluid circuits, electrical roles,
   start/lift requirements; `playable = false` until the scene exists.
4. A vehicle scene with `Mounts` markers (or a model with `MNT_`/`FST_` anchors).
5. A job (`JobDefinition`). Run the tests — the validator rejects bad references
   and dependency cycles.
