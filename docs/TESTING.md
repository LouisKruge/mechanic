# GARAGE — Testing

## Environment used

* Godot **4.3.stable.official.77dcf97d8**, Linux x86_64 (headless), in a cloud container.
* Visual checks: Xvfb virtual display + Mesa software OpenGL, **Compatibility renderer**
  (`--rendering-driver opengl3`). No Vulkan driver was available, so the **Forward+ renderer
  has not been run** — it is the project default and uses only standard Godot 4 features, but
  its output (including SSAO) is unverified.
* **Windows was not available.** The project has no platform-specific code, but it has not been
  launched or exported on Windows.

## How to run

```bash
godot --headless --path . --import                          # builds the class cache (first run)
godot --headless --path . --script res://tests/run_tests.gd # all suites; exit code 0 = pass
godot --headless --path . --script res://tests/run_tests.gd -- --only=save
godot --headless --path . --quit-after 1500                 # soak-run the main scene
xvfb-run -a godot --path . --rendering-driver opengl3 --script res://tools/capture_screenshots.gd -- --out=/tmp/shots
```

The headless (dummy) renderer prints `Parameter "m" is null … mesh_storage.h` for primitive
meshes. That is an engine-side artefact of the dummy renderer (it stores no mesh data) and does
not occur with a real renderer; the runs below filter it out.

## Results (last run)

| Check | Result |
|---|---|
| `--import` (parse every script and resource) | 0 errors |
| Main scene, 1500 frames headless | 0 errors, 0 warnings, no leaked objects |
| Test runner | **33 passed, 0 failed, 249 checks**, exit code 0 |
| Screenshot capture under Xvfb/OpenGL | 12 frames rendered, reviewed manually |

```
== test_content.gd
  PASS  test_definitions_load  (11 checks)
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
== test_scene.gd
  PASS  test_main_scene_loads  (19 checks)
  PASS  test_player_moves_and_collides  (6 checks)
  PASS  test_raycast_detects_components  (17 checks)
  PASS  test_removed_parts_update_visuals  (5 checks)
  PASS  test_ui_panels_toggle_input_mode  (10 checks)
  PASS  test_quick_save_and_load_in_scene  (3 checks)
33 passed, 0 failed, 249 checks, 11.5 s
```

## Coverage against the milestone requirements

| Requirement | Test(s) |
|---|---|
| Project opens without script parse errors | `--import`; every suite loads every script |
| Main scene loads | `test_main_scene_loads` |
| Player can move | `test_player_moves_and_collides` (walk, floor, wall/door, car body, engine-bay guard, crouch) |
| Raycast detects components | `test_raycast_detects_components` (12 vehicle targets, shelf, board, maintainer; closed hood occludes the bay; HUD shows the name) |
| Wrong tools cannot remove bolts | `test_wrong_tools_cannot_remove_bolts` (hands, flashlight, scanner, wrong socket, torque wrench) |
| Fasteners block premature removal | `test_fasteners_block_premature_part_removal` (exact "mounting bolt B01/B02 is still installed" messages) |
| Dependencies enforced | `test_dependency_order_is_enforced`, `test_bolts_blocked_until_belt_off_and_battery_isolated` |
| Damaged alternator can be removed | `test_alternator_removed_after_dependencies` (part keeps identity, condition, fault) |
| Replacement can be installed | `test_replacement_installs_and_snaps_to_mount`, `test_bolt_tightening_workflow` (hand start, snug, over-torque, re-torque) |
| Verification detects incomplete assembly | `test_signoff_refused_with_incomplete_assembly` (under-torqued B02; stale test after later change), `test_reinstalling_faulty_part_does_not_fix` |
| Completed repair resolves the charging fault | `test_full_repair_completes_job` (all 22 objectives), `test_repair_restores_charging` |
| Diagnostics are coherent and do not reveal hidden faults | `test_initial_symptoms`, `test_scanner_does_not_reveal_hidden_fault`, `test_visual_inspection_gives_clue_only_with_flashlight` |
| Save/load preserves mechanical state | `test_round_trip_preserves_mechanical_state` (mid-repair, part-threaded bolt, then finishes the job), `test_quick_save_and_load_in_scene` |
| Invalid save data handled | `test_invalid_saves_are_rejected_gracefully`, `test_partial_and_hostile_data_degrades_safely` |
| Definitions validated, cycles rejected | `test_validator_*`, `test_cycle_finder_*` |
| Definitions not mutated by play | `test_runtime_state_does_not_mutate_definitions` |

The mechanics tests drive the session through the same entry points the E / F / LMB / RMB
handlers call (`tests/support/repair_driver.gd`), with held buttons simulated frame by frame.

## Bugs found by testing and fixed

* Objectives only latched on a 0.2 s timer, so a transient state (battery isolated, then
  reconnected) could be missed. Objectives are now evaluated on every state change.
* Quick-save could store a stale player position (synced only in `_process`).
* The torque wrench's repeat "click" notice overwrote the "within spec" verdict while held.
* Disconnecting a connector left its engagement at 1 while a loaded save normalised it to 0.
* (Visual review) HUD panels collapsed into the top-left corner — anchors set before the
  controls entered the tree. The rear glass made the coupe read as a pickup. The shelf and
  board walls were unlit. All fixed.
* Furniture colliders blocked the interaction ray to items resting on them; furniture now uses a
  dedicated physics layer that blocks the player but not the ray.

## Not verified / known limitations

* Not run on Windows, and not run with the Forward+ (Vulkan) renderer — see Environment.
* Mouse-look and mouse-capture were not exercised with a real mouse (tests call `apply_look`/`set_view`).
* No audio.
* Placeholder art is procedural primitives; the car is recognisable but blocky.
* The fastener "torque" is a timed accumulation while LMB is held, not a physical model.
* Removed parts exist as inventory records, not as physical objects that can be dropped.
* Only one job, one vehicle; customisation, purchasing, tuning and test drives are not started.
