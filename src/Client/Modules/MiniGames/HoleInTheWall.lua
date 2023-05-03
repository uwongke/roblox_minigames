local module = {}
module.__index = module

function module:Init(newJanitor)
    -- return display info
    return "Hole In The Wall!",
    "Make it through the obstacle course where: with each set of doors, only one will let you through. Watch out for what might be behind each door!",
    "rbxassetid://12716822940"
end

function module:Start(janitor)
    
end

function module:Destroy()
    self = nil
end

return module