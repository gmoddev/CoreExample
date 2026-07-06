--[[
Handles time, updates,etc 
]]

return function(helpers,services)
	local ReplicatedStorage = services.ReplicatedStorage
	local ServerScriptService: ServerScriptService = services.ServerScriptService
	local Players: Players = services.Players
	local ServerStorage = services.ServerStorage
	--local RunService: RunService = services.RunService

	local Events = ReplicatedStorage.Remotes
	
	local ServerEvent = Instance.new("BindableFunction")
	ServerEvent.Parent = ServerScriptService
	ServerEvent.Name = "DataEvent"

	local PlayerDataFolder = ServerStorage:FindFirstChild("PlayerData") 
	if not PlayerDataFolder then
		PlayerDataFolder = Instance.new("Folder")
		PlayerDataFolder.Parent = ServerStorage
		PlayerDataFolder.Name = "PlayerData"
	end

	local TableModule = helpers.SharedTable

	--[[
		Syncs variables from table to a parent: instance
	]]	
	local SyncValues: "function | Table: table, Parent: instance" = TableModule.SyncValues

	local Update = Events.Update

	local GlobalPlayerData = {} --// intentionally unused.
	local Cleaning = {} :: {plr: Player?}

	local ds2 = helpers.DataStore2
	--// Default Values
	local DefaultValues = {
		Money = 2000;
		Bank = 0;
		
		OwnedVehicles = {};
		
		Time = 0;

		HasBankAccount = false;
	
		Version = 1;
	}
	
	for i,v in pairs(DefaultValues) do
		ds2.Combine("CoreData",i)
	end
	
	--// Values that are allowed to be fully replicated and show for all players (Via game.Players.Player.Data)
	local AllowFullReplication = { --// actual scope doesnt matter
		["Money"] = 0;
		["Bank"] = 0;
		["Time"] = 0
		
	}
	--// Items that are hidden from the player
	local Hidden = {
		["Version"] = 0;
	}
	
	local function GetDS(plr)
		local i = {}
		
		for index,v in pairs(DefaultValues) do
			i[index] = ds2(index,plr)
		end
		return i
	end

	local function GetType(value)
		local typ = typeof(value)	

		if typ == "table" then
			return "Folder"
		elseif typ == "string" then
			return "StringValue"
		elseif typ == "boolean" then
			return "BoolValue"
		else
			return "NumberValue"
		end
	end


	--[[  
	Used for initial setup of first-time joiners  
	]]  
	local function PlayerAdded(plr: Player)  
		local DataStores = GetDS(plr)
		local PlayerData = {}

		local ValueStorage = Instance.new("Folder")
		ValueStorage.Name = "Data"
		ValueStorage.Parent = plr

		local ServerDataFolder = Instance.new("Folder")
		ServerDataFolder.Name = tostring(plr.UserId)
		ServerDataFolder.Parent = PlayerDataFolder

		for Key, DS in pairs(DataStores) do
			local Default = DefaultValues[Key]
			local ValueObject = nil
			local CurrentValue

			if typeof(Default) == "table" then
				CurrentValue = DS:GetTable(Default)
			else
				CurrentValue = DS:Get(Default)
			end

			PlayerData[Key] = CurrentValue

			local ServerReplicatedObject

			if typeof(CurrentValue) == "table" then
				ServerReplicatedObject = Instance.new("Folder")
				ServerReplicatedObject.Name = Key
				ServerReplicatedObject.Parent = ServerDataFolder
				SyncValues(CurrentValue, ServerReplicatedObject)
			else
				ServerReplicatedObject = Instance.new(GetType(CurrentValue))
				ServerReplicatedObject.Name = Key
				ServerReplicatedObject.Value = CurrentValue
				ServerReplicatedObject.Parent = ServerDataFolder
			end

			if AllowFullReplication[Key] and not Hidden[Key] then
				if typeof(CurrentValue) == "table" then
					ValueObject = Instance.new("Folder")
					ValueObject.Name = Key
					ValueObject.Parent = ValueStorage
					SyncValues(CurrentValue, ValueObject)
				else
					ValueObject = Instance.new(GetType(CurrentValue))
					ValueObject.Name = Key
					ValueObject.Value = CurrentValue
					ValueObject.Parent = ValueStorage
				end
			else
				if not Hidden[Key] then
					Update:FireClient(plr, Key, CurrentValue)
				end
			end

			DS:OnUpdate(function(NewVal)
				PlayerData[Key] = NewVal

				if typeof(NewVal) == "table" and typeof(ServerReplicatedObject) == "Folder" then
					SyncValues(NewVal, ServerReplicatedObject)
				elseif ServerReplicatedObject:IsA("ValueBase") then
					ServerReplicatedObject.Value = NewVal
				end

				if ValueObject then
					if typeof(NewVal) == "table" and typeof(ValueObject) == "Folder" then
						SyncValues(NewVal, ValueObject)
					elseif ValueObject:IsA("ValueBase") then
						ValueObject.Value = NewVal
					end
				end

				if Key ~= "Time" then
					Update:FireClient(plr, Key, NewVal)
				end
			end)

			if ServerReplicatedObject:IsA("ValueBase") then
				ServerReplicatedObject:GetPropertyChangedSignal("Value"):Connect(function()

					local NewVal = ServerReplicatedObject.Value

					if tostring(ServerReplicatedObject.Name) == tostring(NewVal) then
						warn("Change ignored: value equals name")
						return
					end

					if NewVal == DS:Get() then
						return
					end

					PlayerData[Key] = NewVal
					DS:Set(NewVal)
				end)

			elseif ServerReplicatedObject:IsA("Folder") then
				for _, child in pairs(ServerReplicatedObject:GetChildren()) do
					if child:IsA("ValueBase") then
						child:GetPropertyChangedSignal("Value"):Connect(function()
							warn("Detected Change", child)

							local newTable = {}
							local SkipUpdate = true

							for _, sub in pairs(ServerReplicatedObject:GetChildren()) do
								if sub:IsA("ValueBase") then
									newTable[sub.Name] = sub.Value
									-- Check if the value is literally the name, e.g. "Health" = "Health"
									if tostring(sub.Name) ~= tostring(sub.Value) then
										SkipUpdate = false
									end
								end
							end

							if SkipUpdate then
								warn("Change ignored: all values match their names")
								return
							end

							PlayerData[Key] = newTable
							DS:Set(newTable)
						end)
					end
				end
			end

		end
		
		GlobalPlayerData[plr] = PlayerData

		local timekeeper = task.spawn(function()
			while task.wait(1) do
				if not plr or not plr.Parent then break end
				DataStores["Time"]:Increment(1)
			end
		end)

		plr.Destroying:Connect(function()
			if Cleaning[plr] then
				return
			end
			
			Cleaning[plr] = true
			
			task.cancel(timekeeper)
			local folder = ServerStorage:FindFirstChild("PlayerData")
			if folder then
				local PlayerFolder = folder:FindFirstChild(tostring(plr.UserId))
				if PlayerFolder then
					PlayerFolder:Destroy()
				end
			end
			
			Cleaning[plr] = false
		end)
	end

	Update.OnServerEvent:Connect(function(plr) --// Assume hacker
		if helpers.Anticheat and helpers.Anticheat.Log then
			helpers.Anticheat:Log(plr)
		end
	end)

	game:BindToClose(function()
		for i,plr in ipairs(Players:GetPlayers()) do
			ds2.SaveAll(plr) --// We use .SaveAll instead of Save, because this wont error
		end
		task.wait(2)
	end)

	return {["PlayerAdded"] = PlayerAdded}
end