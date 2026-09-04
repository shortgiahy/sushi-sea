"""validate_asset.py — checks the selected object(s) against docs/design/Asset Pipeline.md's
export contract before FBX/OBJ export: triangle budget, material/texture-map count, pivot at
local origin, and fully-applied transforms.

Not run against real Blender yet — no assets exist in this repo to validate (PRD §9: "specify
and script, don't sculpt," modeling starts at Phase 5). Treat this as a starting point to
smoke-test against the first real model, not verified tooling.

Usage (Scripting tab): select one or more mesh objects, Run Script. Reports one line per object.
Usage (headless): blender --background yourfile.blend --python validate_asset.py
"""

import bpy
from mathutils import Vector

TRIANGLE_BUDGET = 10000
MAX_TEXTURE_MAPS_PER_MATERIAL = 4
PIVOT_TOLERANCE = 0.01  # studs-equivalent slack for "pivot is at a sensible local origin"


def _triangle_count(obj):
    mesh = obj.data
    count = 0
    for polygon in mesh.polygons:
        # A polygon with N vertices triangulates into (N - 2) triangles — matches how the FBX
        # exporter/Studio importer will actually count it, not raw polygon count.
        count += max(len(polygon.vertices) - 2, 1)
    return count


def _texture_map_count(obj):
    maps = set()
    for slot in obj.material_slots:
        material = slot.material
        if not material or not material.use_nodes:
            continue
        for node in material.node_tree.nodes:
            if node.type == "TEX_IMAGE" and node.image:
                maps.add(node.image.name)
    return len(maps)


def _has_unapplied_transform(obj):
    loc, rot, scale = obj.location, obj.rotation_euler, obj.scale
    location_applied = all(abs(value) < 1e-6 for value in loc)
    rotation_applied = all(abs(value) < 1e-6 for value in rot)
    scale_applied = all(abs(value - 1.0) < 1e-6 for value in scale)
    return not (location_applied and rotation_applied and scale_applied)


def _pivot_offset_from_geometry_center(obj):
    mesh = obj.data
    if not mesh.vertices:
        return 0.0
    center = sum((v.co for v in mesh.vertices), start=Vector((0.0, 0.0, 0.0))) / len(mesh.vertices)
    return center.length


def validate(obj):
    issues = []

    if obj.type != "MESH":
        return [f"{obj.name}: not a mesh object, skipping"]

    triangles = _triangle_count(obj)
    if triangles > TRIANGLE_BUDGET:
        issues.append(f"{triangles} triangles exceeds the {TRIANGLE_BUDGET} budget")

    texture_maps = _texture_map_count(obj)
    if texture_maps > MAX_TEXTURE_MAPS_PER_MATERIAL:
        issues.append(f"{texture_maps} texture maps exceeds the {MAX_TEXTURE_MAPS_PER_MATERIAL} limit")

    if _has_unapplied_transform(obj):
        issues.append("has an unapplied location/rotation/scale — apply all transforms before export")

    pivot_offset = _pivot_offset_from_geometry_center(obj)
    if pivot_offset > PIVOT_TOLERANCE:
        issues.append(
            f"pivot sits {pivot_offset:.3f}m from the mesh's geometric center — confirm this is "
            "the intended grab point, not an unset origin"
        )

    if not issues:
        return [f"{obj.name}: OK ({triangles} tris, {texture_maps} texture maps)"]
    return [f"{obj.name}: {issue}" for issue in issues]


def main():
    selected = [obj for obj in bpy.context.selected_objects if obj.type == "MESH"]
    if not selected:
        print("validate_asset: no mesh objects selected")
        return

    for obj in selected:
        for line in validate(obj):
            print(f"validate_asset: {line}")


if __name__ == "__main__":
    main()
