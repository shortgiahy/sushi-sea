-- PlayerDataSchema: versioned player data shape + migration chain (PRD §7.3) — pure, no Roblox services
local PlayerDataSchema = {}

local SCHEMA_VERSION = 7
local TUTORIAL_LOAN_DEFAULT = 500

-- Hardcoded here rather than requiring RodConfig (ReplicatedStorage.Config) — this module is
-- deliberately pure/no-Roblox-services (see header), same reasoning TUTORIAL_LOAN_DEFAULT above
-- is a bare number instead of pulling EconomyConfig in.
local DEFAULT_ROD_ID = "starter_rod"

export type SkillEntry = { level: number, xp: number }

export type Skills = {
    fishing: SkillEntry,
    cooking: SkillEntry,
    sailing: SkillEntry,
    hospitality: SkillEntry,
    purchasing: SkillEntry,
}

-- `dryAgeMutation` (M15, PRD §4 "Dry aging"): nil for an ordinarily-caught fish; set to the
-- resolved multiplier (aging curve × rare mutation roll, DryAgingLocker.lua) only when this entry
-- was just pulled from the aging locker (Player_PullFromLocker) back into raw inventory. Carried
-- forward onto the CookedPortion it produces so PlateValueResolver's existing optional
-- `dryAgeMutation` input (M5) finally receives a real value instead of always defaulting to
-- DRY_AGE_MUTATION_BASELINE.
export type InventoryFish = { id: string, species: string, caughtAt: number, dryAgeMutation: number? }

-- Cooked output of ConversionModule.cook (M4, docs/design/cook-verb.md §5). Kept as its own
-- array rather than folded into `inventory`, mirroring how `agingLocker` is already kept separate
-- from the spoilage track: a portion starts its own freshness clock at the cut, distinct from the
-- parent fish's `caughtAt` clock, so it needs its own timestamp field rather than reusing one.
export type CookedPortion = { id: string, species: string, grade: string, cookedAt: number, dryAgeMutation: number? }

export type AgingFish = { slot: number, species: string, placedAt: number }

export type Trophy = { species: string, mountedAt: number }

-- Hired NPC staff (M11, PRD §4 "Staff"). `rarity` indexes RestaurantConfig.STAFF_RARITY, which
-- caps quality by tier per §4 ("staff cooking quality is capped by tier, not by the player").
-- `hiredAt` drives the tenure-based accuracy bonus ("the longer you keep them"). Headcount is
-- `#staff`, not a separately-stored counter — one source of truth, same reasoning `storage.tier`
-- already applies to keep spoilage-multiplier lookups from a single field.
export type StaffMember = { id: string, rarity: string, hiredAt: number }

export type Restaurant = {
    tier: number,
    staff: { StaffMember },
    prestigePoints: number,
    trophies: { Trophy },
}

-- Storage capacity/spoilage-slowdown upgrade line (M8, PRD §12 Thread #5 partial resolution
-- 2026-09-04) — its own Purchasing category, kept separate from `restaurant.tier` (the
-- brick-and-mortar upgrade line) exactly as PRD §5's sink stack lists "storage capacity" and
-- "restaurant tiers" as distinct categories. `tier` indexes EconomyConfig.STORAGE_TIERS.
export type Storage = {
    tier: number,
}

-- Dry-aging locker equipment tier (M15, PRD §4: "opt-in, equipment-gated, limited capacity") —
-- yet another distinct Purchasing category from `storage.tier`/`restaurant.tier`. `tier` indexes
-- AgingConfig.LOCKER_TIERS; 0 means no locker purchased yet (agingLocker must stay empty).
export type AgingLockerEquipment = {
    tier: number,
}

-- Fishing rod ownership/loadout (rod-seller NPC, 2026-09-04). `ownedRodIds` is a set (presence,
-- not count — a rod is a one-time durable purchase, never consumed or stacked, same shape
-- `restaurant.trophies`-style arrays weren't right for: there's nothing per-copy to store).
export type Equipment = {
    ownedRodIds: { [string]: boolean },
    equippedRodId: string,
}

export type Economy = {
    cash: number,
    offlineSnapshotAt: number,
    offlineStockCount: number,
    tutorialLoanOwed: number,
}

export type Meta = {
    schemaVersion: number,
    firstJoinAt: number,
    lastJoinAt: number,
}

export type PlayerData = {
    skills: Skills,
    inventory: { InventoryFish },
    cookedPortions: { CookedPortion },
    agingLocker: { AgingFish },
    agingLockerEquipment: AgingLockerEquipment,
    restaurant: Restaurant,
    storage: Storage,
    economy: Economy,
    equipment: Equipment,
    meta: Meta,
}

PlayerDataSchema.SCHEMA_VERSION = SCHEMA_VERSION

local function _newSkillEntry(): SkillEntry
    return { level = 1, xp = 0 }
end

function PlayerDataSchema.newDefault(): PlayerData
    return {
        skills = {
            fishing = _newSkillEntry(),
            cooking = _newSkillEntry(),
            sailing = _newSkillEntry(),
            hospitality = _newSkillEntry(),
            purchasing = _newSkillEntry(),
        },
        inventory = {},
        cookedPortions = {},
        agingLocker = {},
        agingLockerEquipment = {
            tier = 0,
        },
        restaurant = {
            tier = 0,
            staff = {},
            prestigePoints = 0,
            trophies = {},
        },
        storage = {
            tier = 0,
        },
        economy = {
            cash = 0,
            offlineSnapshotAt = 0,
            offlineStockCount = 0,
            tutorialLoanOwed = TUTORIAL_LOAN_DEFAULT,
        },
        equipment = {
            ownedRodIds = { [DEFAULT_ROD_ID] = true },
            equippedRodId = DEFAULT_ROD_ID,
        },
        meta = {
            schemaVersion = SCHEMA_VERSION,
            firstJoinAt = 0,
            lastJoinAt = 0,
        },
    }
end

local function _mergeSkillEntry(old: any, default: SkillEntry): SkillEntry
    if type(old) ~= "table" then
        return default
    end
    return {
        level = if type(old.level) == "number" then old.level else default.level,
        xp = if type(old.xp) == "number" then old.xp else default.xp,
    }
end

-- Version-indexed migration chain: MIGRATIONS[n] upgrades a version-n table to version n+1.
-- Only version 0 (unversioned/legacy data, or nothing saved yet) exists today. Adding schema
-- version 2 later is a pure addition: define MIGRATIONS[1], bump SCHEMA_VERSION, done — the
-- while-loop in migrate() below walks the chain regardless of how many steps it needs.
local MIGRATIONS: { [number]: (old: any) -> PlayerData } = {}

MIGRATIONS[0] = function(old: any): PlayerData
    old = if type(old) == "table" then old else {}
    local defaults = PlayerDataSchema.newDefault()

    local oldSkills = if type(old.skills) == "table" then old.skills else {}
    local skills: Skills = {
        fishing = _mergeSkillEntry(oldSkills.fishing, defaults.skills.fishing),
        cooking = _mergeSkillEntry(oldSkills.cooking, defaults.skills.cooking),
        sailing = _mergeSkillEntry(oldSkills.sailing, defaults.skills.sailing),
        hospitality = _mergeSkillEntry(oldSkills.hospitality, defaults.skills.hospitality),
        purchasing = _mergeSkillEntry(oldSkills.purchasing, defaults.skills.purchasing),
    }

    -- `staff` is deliberately not populated here — it arrives in MIGRATIONS[3] (v3 -> v4), same
    -- "later step fills in a later addition" shape as `storage` arriving via MIGRATIONS[2].
    local oldRestaurant = if type(old.restaurant) == "table" then old.restaurant else {}
    local restaurant = {
        tier = if type(oldRestaurant.tier) == "number" then oldRestaurant.tier else defaults.restaurant.tier,
        prestigePoints = if type(oldRestaurant.prestigePoints) == "number"
            then oldRestaurant.prestigePoints
            else defaults.restaurant.prestigePoints,
        trophies = if type(oldRestaurant.trophies) == "table"
            then oldRestaurant.trophies
            else defaults.restaurant.trophies,
    }

    local oldEconomy = if type(old.economy) == "table" then old.economy else {}
    local economy = {
        gold = if type(oldEconomy.gold) == "number" then oldEconomy.gold else 0,
        offlineSnapshotAt = if type(oldEconomy.offlineSnapshotAt) == "number"
            then oldEconomy.offlineSnapshotAt
            else defaults.economy.offlineSnapshotAt,
        offlineStockCount = if type(oldEconomy.offlineStockCount) == "number"
            then oldEconomy.offlineStockCount
            else defaults.economy.offlineStockCount,
        tutorialLoanOwed = if type(oldEconomy.tutorialLoanOwed) == "number"
            then oldEconomy.tutorialLoanOwed
            else defaults.economy.tutorialLoanOwed,
    }

    local oldMeta = if type(old.meta) == "table" then old.meta else {}

    return {
        skills = skills,
        inventory = if type(old.inventory) == "table" then old.inventory else defaults.inventory,
        cookedPortions = if type(old.cookedPortions) == "table" then old.cookedPortions else defaults.cookedPortions,
        agingLocker = if type(old.agingLocker) == "table" then old.agingLocker else defaults.agingLocker,
        restaurant = restaurant,
        economy = economy,
        meta = {
            schemaVersion = 1,
            firstJoinAt = if type(oldMeta.firstJoinAt) == "number"
                then oldMeta.firstJoinAt
                else defaults.meta.firstJoinAt,
            lastJoinAt = if type(oldMeta.lastJoinAt) == "number" then oldMeta.lastJoinAt else defaults.meta.lastJoinAt,
        },
    }
end

-- v1 -> v2 (M4): the only change is the addition of cookedPortions (see the CookedPortion type
-- comment above) — everything else in a v1 shape already matches v2, so this is a pure addition
-- exactly as the MIGRATIONS-chain comment above promised.
MIGRATIONS[1] = function(old: any): PlayerData
    old.cookedPortions = if type(old.cookedPortions) == "table" then old.cookedPortions else {}
    old.meta.schemaVersion = 2
    return old
end

-- v2 -> v3 (M8): adds the `storage` section (see the Storage type comment above) — another pure
-- addition, same shape as v1 -> v2's cookedPortions arrival.
MIGRATIONS[2] = function(old: any): PlayerData
    local oldStorage = if type(old.storage) == "table" then old.storage else {}
    old.storage = {
        tier = if type(oldStorage.tier) == "number" then oldStorage.tier else 0,
    }
    old.meta.schemaVersion = 3
    return old
end

-- v3 -> v4 (M11): replaces `restaurant.staffHeadcount` with `restaurant.staff` (see StaffMember
-- type comment above) — a real roster instead of a bare count, since deterministic per-staff
-- performance needs each member's own `rarity`/`hiredAt`. Any pre-existing `staffHeadcount` value
-- is dropped, not converted to synthetic staff entries — a v3 save is always 0 headcount today
-- (M11 didn't exist yet to hire anyone), so there is nothing real to preserve.
MIGRATIONS[3] = function(old: any): PlayerData
    old.restaurant.staffHeadcount = nil
    old.restaurant.staff = if type(old.restaurant.staff) == "table" then old.restaurant.staff else {}
    old.meta.schemaVersion = 4
    return old
end

-- v4 -> v5 (M15): adds `agingLockerEquipment` (see its type comment above) — a pure addition, same
-- shape as v2 -> v3's `storage` arrival. `inventory`/`cookedPortions` entries don't need a
-- migration step for their new optional `dryAgeMutation` field — it's nil-safe by construction
-- (every reader already treats a missing/nil value as "no mutation," PlateValueResolver's existing
-- baseline-default behavior from M5).
MIGRATIONS[4] = function(old: any): PlayerData
    local oldAgingLockerEquipment = if type(old.agingLockerEquipment) == "table" then old.agingLockerEquipment else {}
    old.agingLockerEquipment = {
        tier = if type(oldAgingLockerEquipment.tier) == "number" then oldAgingLockerEquipment.tier else 0,
    }
    old.meta.schemaVersion = 5
    return old
end

-- v5 -> v6 (currency rename, 2026-09-04): Giahy wants the currency displayed as dollars ("$")
-- rather than "gold," Dave the Diver style — renames `economy.gold` to `economy.cash`, same
-- pure-rename shape as v3 -> v4's staffHeadcount -> staff rename above.
MIGRATIONS[5] = function(old: any): PlayerData
    local oldEconomy = if type(old.economy) == "table" then old.economy else {}
    old.economy.cash = if type(oldEconomy.cash) == "number"
        then oldEconomy.cash
        elseif type(oldEconomy.gold) == "number" then oldEconomy.gold
        else 0
    old.economy.gold = nil
    old.meta.schemaVersion = 6
    return old
end

-- v6 -> v7 (rod-seller NPC, 2026-09-04): adds `equipment` (see its type comment above) — a pure
-- addition, same shape as v2 -> v3's `storage` arrival. Every existing player starts owning and
-- wearing the free starter rod, same as if they were new — there is nothing to preserve from a
-- version that had no concept of rods at all.
MIGRATIONS[6] = function(old: any): PlayerData
    local oldEquipment = if type(old.equipment) == "table" then old.equipment else {}
    local oldOwnedRodIds = if type(oldEquipment.ownedRodIds) == "table" then oldEquipment.ownedRodIds else {}
    oldOwnedRodIds[DEFAULT_ROD_ID] = true
    old.equipment = {
        ownedRodIds = oldOwnedRodIds,
        equippedRodId = if type(oldEquipment.equippedRodId) == "string"
            then oldEquipment.equippedRodId
            else DEFAULT_ROD_ID,
    }
    old.meta.schemaVersion = 7
    return old
end

-- Never silently overwrite (PRD §7.3, §8 DataStore rules): walk the chain from whatever version
-- the saved data claims up to SCHEMA_VERSION. Missing/invalid version data is treated as version 0.
function PlayerDataSchema.migrate(raw: any): PlayerData
    if raw == nil then
        return PlayerDataSchema.newDefault()
    end

    local data = raw
    local version = if type(data) == "table"
            and type(data.meta) == "table"
            and type(data.meta.schemaVersion) == "number"
        then data.meta.schemaVersion
        else 0

    while version < SCHEMA_VERSION do
        local step = MIGRATIONS[version]
        if not step then
            warn(
                "[PlayerDataSchema] no migration registered from schema version "
                    .. tostring(version)
                    .. " — resetting to default"
            )
            return PlayerDataSchema.newDefault()
        end
        data = step(data)
        version = data.meta.schemaVersion
    end

    return data
end

return PlayerDataSchema
