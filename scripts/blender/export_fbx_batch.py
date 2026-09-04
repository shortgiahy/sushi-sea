"""export_fbx_batch.py — exports every top-level mesh object in the current .blend to its own
.fbx in a target directory, named directly from the object's own name in Blender's outliner. This
makes naming-convention compliance in Blender (docs/design/Asset Pipeline.md's
`{Category}_{AssetName}_{Variant?}` scheme) directly become the exported filename — no separate
renaming step to forget.

Not run against real Blender yet — no assets exist in this repo to export (PRD §9). Treat this as
a starting point to smoke-test against the first real model, not verified tooling.

Usage (headless, recommended for batch work):
    blender --background yourfile.blend --python export_fbx_batch.py -- /path/to/export/dir

Usage (Scripting tab): edit EXPORT_DIR below, Run Script.
"""

import sys
import os

import bpy

EXPORT_DIR = None  # set here for interactive use, or pass a directory after `--` on the command line


def _resolve_export_dir():
    if "--" in sys.argv:
        args_after_separator = sys.argv[sys.argv.index("--") + 1 :]
        if args_after_separator:
            return args_after_separator[0]
    if EXPORT_DIR:
        return EXPORT_DIR
    raise ValueError(
        "export_fbx_batch: no export directory given — pass one after `--` on the command line, "
        "or set EXPORT_DIR at the top of this script"
    )


def _export_object(obj, export_dir):
    bpy.ops.object.select_all(action="DESELECT")
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj

    filepath = os.path.join(export_dir, f"{obj.name}.fbx")
    bpy.ops.export_scene.fbx(
        filepath=filepath,
        use_selection=True,
        apply_unit_scale=True,
        apply_scale_options="FBX_SCALE_ALL",
        object_types={"MESH", "ARMATURE"},
        mesh_smooth_type="FACE",
        add_leaf_bones=False,
    )
    return filepath


def main():
    export_dir = _resolve_export_dir()
    os.makedirs(export_dir, exist_ok=True)

    top_level_meshes = [
        obj for obj in bpy.context.scene.objects if obj.type == "MESH" and obj.parent is None
    ]
    if not top_level_meshes:
        print("export_fbx_batch: no top-level mesh objects found in the scene")
        return

    for obj in top_level_meshes:
        filepath = _export_object(obj, export_dir)
        print(f"export_fbx_batch: exported {obj.name} -> {filepath}")


if __name__ == "__main__":
    main()
