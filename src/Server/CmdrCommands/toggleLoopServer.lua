local Knit = require(game.ReplicatedStorage.Packages.Knit)

return function(context)
    local newState = Knit.GetService("NewMiniGameService"):ToggleLoop()
    context:Reply("Toggled minigame loop. Loop state: " .. tostring(newState))
    Knit.GetService("NewMiniGameService").FSM.reset()
end