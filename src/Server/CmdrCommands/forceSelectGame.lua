return {
	Name = "force-game";
	Aliases = {};
	Description = "Forcibly pick a new minigame";
	Group = "Admin";
	AutoExec = {};
	Args = {
		{
			Type = "minigame";
			Name = "Minigame";
			Description = "Name of the minigame you want to use next";
		},
	};
}