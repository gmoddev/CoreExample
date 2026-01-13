--[[
Not_Lowest
Sound System

Methods marked with a _ like _Method() are internal and should not be used outside of the script. I guess if you want to make it harder for yourself go ahead.
]]

local SoundService = game:GetService("SoundService")

local SoundCache = {}
SoundCache.__index = SoundCache

local MAX_FREE_PER_SIGNATURE = 15
local MAX_IDLE_TIME = 30 -- seconds

--[[
SoundCache.new()
Returns a new SoundCache instance.
Initializes caches, registries, and starts automatic garbage collection.
]]
function SoundCache.new()
	local self = setmetatable({}, SoundCache)

	self.Cache = {}
	self.Registry = {}
	self.ByName = {}

	self._Running = true
	self._Destroyed = false

	self._Paused = false
	self._Locked = false
	self._PausedByManager = {} -- [Sound] = true

	self:_BuildRegistry()

	task.spawn(function()
		while self._Running do
			task.wait(120)
			if not self._Running then
				break
			end
			self:_GC()
		end
	end)

	return self
end

--[[
SoundCache:_GC()
Internal garbage collection of unused sounds.
Destroys sounds exceeding MAX_FREE_PER_SIGNATURE.
]]
function SoundCache:_GC()
	local now = os.clock()

	for signature, pool in pairs(self.Cache) do
		while #pool.Free > MAX_FREE_PER_SIGNATURE do
			local sound = table.remove(pool.Free)
			pool.LastUsed[sound] = nil
			sound:Destroy()
		end

		--[[ Intentionally disabled
		for i = #pool.Free, 1, -1 do
			local sound = pool.Free[i]
			local lastUsed = pool.LastUsed[sound]

			if lastUsed and (now - lastUsed) > MAX_IDLE_TIME then
				table.remove(pool.Free, i)
				pool.LastUsed[sound] = nil
				sound:Destroy()
			end
		end
		]]

		if #pool.Free == 0 and next(pool.InUse) == nil then
			self.Cache[signature] = nil
		end
	end

end

--[[
SoundCache:_GetSignature(Sound)
Returns a string signature representing the unique properties of a sound.
Used for pooling and caching.
]]
function SoundCache:_GetSignature(Sound)
	return table.concat({
		Sound.SoundId or "",
		tostring(Sound.Volume),
		tostring(Sound.PlaybackSpeed),
		tostring(Sound.Looped),
		tostring(Sound.RollOffMaxDistance),
		tostring(Sound.RollOffMinDistance),
		tostring(Sound.RollOffMode)
	}, "|")
end

--[[
SoundCache:_CreateFromTemplate(Template)
Creates a new Sound instance from a template Sound.
]]
function SoundCache:_CreateFromTemplate(Template)
	local Sound = Instance.new("Sound")
	Sound.SoundId = Template.SoundId
	Sound.Volume = Template.Volume
	Sound.PlaybackSpeed = Template.PlaybackSpeed
	Sound.Looped = Template.Looped
	Sound.RollOffMaxDistance = Template.RollOffMaxDistance
	Sound.RollOffMode = Template.RollOffMode
	Sound.RollOffMinDistance = Template.RollOffMinDistance
	Sound.Parent = SoundService

	return Sound
end

--[[
SoundCache:_GetSound(Template)
Returns a pooled sound matching the template, or creates a new one.
]]
function SoundCache:_GetSound(Template)
	local Signature = self:_GetSignature(Template)

	local Pool = self.Cache[Signature]
	if not Pool then
		Pool = {
			Free = {},
			InUse = {},
			LastUsed = {}
		}
		self.Cache[Signature] = Pool
	end

	if #Pool.Free > 0 then
		local Sound = table.remove(Pool.Free)
		Pool.InUse[Sound] = true
		return Sound
	end

	local Sound = self:_CreateFromTemplate(Template)
	Pool.InUse[Sound] = true
	return Sound
end

--[[
SoundCache:_ReturnSound(Template, Sound)
Returns a sound back to its pool and stops it.
]]
function SoundCache:_ReturnSound(Template, Sound)
	local Signature = self:_GetSignature(Template)
	local Pool = self.Cache[Signature]
	if not Pool then return end

	Pool.InUse[Sound] = nil
	Sound:Stop()
	Sound.TimePosition = 0

	Pool.LastUsed[Sound] = os.clock()
	table.insert(Pool.Free, Sound)
end

--[[
SoundCache:_WrapSound(Template, Sound)
Wraps a sound instance so Destroy() returns it to the pool instead of destroying it.
]]
function SoundCache:_WrapSound(Template, Sound)
	local Released = false
	local Proxy = {}

	local Meta = {
		__index = function(_, Key)
			if Key == "Destroy" then
				return function()
					if Released then return end
					Released = true
					self:_ReturnSound(Template, Sound)
				end
			end

			if Key == "_Destroy" then
				return function()
					if Released then return end
					Released = true

					for _, pool in pairs(self.Cache) do
						pool.InUse[Sound] = nil
						pool.LastUsed[Sound] = nil
					end

					Sound:Destroy()
				end
			end

			local value = Sound[Key]
			if typeof(value) == "RBXScriptSignal" then
				return value
			end

			if Key == "Play" or Key == "Stop" or Key == "Pause" then
				return function(_, ...)
					return Sound[Key](Sound, ...)
				end
			end

			if Key == "IsA" then
				return function(_, class)
					return Sound:IsA(class)
				end
			end

			return value
		end,

		__newindex = function(_, Key, Value)
			if Released then return end
			Sound[Key] = Value
		end
	}

	return setmetatable(Proxy, Meta)
end

--[[
SoundCache:_BuildRegistry()
Builds the initial registry of sounds grouped by folder and name.
]]
function SoundCache:_BuildRegistry()
	self.Registry = {}
	self.ByName = {}

	local function Scan(Container, GroupName)
		for _, Obj in ipairs(Container:GetChildren()) do
			if Obj:IsA("Sound") then
				-- group registry
				if GroupName then
					self.Registry[GroupName] = self.Registry[GroupName] or {}
					table.insert(self.Registry[GroupName], Obj)
				end

				-- name registry
				self.ByName[Obj.Name] = self.ByName[Obj.Name] or {}
				table.insert(self.ByName[Obj.Name], Obj)

			else
				Scan(Obj, Obj.Name)
			end
		end
	end

	Scan(SoundService)
	--// Not really nessesary, but if you add more sounds after startup, it'll be there.
	SoundService.ChildAdded:Connect(function()
		Scan(SoundService)
	end)
end

--[[
SoundCache:_PickFromGroup(GroupName)
Returns a random sound from a registered group.
]]
function SoundCache:_PickFromGroup(GroupName)
	local Group = self.Registry[GroupName]
	if not Group or #Group == 0 then
		warn("Sound group not found:", GroupName)
		return nil
	end

	return Group[math.random(1, #Group)]
end

--[[
SoundCache:GetDebugStats()
Returns debug stats about sound cache usage.
]]
function SoundCache:GetDebugStats()
	local stats = {
		Signatures = 0,
		TotalSounds = 0,
		InUse = 0,
		Free = 0,
		Playing = 0,
		Paused = 0,

		PausedGlobally = self._Paused,
		Locked = self._Locked,
		Destroyed = self._Destroyed,
	}

	for _, pool in pairs(self.Cache) do
		stats.Signatures += 1

		for sound in pairs(pool.InUse) do
			stats.InUse += 1
			stats.TotalSounds += 1

			if sound.IsPlaying then
				stats.Playing += 1
			else
				stats.Paused += 1
			end
		end

		for _, sound in ipairs(pool.Free) do
			stats.Free += 1
			stats.TotalSounds += 1
		end
	end

	return stats
end
--// PUBLIC API

--[[
SoundCache:PlaySound(Template, Parent)
Plays a sound template and returns the wrapped handle.
Parent optional, defaults to SoundService.
]]
function SoundCache:PlaySound(Template, Parent)
	if self._Destroyed then
		warn("SoundCache is destroyed")
		return
	end

	if self._Locked then
		return
	end

	local Handle = self:GetSound(Template, Parent)
	if not Handle then
		return
	end

	Handle:Play()

	if not Template.Looped then
		task.spawn(function()
			Handle.Ended:Wait()
			Handle:Destroy()
		end)
	end

	return Handle
end

--[[
SoundCache:GetSound(Template, Parent)
Returns a pooled sound (wrapped) from template.
Pauses immediately if globally paused.
]]
function SoundCache:GetSound(Template, Parent)
	if self._Destroyed or self._Locked then
		return
	end

	local Sound = self:_GetSound(Template)
	Sound.Parent = Parent or SoundService

	-- If globally paused, pause immediately
	if self._Paused then
		Sound:Pause()
		self._PausedByManager[Sound] = true
	end

	return self:_WrapSound(Template, Sound)
end

--[[
SoundCache:PlaySoundByName(GroupOrName, SoundName, Parent)
Plays a sound by group and name, or just by name if SoundName nil.
]]
function SoundCache:PlaySoundByName(GroupOrName, SoundName, Parent)
	local Template

	--  PlaySoundByName("Weapons", "Gunshot")
	if SoundName then
		local Group = self.Registry[GroupOrName]
		if not Group then
			warn("Sound group not found:", GroupOrName)
			return
		end

		for _, Sound in ipairs(Group) do
			if Sound.Name == SoundName then
				Template = Sound
				break
			end
		end

		if not Template then
			warn("Sound not found in group:", GroupOrName, SoundName)
			return
		end

		-- PlaySoundByName("Gunshot")
	else
		local Sounds = self.ByName[GroupOrName]
		if not Sounds then
			warn("Sound not found:", GroupOrName)
			return
		end

		Template = Sounds[math.random(#Sounds)]
	end

	return self:PlaySound(Template, Parent)
end

--// Pausing

--[[
SoundCache:PauseAll()
Pauses all currently playing sounds managed by this cache.
]]
function SoundCache:PauseAll()
	if self._Paused or self._Destroyed then
		return
	end

	self._Paused = true

	for _, pool in pairs(self.Cache) do
		for sound in pairs(pool.InUse) do
			if sound.IsPlaying then
				sound:Pause()
				self._PausedByManager[sound] = true
			end
		end
	end
end

--[[
SoundCache:ResumeAll()
Resumes all sounds paused by PauseAll().
]]
function SoundCache:ResumeAll()
	if not self._Paused or self._Destroyed then
		return
	end

	self._Paused = false

	for sound in pairs(self._PausedByManager) do
		if sound.Parent then
			sound:Play()
		end
	end

	table.clear(self._PausedByManager)
end
--// Locking

--[[
SoundCache:LockAll(PauseExisting)
Locks the sound cache to prevent new sounds from playing.
Optionally pauses existing sounds.
]]
function SoundCache:LockAll(PauseExisting)
	if self._Locked or self._Destroyed then
		return
	end

	self._Locked = true

	if PauseExisting then
		self:PauseAll()
	end
end

--[[
SoundCache:UnlockAll(resume)
Unlocks the sound cache. Optionally resumes previously paused sounds.
]]
function SoundCache:UnlockAll(resume)
	if not self._Locked or self._Destroyed then
		return
	end

	self._Locked = false

	if resume then
		self:ResumeAll()
	end
end

--// Add sounds in post

--[[
SoundCache:AddToRegistry(Object, ForcedGroupName)
Object: Folder or Sound instance
ForcedGroupName: string (optional)
Adds sounds to the registry at runtime.
]]
function SoundCache:AddToRegistry(Object, ForcedGroupName)
	if self._Destroyed then
		return
	end

	local function RegisterSound(Sound, GroupName)
		if GroupName then
			local group = self.Registry[GroupName]
			if not group then
				group = {}
				self.Registry[GroupName] = group
			end

			for _, existing in ipairs(group) do
				if existing == Sound then
					break
				end
			end

			if not table.find(group, Sound) then
				table.insert(group, Sound)
			end
		end

		local nameList = self.ByName[Sound.Name]
		if not nameList then
			nameList = {}
			self.ByName[Sound.Name] = nameList
		end

		if not table.find(nameList, Sound) then
			table.insert(nameList, Sound)
		end
	end

	local function Scan(Container, GroupName)
		for _, obj in ipairs(Container:GetChildren()) do
			if obj:IsA("Sound") then
				RegisterSound(obj, GroupName)
			else
				Scan(obj, GroupName or obj.Name)
			end
		end
	end

	if Object:IsA("Sound") then
		RegisterSound(Object, ForcedGroupName or (Object.Parent and Object.Parent.Name))
	else
		Scan(Object, ForcedGroupName)
	end
end

--// This is here purely for people who say "Oh well its not professionally made bcz it doesnt cleanup on shutdown".. Thats what shutting down the server is for.
--// Its not required for normal operation and I didnt build this to be recycled, but its here if you want it. Although using it more than once is honestly counter productive
function SoundCache:Destroy()
	if self._Destroyed then
		return
	end
	self._Destroyed = true
	self._Running = false

	table.clear(self._PausedByManager)

	for _, pool in pairs(self.Cache) do
		for sound in pairs(pool.InUse) do
			sound:Stop()
			sound:Destroy()
		end

		for _, sound in ipairs(pool.Free) do
			sound:Stop()
			sound:Destroy()
		end
	end

	table.clear(self.Cache)
	table.clear(self.Registry)
	table.clear(self.ByName)
end


return SoundCache.new()