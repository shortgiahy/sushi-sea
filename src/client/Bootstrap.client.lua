-- Bootstrap: wires all client controllers on player start, no game logic here (mirrors
-- Bootstrap.server.lua). FishingController (M3), BoatCookController (M4), and FreshnessUI (M6)
-- are filled in; WeatherClient stays unwired until M13 — requiring+init'ing an empty scaffold that
-- returns `{}` with no init() would error.
local FishingController = require(script.Parent.Controllers.FishingController)
local BoatCookController = require(script.Parent.Controllers.BoatCookController)
local FreshnessUI = require(script.Parent.UI.FreshnessUI)

FishingController.init()
BoatCookController.init()
FreshnessUI.init()
