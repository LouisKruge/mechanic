# GARAGE — Testing

## Environment used

* Godot **4.3.stable.official.77dcf97d8**, Linux x86_64, headless, in a cloud container.
* Blender **4.2** as the `bpy` Python module (headless) for the asset round trip.
* Visual checks: Xvfb + Mesa software OpenGL, **Compatibility renderer**
  (`--rendering-driver opengl3`). No Vulkan driver was available, so the **Forward+
  renderer (the project default) has not been run**: SSAO/SSIL/SSR, soft PCSS shadows and
  the reflection probe are configured but their output is unverified.
* **Windows was not available**; nothing platform-specific is used, but the game has not
  been launched or exported on Windows. Real mouse input was not exercised.

## How to run

```bash
godot --headless --path . --import
godot --headless --path . --script res://tests/run_tests.gd               # exit code 0 = pass
godot --headless --path . --script res://tests/run_tests.gd -- --only=m4
godot --headless --path . --quit-after 1500                               # soak-run the main scene
tools/blender/roundtrip_test.sh <godot> <blender | bpy-python> /tmp/rt     # Godot -> Blender -> Godot
GARAGE_BLENDER_GLB=/tmp/rt/bmw_m4_g82_from_blender.glb godot --headless --path . --script res://tests/run_tests.gd
xvfb-run -a godot --path . --rendering-driver opengl3 --script res://tools/capture_screenshots.gd -- --out=/tmp/shots [--job=job_101]
```

The headless dummy renderer prints `Parameter "m" is null … mesh_storage.h` for procedural
meshes; it is an artefact of that renderer (it stores no mesh data) and is filtered out below.

## Results (last run)

| Check | Result |
|---|---|
| `--import` (all scripts and resources) | 0 errors |
| Content validation (4 vehicles, 2 jobs, 60 components) | 0 errors, no dependency cycles |
| Main scene, 1500 frames headless | 0 errors, no leaked objects |
| Test runner (Blender GLB supplied) | **48 passed, 0 failed, 467 checks**, exit code 0 |
| Blender round trip (`roundtrip_test.sh`) | template exported, anchor removed in Blender and restored by `--fix`, re-exported GLB: **VALID, 0 errors, 0 warnings**, 48/48 anchors, 19 materials |
| Screenshots (OpenGL, both jobs) | rendered and reviewed manually |

```
== test_content.gd
  PASS  test_definitions_load  (13 checks)
  PASS  test_validator_accepts_shipped_content  (1 checks)
  PASS  test_validator_detects_dependency_cycle  (1 checks)
  PASS  test_validator_accepts_acyclic_chain  (1 checks)
  PASS  test_validator_detects_bad_references  (4 checks)
  PASS  test_cycle_finder_reports_self_loop_and_long_cycle  (1 checks)
  PASS  test_runtime_state_does_not_mutate_definitions  (6 checks)
== test_mechanics.gd
  PASS  test_wrong_tools_cannot_remove_bolts  (10 checks)
  PASS  test_bolts_blocked_until_belt_off_and_battery_isolated  (2 checks)
  PASS  test_fasteners_block_premature_part_removal  (4 checks)
  PASS  test_dependency_order_is_enforced  (9 checks)
  PASS  test_alternator_removed_after_dependencies  (5 checks)
  PASS  test_replacement_installs_and_snaps_to_mount  (8 checks)
  PASS  test_bolt_tightening_workflow  (9 checks)
  PASS  test_full_repair_completes_job  (27 checks)
  PASS  test_signoff_refused_with_incomplete_assembly  (6 checks)
  PASS  test_reinstalling_faulty_part_does_not_fix  (4 checks)
  PASS  test_parts_storage_core_return  (3 checks)
== test_diagnostics.gd
  PASS  test_initial_symptoms  (10 checks)
  PASS  test_scanner_does_not_reveal_hidden_fault  (11 checks)
  PASS  test_visual_inspection_gives_clue_only_with_flashlight  (7 checks)
  PASS  test_battery_isolated_blocks_start_and_scanner  (3 checks)
  PASS  test_flat_battery_needs_maintainer  (5 checks)
  PASS  test_repair_restores_charging  (4 checks)
== test_save_load.gd
  PASS  test_round_trip_preserves_mechanical_state  (17 checks)
  PASS  test_invalid_saves_are_rejected_gracefully  (6 checks)
  PASS  test_partial_and_hostile_data_degrades_safely  (14 checks)
== test_m4.gd
  PASS  test_m4_definition_differs_from_c01  (52 checks)
  PASS  test_job101_full_procedure  (25 checks)
  PASS  test_leak_blockers_and_drain_rules  (8 checks)
  PASS  test_pressure_test_finds_leak_and_incomplete_assembly  (3 checks)
  PASS  test_signoff_refused_when_not_bled  (2 checks)
  PASS  test_lift_and_wheel_removal  (10 checks)
  PASS  test_stripped_thread_needs_new_hardware  (6 checks)
  PASS  test_parts_are_vehicle_specific  (1 checks)
  PASS  test_m4_save_round_trip_with_fluids_and_lift  (6 checks)
  PASS  test_v1_save_migrates  (4 checks)
== test_asset_pipeline.gd
  PASS  test_procedural_body_follows_convention  (2 checks)
  PASS  test_validator_rejects_bad_models  (5 checks)
  PASS  test_template_glb_round_trip_and_binding  (38 checks)
  PASS  test_blender_output_if_available  (35 checks)
== test_scene.gd
  PASS  test_main_scene_loads  (19 checks)
  PASS  test_player_moves_and_collides  (6 checks)
  PASS  test_raycast_detects_components  (17 checks)
  PASS  test_removed_parts_update_visuals  (6 checks)
  PASS  test_ui_panels_toggle_input_mode  (10 checks)
  PASS  test_quick_save_and_load_in_scene  (3 checks)
  PASS  test_m4_job_loads_and_is_reachable  (18 checks)
48 passed, 0 failed, 467 checks, 24.6 s
```

Without `GARAGE_BLENDER_GLB` the Blender test is skipped and reports a single "skipped" check.

## Coverage

| Area | Tests |
|---|---|
| Original milestone (JOB 001, tools, fasteners, saves, raycasts) | `test_mechanics`, `test_diagnostics`, `test_save_load`, `test_scene` (unchanged and passing) |
| BMW M4 data differs from C01 and catalogue cars are distinct | `test_m4_definition_differs_from_c01` |
| JOB 101 end to end (22 objectives) | `test_job101_full_procedure` |
| Fluid rules (pan, venting, clamps need pliers and an empty circuit, leak while running, level-sensor code, cap with engine running) | `test_leak_blockers_and_drain_rules` |
| Pressure test finds the leak; sign-off refused when not bled | `test_pressure_test_finds_leak_and_incomplete_assembly`, `test_signoff_refused_when_not_bled` |
| Lift + wheel bolts + lift-lower requirement | `test_lift_and_wheel_removal` |
| Stripped threads, spare hardware | `test_stripped_thread_needs_new_hardware` |
| Parts are vehicle-specific | `test_parts_are_vehicle_specific` |
| M4 save round trip (fluid level, lift, carried coolant), v1 → v2 migration | `test_m4_save_round_trip_with_fluids_and_lift`, `test_v1_save_migrates` |
| Asset validator rejects rotated, cm-unit, backwards, bad-pivot and incomplete models | `test_validator_rejects_bad_models` |
| GLB round trip + binding accuracy (≤ 1 mm, orientation) | `test_template_glb_round_trip_and_binding`, `test_blender_output_if_available` |
| M4 in the scene: job loads, shelf stocked, closed hood/trunk occlude, key parts reachable, lift raises, switching jobs | `test_m4_job_loads_and_is_reachable` |
| Part slide/snap animation, pause menu pauses the simulation | `test_removed_parts_update_visuals`, `test_ui_panels_toggle_input_mode` |

## Bugs found while testing this upgrade (fixed)

* Topping up after bleeding re-flagged air in the circuit, making JOB 101 impossible to finish.
* Full-width body colliders enclosed the wheels, so wheel bolts could not be targeted.
* Axis-aligned collision boxes around the diagonal strut-brace arms swallowed nearby targets.
* The rear-wall collider stood above the visible tail and a closed trunk left a gap above it.
* `Orientation` enum name clashed with a Godot global; properties written above `script =`
  in `.tres` files were silently dropped.
* glTF export ignored `material_override` (materials now baked into surfaces); exporters
  rename duplicate `Spin` nodes (any `Spin*` accepted); mirrors inflated the width check;
  packed arrays read from a Dictionary are copies (validator material list).
* Procedural hood/trunk panels were not pivoted at their hinges (now they are, and the view
  attaches lids by transform so imported and procedural panels behave the same).
* Tests: tween waits used frame counts (headless frames are not real time); the main scene
  remembered the last job in user settings; stand positions inside the M4's longer bumper.

## Not verified / known limitations

* Forward+ rendering, Windows, real mouse input — see Environment.
* All art is procedural placeholder geometry; no licensed models, HDRIs or texture sets.
* The Porsche 911 GT3 (992) and Audi RS 3 (8Y) are catalogue entries only (no scene or job).
* Many M4 systems are data-only (no model or interaction yet); see `docs/VEHICLES.md`.
* Doors are separate meshes but do not open; the driver's window is modelled open.
* Torque is a timed accumulation; fluids are levels, not flow simulation; no temperatures.
* No audio.
