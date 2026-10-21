"""GARAGE vehicle asset tools for Blender (4.x).

Checks and exports vehicle models that follow the GARAGE naming convention
(docs/ASSET_PIPELINE.md). Works inside Blender or with the `bpy` module:

  blender -b -P tools/blender/garage_vehicle_tools.py -- check  <in.glb|in.blend> --manifest <anchors.json>
  blender -b -P tools/blender/garage_vehicle_tools.py -- export <in.glb|in.blend> <out.glb> --manifest <anchors.json> [--fix]
  python  tools/blender/garage_vehicle_tools.py export ...        (with `pip install bpy`)

Blender space: metres, +Z up, the car's nose pointing +Y. The glTF exporter's
"+Y up" option converts this to glTF/Godot space (+Y up, nose towards -Z).

--fix creates any anchor empties listed in the manifest that are missing,
at the manifest positions (converted to Blender space).
"""
import json
import os
import sys

import bpy  # noqa: E402  (provided by Blender or the bpy module)
from mathutils import Matrix, Vector

REQUIRED = ["Panel_hood", "Panel_trunk", "Wheel_FL", "Wheel_FR", "Wheel_RL", "Wheel_RR"]
REQUIRED_MATERIALS = ["MAT_paint", "MAT_glass"]
# glTF/Godot (x, y, z) -> Blender (x, -z, y)
GLTF_TO_BLENDER = Matrix(((1, 0, 0, 0), (0, 0, -1, 0), (0, 1, 0, 0), (0, 0, 0, 1)))


def _args():
    argv = sys.argv
    argv = argv[argv.index("--") + 1:] if "--" in argv else argv[1:]
    opts = {"manifest": None, "fix": False}
    pos = []
    i = 0
    while i < len(argv):
        a = argv[i]
        if a == "--manifest":
            opts["manifest"] = argv[i + 1]
            i += 2
            continue
        if a == "--fix":
            opts["fix"] = True
        else:
            pos.append(a)
        i += 1
    return pos, opts


def base_name(name):
    """Strip Blender duplicate suffixes like .001."""
    while len(name) > 4 and name[-4] == "." and name[-3:].isdigit():
        name = name[:-4]
    return name


def load(path):
    if path.lower().endswith(".blend"):
        bpy.ops.wm.open_mainfile(filepath=path)
        return
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=path)


def objects_by_base():
    out = {}
    for ob in bpy.data.objects:
        out.setdefault(base_name(ob.name), ob)
    return out


def check(manifest):
    """Returns (errors, warnings)."""
    errors, warnings = [], []
    obs = objects_by_base()
    if not any(n.startswith("Body_") for n in obs):
        errors.append("No Body_* object.")
    for n in REQUIRED:
        if n not in obs:
            errors.append("Missing %s." % n)
    for n, ob in obs.items():
        if ob.type == "MESH" and any(s < 0 for s in ob.scale):
            errors.append("%s has negative scale; apply transforms." % n)
    if bpy.context.scene.unit_settings.scale_length not in (0.0, 1.0):
        warnings.append("Scene unit scale is %.3f; GARAGE expects metres (1.0)." % bpy.context.scene.unit_settings.scale_length)
    # Orientation: in Blender the nose points +Y.
    if "Light_head_L" in obs and "Light_tail_L" in obs:
        if obs["Light_head_L"].matrix_world.translation.y <= obs["Light_tail_L"].matrix_world.translation.y:
            errors.append("Nose must point +Y in Blender (headlights are behind the tail lights).")
    meshes = [ob for ob in bpy.data.objects if ob.type == "MESH"]
    if meshes:
        ys = [(ob.matrix_world @ Vector(c)).y for ob in meshes if not base_name(ob.name).startswith("Mirror_") for c in ob.bound_box]
        length = max(ys) - min(ys)
        if not 2.5 <= length <= 6.5:
            errors.append("Length along Y is %.2f m; check units and orientation." % length)
    mats = {base_name(m.name) for m in bpy.data.materials}
    for m in REQUIRED_MATERIALS:
        if m not in mats:
            warnings.append("Material %s not found." % m)
    if manifest:
        missing = [a["name"] for a in manifest["anchors"] if a["name"] not in obs]
        if missing:
            warnings.append("%d anchor(s) missing: %s" % (len(missing), ", ".join(missing[:8])))
    return errors, warnings


def fix_anchors(manifest):
    """Create missing anchor empties from the manifest. Returns how many were made."""
    obs = objects_by_base()
    made = 0
    for a in manifest["anchors"]:
        if a["name"] in obs:
            continue
        b = a["basis"]
        # Godot basis columns x, y, z -> 4x4 in glTF space, then to Blender space.
        m = Matrix(((b[0], b[3], b[6], a["position"][0]), (b[1], b[4], b[7], a["position"][1]), (b[2], b[5], b[8], a["position"][2]), (0, 0, 0, 1)))
        ob = bpy.data.objects.new(a["name"], None)
        ob.empty_display_type = "ARROWS"
        ob.empty_display_size = 0.05
        ob.matrix_world = GLTF_TO_BLENDER @ m @ GLTF_TO_BLENDER.inverted()
        bpy.context.scene.collection.objects.link(ob)
        made += 1
    return made


def export(path):
    os.makedirs(os.path.dirname(os.path.abspath(path)), exist_ok=True)
    bpy.ops.export_scene.gltf(filepath=path, export_format="GLB", export_yup=True, use_selection=False, export_apply=True, export_extras=True)


def _exit(code):
    # bpy-as-a-module can crash during interpreter teardown; leave immediately.
    sys.stdout.flush()
    sys.stderr.flush()
    os._exit(code)


def main():
    pos, opts = _args()
    if not pos or pos[0] not in ("check", "export"):
        print(__doc__)
        _exit(2)
    manifest = json.load(open(opts["manifest"])) if opts["manifest"] else None
    load(pos[1])
    made = fix_anchors(manifest) if (opts["fix"] and manifest) else 0
    errors, warnings = check(manifest)
    for e in errors:
        print("ERROR   ", e)
    for w in warnings:
        print("WARNING ", w)
    if made:
        print("FIXED    created %d anchor empties from the manifest" % made)
    if pos[0] == "export":
        if errors:
            print("Not exporting: fix the errors first.")
            _exit(1)
        export(pos[2])
        print("EXPORTED", pos[2])
    print("RESULT  ", "INVALID" if errors else "VALID", "(%d errors, %d warnings)" % (len(errors), len(warnings)))
    _exit(1 if errors else 0)


if __name__ == "__main__":
    main()
