-- Bootstrap: wires all client controllers on player start, no game logic here (mirrors
-- Bootstrap.server.lua). FishingController (M3), BoatCookController (M4), FreshnessUI (M6),
-- RestaurantUI (M10/M11), and WeatherClient (M13) are filled in.
local FishingController = require(script.Parent.Controllers.FishingController)
local BoatCookController = require(script.Parent.Controllers.BoatCookController)
local WeatherClient = require(script.Parent.Controllers.WeatherClient)
local FreshnessUI = require(script.Parent.UI.FreshnessUI)
local RestaurantUI = require(script.Parent.UI.RestaurantUI)

FishingController.init()
BoatCookController.init()
WeatherClient.init()
FreshnessUI.init()
RestaurantUI.init()
