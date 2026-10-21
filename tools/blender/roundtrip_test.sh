#!/usr/bin/env bash
# End-to-end asset pipeline check:
#   Godot template GLB -> Blender (import, delete an anchor, --fix, export) -> Godot validator.
# Usage: tools/blender/roundtrip_test.sh <godot-binary> <blender-python-or-blender> <work-dir> [vehicle]
set -euo pipefail
GODOT="$1"; BLENDER="$2"; WORK="$3"; VEH="${4:-bmw_m4_g82}"
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
mkdir -p "$WORK"
"$GODOT" --headless --path "$ROOT" --script res://tools/export_vehicle_template.gd -- --vehicle="$VEH" --out="$WORK/${VEH}_template.glb"
# Simulate an artist file that lost an anchor, then let --fix restore it.
cat > "$WORK/drop_anchor.py" <<PY
import bpy, sys
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath="$WORK/${VEH}_template.glb")
ob = bpy.data.objects.get("MNT_m4_lt_expansion_tank")
if ob: bpy.data.objects.remove(ob)
bpy.ops.wm.save_as_mainfile(filepath="$WORK/${VEH}_artist.blend")
print("artist file saved without MNT_m4_lt_expansion_tank")
import os, sys; sys.stdout.flush(); os._exit(0)
PY
run_blender() {
  if [[ "$BLENDER" == *python* ]]; then "$BLENDER" "$@"; else "$BLENDER" -b -P "$1" -- "${@:2}"; fi
}
run_blender "$WORK/drop_anchor.py"
run_blender "$ROOT/tools/blender/garage_vehicle_tools.py" export "$WORK/${VEH}_artist.blend" "$WORK/${VEH}_from_blender.glb" --manifest "$WORK/${VEH}_template_anchors.json" --fix
"$GODOT" --headless --path "$ROOT" --script res://tools/validate_vehicle_model.gd -- --vehicle="$VEH" --model="$WORK/${VEH}_from_blender.glb"
