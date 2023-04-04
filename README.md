# Suit Up Boilerplate
This boilerplate should serve as a solid basis for starting a new project. It has the latest version of Knit established, as well as core Controllers and Services written by *Aaron Jay (seyai)* that handle player save data, character spawning, and basic client-server communication.

This README aims to introduce some patterns found in this boilerplate, as well as how to best take advantage of some of the modules found in it.

UI is not included in this template.

# Item Shop
An Item Shop exists via `ShopService.lua`, and can be invoked on both the client and server using the PurchaseItem method.

```
-- client
ShopService:PurchaseItem("TestItem", 10) -- // purchase 10 TestItem

-- server
ShopService:PurchaseItem(player, "TestItem", 10) -- // server call requires direct reference to the player object
```

# Modules
## Profile+ReplicaService (modified)
[ProfileService](https://madstudioroblox.github.io/ProfileService/) and [ReplicaService](https://madstudioroblox.github.io/ReplicaService/) are modules created by Roblox developer veteran [loleris](https://twitter.com/LM_loleris) as a way to safely store player data and reflect that data as it changes across the client-server boundary with minimal network traffic, respectively.

ReplicaService has been minimally modified by Aaron Jay (seyai) to include quality of life methods like IncrementValue when operating on numeric data.

### WriteLibs
ReplicaService features WriteLibs, which are collections of predefined functions that predictably mutate data. Updating user data using WriteLibs is preferred because they also function as RemoteEvents that can be specifically listened for on the client using ReplicaService's API. This is great for accurate updates to player state with simple implementation.

## Promises
[Promise](https://eryn.io/roblox-lua-promise/) by [evaera](https://twitter.com/evaeraevaera) is a Luau implementation of the Promise structure similar to Promise/A+, and allows for predictable timing of Roblox's asynchronous structure

### WaitFor
This RbxUtil module by sleitnick is useful Promise implementation of `WaitForChild`, and should be used when you are expecting to do something after an Instance is found.