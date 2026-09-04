-- Placeholder headless test: proves the Lune runner can require a pure ServerStorage module and CI stays green.
-- Real economy/offline-bank/spoilage tests land alongside their modules (PRD §9); this only proves the wire works.
local ConversionModule = require("../src/server/ServerStorage/Modules/ConversionModule")
local FishTable = require("../src/server/ServerStorage/Modules/FishTable")
local OfflineBankCalculator = require("../src/server/ServerStorage/Modules/OfflineBankCalculator")

assert(type(ConversionModule) == "table", "ConversionModule must return a table, got " .. type(ConversionModule))
assert(type(FishTable) == "table", "FishTable must return a table, got " .. type(FishTable))
assert(type(OfflineBankCalculator) == "table", "OfflineBankCalculator must return a table, got " .. type(OfflineBankCalculator))

print("placeholder.spec: all pure modules load and return tables")
