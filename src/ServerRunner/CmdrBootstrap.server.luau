local ServerStorage = game:GetService("ServerStorage")
local Cmdr = require(ServerStorage.Packages.Cmdr)

Cmdr:RegisterDefaultCommands({"Help", "DefaultUtil"})
Cmdr:RegisterCommandsIn(ServerStorage.CmdrCommands)
Cmdr:RegisterHooksIn(ServerStorage.CmdrHooks)
Cmdr:RegisterTypesIn(ServerStorage.CmdrTypes)