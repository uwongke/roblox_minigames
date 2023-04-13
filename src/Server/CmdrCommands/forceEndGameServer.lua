local Knit = require(game.ReplicatedStorage.Packages.Knit)
local MiniGameService = Knit.GetService("MiniGameService")

return function(context)
    if MiniGameService then
        if MiniGameService.CurrentGame then
            MiniGameService.CurrentGame.GameOver.Value = true
        end
    end
end