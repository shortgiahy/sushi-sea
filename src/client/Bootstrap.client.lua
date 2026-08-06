-- Bootstrap: wires all client controllers on player start, no game logic here (mirrors
-- Bootstrap.server.lua). FishingController (M3) and BoatCookController (M4) are filled in;
-- WeatherClient stays unwired until M13 — requiring+init'ing an empty scaffold that returns `{}`
-- with no init() would error.
local FishingController = require(script.Parent.Controllers.FishingController)
local BoatCookController = require(script.Parent.Controllers.BoatCookController)

FishingController.init()
BoatCookController.init()
