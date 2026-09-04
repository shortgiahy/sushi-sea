-- Bootstrap: wires all client controllers on player start, no game logic here (mirrors
-- Bootstrap.server.lua). FishingController (M3), BoatCookController (M4), FreshnessUI (M6), and
-- RestaurantUI (M10/M11) are filled in; WeatherClient stays unwired until M13 — requiring+init'ing
-- an empty scaffold that returns `{}` with no init() would error.
local FishingController = require(script.Parent.Controllers.FishingController)
local BoatCookController = require(script.Parent.Controllers.BoatCookController)
local FreshnessUI = require(script.Parent.UI.FreshnessUI)
local RestaurantUI = require(script.Parent.UI.RestaurantUI)

FishingController.init()
BoatCookController.init()
FreshnessUI.init()
RestaurantUI.init()
