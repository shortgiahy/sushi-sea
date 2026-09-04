"""procedural_fish_scale.py — duplicates a base fish mesh and scales each copy to a species'
relative size, so one authored fish model can stand in for FishSpecies.lua's whole roster during
an early art pass, before each species earns its own unique model.

Scale factors are relative sizing guesses (mackerel/sea_bream small, yellowtail/opah mid, tuna
large, kraken far larger) — not measured from anything, since no real fish model exists yet to
measure. Treat as a starting point, same "first-pass, not locked" status as every numeric guess
elsewhere in this repo.

Not run against real Blender yet (PRD §9). Mirrors src/shared/Modules/FishSpecies.lua's roster —
if that file's species list changes, update SPECIES_SCALE to match.

Usage (Scripting tab): select the base fish mesh, set BASE_OBJECT_NAME below to match, Run Script.
Produces one new object per entry in SPECIES_SCALE, named `Fish_{Species}` per the Asset
Pipeline.md naming convention.
"""

import bpy

BASE_OBJECT_NAME = "Fish_Base"

# id -> uniform scale multiplier relative to the base mesh. Ordering mirrors FishSpecies.lua.
SPECIES_SCALE = {
    "mackerel": 0.8,
    "sea_bream": 0.85,
    "yellowtail": 1.3,
    "tuna": 2.2,
    "opah": 1.8,
    "kraken": 6.0,
}


def main():
    base = bpy.data.objects.get(BASE_OBJECT_NAME)
    if not base:
        print(f"procedural_fish_scale: no object named '{BASE_OBJECT_NAME}' found — set BASE_OBJECT_NAME to match")
        return

    for species_id, scale in SPECIES_SCALE.items():
        duplicate = base.copy()
        duplicate.data = base.data.copy()
        duplicate.name = f"Fish_{species_id.title().replace('_', '')}"
        duplicate.scale = (base.scale[0] * scale, base.scale[1] * scale, base.scale[2] * scale)
        bpy.context.collection.objects.link(duplicate)
        print(f"procedural_fish_scale: created {duplicate.name} at {scale}x base scale")

    print("procedural_fish_scale: remember to apply scale (Object > Apply > Scale) before export")


if __name__ == "__main__":
    main()
