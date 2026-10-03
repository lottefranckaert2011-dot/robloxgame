-- Startpunt van de client.

local Hud = require(script.Hud)
local Controls = require(script.Controls)
local Effects = require(script.Effects)

Hud.Init()
Controls.Init(Hud)
Effects.Init(Hud)
