return function (registry)
	registry:RegisterType("place", registry.Cmdr.Util.MakeEnumType("Place", {"prototype", "vertical-slice"}))
end
