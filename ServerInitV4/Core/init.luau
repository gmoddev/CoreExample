--[[
	Not_Lowest
	Version: 4.2
	Last Updated: 07/06/26 3:11am
	
	7/06/26 - Made load order explicit with Helpers->Middleware->Managers
]]

-- No check because of the return
--!nocheck
local RunService = game:GetService("RunService")

local IsServer = RunService:IsServer()
local COSText = IsServer and "SERVER" or "CLIENT"

local OldWarn = warn
local warn = function(...)
	OldWarn(`[{COSText}]`, ...)
end

local RuntimeModule = script:FindFirstChild("RunTime")
local RuntimeSuccess, Runtime = xpcall(function()
	if not RuntimeModule then
		return {
			Loaded = false,
			FailureReason = "Core RunTime module is missing",
		}
	end

	return require(RuntimeModule)
end, function(Error)
	return debug.traceback(tostring(Error), 2)
end)

if not RuntimeSuccess then
	Runtime = {
		Loaded = false,
		FailureReason = ("Core RunTime module failed to load\n%s"):format(tostring(Runtime)),
	}
elseif type(Runtime) ~= "table" then
	Runtime = {
		Loaded = false,
		FailureReason = "Core RunTime module returned an invalid runtime table",
	}
end

local CoreModule = {
	RuntimeLoaded = Runtime.Loaded == true,
	RuntimeFailureReason = Runtime.FailureReason,
}

if not Runtime.Loaded then
	function CoreModule.new()
		warn(Runtime.FailureReason or "Core RunTime module failed to load")
		return nil
	end

	setmetatable(CoreModule, {
		__call = function(_, ...)
			return CoreModule.new(...)
		end,
	})

	return CoreModule
end

local LoggerFactory = Runtime.Logger
local Loader = Runtime.Loader
local Lifecycle = Runtime.Lifecycle
local ServicesFactory = Runtime.Services
local SharedPublisher = Runtime.SharedPublisher
local Promise = Runtime.Promise

local Core = {}
Core.__index = Core

local function GetRegistryValues(Registry, RegistryName, ...)
	local Count = select("#", ...)

	if Count == 0 then
		return Registry
	end

	local Results = {}

	for Index = 1, Count do
		local Name = select(Index, ...)
		local Value = Registry[Name]

		if Value == nil then
			warn(RegistryName, tostring(Name), "has not been loaded")
			return nil
		end

		Results[Index] = Value
	end

	return table.unpack(Results, 1, Count)
end

function Core.new(Root, Config)
	Config = Config or {}

	if typeof(Root) ~= "Instance" then
		warn("Expected a root Instance containing Helpers, Middleware, and Managers")
		return nil
	end

	local self = setmetatable({
		Root = Root,
		Config = Config,

		Helpers = {},
		Middleware = {},
		Managers = {},
		Settings = {},

		State = {
			IsLoading = false,
			IsLoaded = false,
			Failed = false,
			FailureReason = nil,
		},

		_LoadedDescriptors = {},
		_LoadEvent = Instance.new("BindableEvent"),
		_LifecycleConnections = {},
		_LoadPromise = nil,
	}, Core)

	self.Logger = LoggerFactory.new(script, Config, COSText)
	self.Services = ServicesFactory.new(Promise, self.Logger)

	return self
end

function Core:GetHelper(...)
	return GetRegistryValues(self.Helpers, "Helper", ...)
end

function Core:GetMiddleware(...)
	return GetRegistryValues(self.Middleware, "Middleware", ...)
end

function Core:GetManager(...)
	return GetRegistryValues(self.Managers, "Manager", ...)
end

function Core:GetSharedRoots()
	local ReplicatedStorage = self.Services.ReplicatedStorage
	local Shared = ReplicatedStorage:FindFirstChild("Shared")

	if not Shared then
		return {}
	end

	return { Shared }
end

function Core:IsLoaded()
	return self.State.IsLoaded == true
end

function Core:WaitForLoad(Timeout)
	if self.State.IsLoaded then
		return true, self
	end

	if self.State.Failed then
		return false, self.State.FailureReason
	end

	local WaitingThread = coroutine.running()
	local Finished = false
	local Connection

	Connection = self._LoadEvent.Event:Connect(function()
		if Finished then
			return
		end

		Finished = true
		task.spawn(WaitingThread)
	end)

	if Timeout ~= nil then
		task.delay(Timeout, function()
			if Finished then
				return
			end

			Finished = true
			task.spawn(WaitingThread)
		end)
	end

	coroutine.yield()

	if Connection then
		Connection:Disconnect()
	end

	if self.State.IsLoaded then
		return true, self
	end

	if self.State.Failed then
		return false, self.State.FailureReason
	end

	return false, "Timed out while waiting for Core to load"
end

function Core:Start()
	if self.State.IsLoaded then
		self.Logger:Warn("Start called after Core was already loaded")
		return self
	end

	if self.State.IsLoading then
		self:WaitForLoad()
		return self
	end

	self.State.IsLoading = true
	self.Logger:Stage("Initializing", self.Root:GetFullName())

	self._LoadPromise = Promise.try(function()
		local Published, PublishReason = SharedPublisher.PublishServerShared(script, self.Root, self.Services, self.Logger)

		if not Published then
			return false, PublishReason
		end

		local SharedReady, SharedReason = SharedPublisher.WaitForServerShared(script, self.Services, self.Logger)

		if not SharedReady then
			return false, SharedReason
		end

		local LoadResult, LoadReason = Loader.Load(self.Root, self)

		if not LoadResult then
			return false, LoadReason
		end

		return true, LoadResult
	end):catch(function(Reason)
		return false, tostring(Reason)
	end)

	local PromiseResolved, LoadSucceeded, Result = self._LoadPromise:await()

	if not PromiseResolved or not LoadSucceeded then
		self.State.IsLoading = false
		self.State.IsLoaded = false
		self.State.Failed = true
		self.State.FailureReason = Result or "Core load failed"
		self.Logger:Failure(self.State.FailureReason)
		self._LoadEvent:Fire()
		return self
	end

	self._LoadedDescriptors = Result.Descriptors

	local Finalized, FinalizeReason = xpcall(function()
		self._LifecycleConnections = Lifecycle.Bind(self, Result.Hooks)

		local RuntimeRunService = self.Services.RunService
		local SideName = RuntimeRunService:IsServer() and "Server" or "Client"

		self.Root:SetAttribute(("%s-Loaded"):format(SideName), true)
		SharedPublisher.MarkServerLoaded(script, self.Services)
	end, function(Error)
		return debug.traceback(tostring(Error), 2)
	end)

	if not Finalized then
		self.State.IsLoading = false
		self.State.IsLoaded = false
		self.State.Failed = true
		self.State.FailureReason = tostring(FinalizeReason)
		self.Logger:Failure(self.State.FailureReason)
		self._LoadEvent:Fire()
		return self
	end

	self.State.IsLoading = false
	self.State.IsLoaded = true

	self._LoadEvent:Fire()
	self.Logger:Stage("Successfully completed load")

	return self
end

function Core:Destroy()
	for _, Connection in ipairs(self._LifecycleConnections) do
		Connection:Disconnect()
	end

	self._LifecycleConnections = {}
	self._LoadEvent:Destroy()
end

function CoreModule.new(Root, Config)
	local RuntimeInstance = Core.new(Root, Config)

	if not RuntimeInstance then
		return nil
	end

	if not Config or Config.AutoStart ~= false then
		RuntimeInstance:Start()
	end

	return RuntimeInstance
end

setmetatable(CoreModule, {
	__call = function(_, Root, Config)
		return CoreModule.new(Root, Config)
	end,
})

return CoreModule
