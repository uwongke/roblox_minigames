local Knit = require(game.ReplicatedStorage.Packages.Knit)
local MiniGameService = Knit.GetService("MiniGameService")

return function(context, minigameName)
    if MiniGameService then
        MiniGameService.FORCE_MINIGAME = minigameName
    	context:Reply("Forced minigame: " .. minigameName)
    end
end