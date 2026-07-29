-- Bootstrap: wires all client controllers on player start, no game logic here (mirrors
-- Bootstrap.server.lua). Only FishingController is filled in as of M3 — WeatherClient and
-- BoatCookController stay unwired until their own modules are built (M13, M4 respectively);
-- requiring+init'ing an empty scaffold that returns `{}` with no init() would error.
local FishingController = require(script.Parent.Controllers.FishingController)

FishingController.init()
