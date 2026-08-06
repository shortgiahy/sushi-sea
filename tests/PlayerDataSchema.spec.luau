-- Headless tests for PlayerDataSchema (PRD §7.3): serialize/deserialize round-trip + migration chain.
local serde = require("@lune/serde")
local PlayerDataSchema = require("../src/server/ServerStorage/Modules/PlayerDataSchema")

local function deepEquals(a: any, b: any): boolean
    if type(a) ~= type(b) then
        return false
    end
    if type(a) ~= "table" then
        return a == b
    end
    for key, value in a do
        if not deepEquals(value, b[key]) then
            return false
        end
    end
    for key in b do
        if a[key] == nil then
            return false
        end
    end
    return true
end

-- Serialize/deserialize round-trip: DataStore effectively JSON-round-trips whatever we hand it,
-- so a schema that can't survive an encode/decode cycle would silently corrupt on a real save.
do
    local original = PlayerDataSchema.newDefault()
    original.economy.gold = 1250
    original.skills.fishing.level = 7
    original.skills.fishing.xp = 340
    table.insert(original.inventory, { id = "uuid-1", species = "salmon", caughtAt = 1718000000 })
    table.insert(original.restaurant.trophies, { species = "kraken", mountedAt = 1718005000 })

    local encoded = serde.encode("json", original)
    local decoded = serde.decode("json", encoded)

    assert(deepEquals(original, decoded), "PlayerData must survive a JSON encode/decode round-trip unchanged")
    print("PlayerDataSchema.spec: serialize/deserialize round-trip OK")
end

-- Migration chain: a legacy/partial shape (no meta.schemaVersion at all, missing whole sections)
-- must migrate forward to the current schema, preserving whatever real data it had.
do
    local legacy = {
        skills = {
            fishing = { level = 5, xp = 120 },
        },
        economy = {
            gold = 999,
        },
        -- no inventory, agingLocker, restaurant, or meta at all — simulates pre-versioning data
    }

    local migrated = PlayerDataSchema.migrate(legacy)

    assert(
        migrated.meta.schemaVersion == PlayerDataSchema.SCHEMA_VERSION,
        "migrated data must land on current schemaVersion"
    )
    assert(migrated.skills.fishing.level == 5, "migration must preserve existing fishing level")
    assert(migrated.skills.fishing.xp == 120, "migration must preserve existing fishing xp")
    assert(migrated.skills.cooking.level == 1, "migration must fill in missing skills with defaults")
    assert(migrated.economy.gold == 999, "migration must preserve existing gold")
    assert(migrated.economy.tutorialLoanOwed == 500, "migration must fill in missing economy fields with defaults")
    assert(
        type(migrated.inventory) == "table" and #migrated.inventory == 0,
        "migration must fill in missing inventory as empty array"
    )
    assert(
        type(migrated.restaurant) == "table" and migrated.restaurant.tier == 0,
        "migration must fill in missing restaurant section"
    )
    print("PlayerDataSchema.spec: migration chain (legacy -> current) OK")
end

-- Never-silently-overwrite: nil (brand-new player, GetAsync returned nothing) must produce a
-- fresh default, not an error or a half-populated table.
do
    local fresh = PlayerDataSchema.migrate(nil)
    assert(
        fresh.meta.schemaVersion == PlayerDataSchema.SCHEMA_VERSION,
        "nil input must produce current-schema default data"
    )
    assert(fresh.economy.gold == 0, "fresh default must start with zero gold")
    print("PlayerDataSchema.spec: nil input -> fresh default OK")
end

-- v1 -> v2 (M4): a real schema-v1 save (no cookedPortions field at all, predating its addition)
-- must gain an empty cookedPortions array and land on v2, without disturbing any v1 field.
do
    local v1Save = {
        skills = {
            fishing = { level = 3, xp = 50 },
            cooking = { level = 2, xp = 10 },
            sailing = { level = 1, xp = 0 },
            hospitality = { level = 1, xp = 0 },
            purchasing = { level = 1, xp = 0 },
        },
        inventory = { { id = "uuid-2", species = "tuna", caughtAt = 1718001000 } },
        agingLocker = {},
        restaurant = { tier = 0, staffHeadcount = 0, prestigePoints = 0, trophies = {} },
        economy = { gold = 300, offlineSnapshotAt = 0, offlineStockCount = 0, tutorialLoanOwed = 500 },
        meta = { schemaVersion = 1, firstJoinAt = 1717999000, lastJoinAt = 1718000000 },
    }

    local migrated = PlayerDataSchema.migrate(v1Save)

    assert(migrated.meta.schemaVersion == 2, "a v1 save must migrate forward to schemaVersion 2")
    assert(
        type(migrated.cookedPortions) == "table" and #migrated.cookedPortions == 0,
        "a v1 save must gain an empty cookedPortions array"
    )
    assert(migrated.skills.cooking.level == 2, "v1 -> v2 migration must not disturb existing skill data")
    assert(migrated.economy.gold == 300, "v1 -> v2 migration must not disturb existing economy data")
    assert(
        #migrated.inventory == 1 and migrated.inventory[1].id == "uuid-2",
        "v1 -> v2 migration must not disturb existing inventory"
    )
    print("PlayerDataSchema.spec: v1 -> v2 migration (cookedPortions addition) OK")
end

-- Already-current data must pass through the chain without being altered or re-defaulted.
do
    local current = PlayerDataSchema.newDefault()
    current.economy.gold = 42
    local result = PlayerDataSchema.migrate(current)
    assert(result.economy.gold == 42, "already-current data must not be reset by migrate()")
    print("PlayerDataSchema.spec: already-current data passes through unchanged OK")
end

print("PlayerDataSchema.spec: all assertions passed")
