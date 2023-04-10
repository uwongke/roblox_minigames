local t = {}
for _, v in game:GetService("ReplicatedStorage").Assets:WaitForChild("MiniGames"):GetChildren() do
    table.insert(t, v.Name)
end

return function (registry)
	registry:RegisterType("minigame", registry.Cmdr.Util.MakeEnumType("Minigame", t))
end
