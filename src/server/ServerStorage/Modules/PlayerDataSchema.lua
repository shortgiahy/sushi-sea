-- PlayerDataSchema: versioned player data shape + migration chain (PRD §7.3) — pure, no Roblox services
local PlayerDataSchema = {}

local SCHEMA_VERSION = 1
local TUTORIAL_LOAN_DEFAULT = 500

export type SkillEntry = { level: number, xp: number }

export type Skills = {
    fishing: SkillEntry,
    cooking: SkillEntry,
    sailing: SkillEntry,
    hospitality: SkillEntry,
    purchasing: SkillEntry,
}

export type InventoryFish = { id: string, species: string, caughtAt: number }

export type AgingFish = { slot: number, species: string, placedAt: number }

export type Trophy = { species: string, mountedAt: number }

export type Restaurant = {
    tier: number,
    staffHeadcount: number,
    prestigePoints: number,
    trophies: { Trophy },
}

export type Economy = {
    gold: number,
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
    agingLocker: { AgingFish },
    restaurant: Restaurant,
    economy: Economy,
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
        agingLocker = {},
        restaurant = {
            tier = 0,
            staffHeadcount = 0,
            prestigePoints = 0,
            trophies = {},
        },
        economy = {
            gold = 0,
            offlineSnapshotAt = 0,
            offlineStockCount = 0,
            tutorialLoanOwed = TUTORIAL_LOAN_DEFAULT,
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

    local oldRestaurant = if type(old.restaurant) == "table" then old.restaurant else {}
    local restaurant: Restaurant = {
        tier = if type(oldRestaurant.tier) == "number" then oldRestaurant.tier else defaults.restaurant.tier,
        staffHeadcount = if type(oldRestaurant.staffHeadcount) == "number"
            then oldRestaurant.staffHeadcount
            else defaults.restaurant.staffHeadcount,
        prestigePoints = if type(oldRestaurant.prestigePoints) == "number"
            then oldRestaurant.prestigePoints
            else defaults.restaurant.prestigePoints,
        trophies = if type(oldRestaurant.trophies) == "table"
            then oldRestaurant.trophies
            else defaults.restaurant.trophies,
    }

    local oldEconomy = if type(old.economy) == "table" then old.economy else {}
    local economy: Economy = {
        gold = if type(oldEconomy.gold) == "number" then oldEconomy.gold else defaults.economy.gold,
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
