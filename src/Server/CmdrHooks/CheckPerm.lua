local GroupService = game:GetService("GroupService")

local GROUP_TO_CHECK = 16314365
local groupsPerms = {
    ["DefaultAdmin"] = 222,
    ["DefaultDebug"] = 222,
    ["DefaultUtil"] = 222,
}

return function (registry)
	registry:RegisterHook("BeforeRun", function(context)
        return nil
        -- -- check if permission is setup for this group
        -- local cmdGroup: string = context.Group
        -- local executor: Player = context.Executor

        -- if executor.UserId == 4338714 then -- hardcoded seyai perm
        --     return nil
        -- end

        -- if groupsPerms[cmdGroup] then
        --     local executorRank = executor:GetRankInGroup(GROUP_TO_CHECK)
        --     -- check with executor
        --     if executorRank >= groupPerms[cmdGroup] then
        --         return nil
        --     end
        -- end
		
        -- return "You don't have permission to run this command"
	end)
end