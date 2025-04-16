# How to use 
Download, drag and drop CoreV3Package.rbxm into Roblox

Put models in respective places and ungroup

# Without RBXM

Create a script and localscript, put in ServerScriptService and StarterPlayerScripts

Create a folder with this hirearchy in both ReplicatedStorage and ServerScriptService
- Folder
- - Managers
- - Helpers

Clone the Example_Loader.lua and change the respective variables to the folder

# Example Manager
    return function(helpers,services)
        local Players = services.Players

        local function PlayerAdded(plr: Player)
        
        end

        return {
            PlayerAdded = PlayerAdded
        }
    end
# Example Helper
    local Players = game:GetService("Players")

    return {
        GetPlayer = function(name)
            return Players:FindFirstChild(name)
        end
    }