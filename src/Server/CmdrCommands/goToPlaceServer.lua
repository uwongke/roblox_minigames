local TeleportService = game:GetService("TeleportService")

local items = {
    ["prototype"] = 11851126119;
    ["vertical-slice"] = 12147091294;
}

return function(context, players, place)
	players = players or { context.Executor }

	if not items[place] then
        return "Not a valid universe place."
	end

	context:Reply("Commencing teleport...")

	if items[place] then
		TeleportService:TeleportAsync(items[place], players)
		if game.PlaceId == items[place] then
			return "You're already here! You might end up in a different server..."
		end
	end

	return "Teleported."
end