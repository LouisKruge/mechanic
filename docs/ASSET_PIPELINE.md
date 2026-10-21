# Vehicle asset pipeline (glTF / GLB, Godot 4 + Blender)

Everything here works with free software only: Godot 4.3+, Blender 4.x
(or the `bpy` Python module), and freely licensed or original assets.

## 1. How a vehicle is put together

```
VehicleDefinition (.tres)          data: components, fasteners, dependencies, circuits
  ├─ body_profile                  proportions for the procedural placeholder body
  ├─ engine / drivetrain_config    architecture (inline / V / flat, layout, gearbox)
  ├─ scene_path  -> vehicle scene  Marker3D mount points (authoring fallback)
  └─ model_path  -> .glb / .gltf   optional detailed model (this pipeline)
```

At runtime `VehicleView` uses the imported model if `model_path` is set and the
model passes validation; otherwise it builds the procedural placeholder. Both
follow the **same naming convention**, so gameplay code never knows which one it
has. A rejected model logs its errors and falls back to the placeholder — the
game never breaks because of a bad asset.

## 2. Naming convention

| Node | Meaning |
|---|---|
| `Body_*` | Painted shell pieces (at least one). |
| `Panel_hood`, `Panel_trunk`, `Panel_door_L/R` | Openable panels. **Origin = hinge line** (hood: rear edge; trunk: front edge). |
| `Glass_*` | Glazing. |
| `Light_head_L/R`, `Light_tail_L/R` | Lamps (also used to check orientation). |
| `Wheel_FL/FR/RL/RR` | Origin = wheel centre. Child `Spin*` = parts that rotate and leave with the wheel (tyre, rim). Brake disc/caliper stay outside `Spin`. |
| `Mirror_*` | Excluded from body width checks. |
| `MNT_<component_id>` | Empty: mount anchor of an interactive component (e.g. `MNT_m4_alternator`). |
| `FST_<component_id>__<slot_id>` | Empty: fastener anchor (e.g. `FST_m4_alternator__B01`). **Local −Z points out of the hole** (the direction the fastener travels when removed). |
| `Part_<component_id>` | Mesh that replaces that component's placeholder (e.g. `Part_m4_cc_hose`). |
| `ENG_*` | Engine sub-assembly pieces (optional; same names as the procedural engine). |
| `COL_*` | Optional collision proxies — stripped at runtime (vehicle colliders are generated from the body profile so gameplay reach stays tuned). |

Materials: `MAT_paint` and `MAT_glass` are required; `MAT_tyre`, `MAT_rim`,
`MAT_lens`, `MAT_tail_lens`, `MAT_chrome`, `MAT_trim`, ... are recognised.
Duplicate-name suffixes added by DCC tools (`.001`, `_001`) are ignored when matching.

Space: **metres, +Y up, nose towards −Z** in glTF and Godot. In Blender the
nose points **+Y** with **+Z up**; the glTF exporter's "+Y up" option converts.

## 3. Workflow

1. **Export a template** for the vehicle (placeholder body + every anchor at the
   authored marker positions + an anchor manifest):
   ```bash
   godot --headless --path . --script res://tools/export_vehicle_template.gd -- \
         --vehicle=bmw_m4_g82 --out=/work/bmw_m4_g82_template.glb
   ```
2. **Model in Blender**: File → Import → glTF, model over the placeholder, keep
   the `MNT_*`/`FST_*` empties where the real parts are (move them if your
   geometry differs — the game follows the anchors), name meshes per the table.
3. **Check / fix / export** with the Blender tool (adds missing anchors from the
   manifest with `--fix`):
   ```bash
   blender -b -P tools/blender/garage_vehicle_tools.py -- export model.blend out.glb \
           --manifest /work/bmw_m4_g82_template_anchors.json --fix
   ```
4. **Validate in Godot** (exit code 1 on errors):
   ```bash
   godot --headless --path . --script res://tools/validate_vehicle_model.gd -- \
         --vehicle=bmw_m4_g82 --model=/work/out.glb
   ```
5. Copy the GLB into the project (e.g. `res://assets/vehicles/bmw_m4_g82/model.glb`),
   let the editor import it, and set `model_path` in the vehicle definition.
   External GLBs (`user://` or absolute paths) are also loaded at runtime.

`tools/blender/roundtrip_test.sh` runs steps 1–4 automatically and simulates an
artist file that lost an anchor; the Godot test-suite then checks that binding
the Blender export reproduces every marker within 1 mm.

## 4. What the validator checks

* `Body_*`, `Panel_hood`/`Panel_trunk` (when the vehicle has them), four wheels with `Spin*`.
* Every `MNT_`/`FST_` anchor the vehicle definition needs (missing ones fall back to scene markers — warning).
* Unknown anchors / part names (warning).
* Length 2.5–6.5 m along Z, not wider than long (catches cm/inch units and 90° rotation).
* Front towards −Z (headlights ahead of tail lights; otherwise hood ahead of trunk).
* Size within 12 % of the body profile (mirrors excluded).
* Hood/trunk pivots on their hinge edge; wheel pivots at the axle.
* No negative scale on moving parts; warns on non-uniform scale.
* Required materials; triangle budget (warning above 600 k, error above 2 M).

## 5. Licensing rules for vehicle assets

* Use only original work or assets whose licence allows use **and redistribution
  in a game** (CC0, CC-BY with attribution, or an explicit written permission).
* Never use models ripped or extracted from commercial games, or "free" uploads
  of unclear origin. Record every asset in `docs/ASSETS_AND_LICENSES.md`
  (source URL, author, licence, date, modifications).
* **Trademarks are separate from model licences.** Manufacturer names, badges,
  logos and distinctive design elements (e.g. grille shapes) are protected
  regardless of who made the 3D model. Shipping a commercial game that depicts
  real BMW, Porsche or Audi vehicles normally requires a licence from the
  manufacturer. The data keeps display names in `VehicleDefinition.display_name`
  and `manufacturer`, so a build can rename vehicles without touching gameplay;
  placeholder art deliberately avoids badges and signature grille designs.
