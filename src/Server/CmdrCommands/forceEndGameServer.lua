local Knit = require(game.ReplicatedStorage.Packages.Knit)
local MiniGameService = Knit.GetService("MiniGameService")

return function(context)
    if MiniGameService then
        if MiniGameService._gameEndSignal then
            MiniGameService._gameEndSignal:Fire(2)
        end
    end
end