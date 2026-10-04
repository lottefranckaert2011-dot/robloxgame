-- Startpunt van de client.

local Hud = require(script.Hud)
local Controls = require(script.Controls)
local Effects = require(script.Effects)
local Music = require(script.Music)

Hud.Init()
Controls.Init(Hud)
task.spawn(Effects.Init, Hud) -- wacht op de zalen
Music.Init(Hud, Effects)
