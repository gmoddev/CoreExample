# Core System

The Core system is a small runtime for loading side-specific game modules without turning `Core` into a giant central object.

Core owns:

- lazy service access
- module discovery
- dependency ordering
- helper, middleware, and manager registries
- load state
- lifecycle hooks

Core should not own game behavior. Game behavior belongs in `Helpers`, `Middleware`, and `Managers`.

## Folder Layout

The public Core module lives at:

```text
ReplicatedStorage/
  Core/
    init.luau
    RunTime/
      init.luau
      DependencyGraph.luau
      Lifecycle.luau
      LoadFailure.luau
      Loader.luau
      Logger.luau
      ManagerExtensions.luau
      ModuleCatalog.luau
      Promise.luau
      Services.luau
      SharedPublisher.luau
```

Each side has its own root:

```text
ReplicatedStorage/
  Client/
    Helpers/
    Middleware/
    Managers/

ServerScriptService/
  Server/
    Helpers/
    Middleware/
    Managers/
    Shared/
```

`Shared` is helper-only. Shared modules are injected into `core.Helpers` and are retrieved with `core:GetHelper(...)`.

There is no shared middleware or shared manager concept.

Only direct child ModuleScripts of `Helpers`, `Middleware`, and `Managers` are public modules. If a module needs private children, use a folder module:

```text
Helpers/
  InventoryView/
    init.luau
    Components/
      Slot.luau
      Tooltip.luau
```

Consumers still refer to it as `InventoryView`.

Managers can also own private extension helpers, middleware, and services. These are loaded only for that manager and are not inserted into the public Core registries.

Preferred layout:

```text
Managers/
  InventoryManager/
    init.luau
    Extension/
      Helpers/
        ItemBuilder.luau
      Middleware/
        ValidateSlot.luau
      Services/
        SlotService.luau
```

Flat layout:

```text
Managers/
  InventoryManager/
    init.luau
    Helpers/
      ItemBuilder.luau
    Middleware/
      ValidateSlot.luau
    Services/
      SlotService.luau
```

Use one layout per manager. If both `Extension/Helpers` and `Helpers`, both `Extension/Middleware` and `Middleware`, or both `Extension/Services` and `Services` exist under the same manager, Core warns and stops loading instead of guessing.

## Bootstrapping

### Server

Create a server bootstrap script and point Core at `ServerScriptService.Server`.

```lua
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local CreateCore = require(ReplicatedStorage:WaitForChild("Core"))

local core = CreateCore(ServerScriptService:WaitForChild("Server"))
core:WaitForLoad()
```

### Client

Create a client bootstrap script and point Core at `ReplicatedStorage.Client`.

```lua
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CreateCore = require(ReplicatedStorage:WaitForChild("Core"))

local core = CreateCore(ReplicatedStorage:WaitForChild("Client"))
core:WaitForLoad()
```

By default, `CreateCore(Root)` starts loading immediately.

To create Core without starting it:

```lua
local core = CreateCore(Root, {
	AutoStart = false,
})

core:Start()
```

## Module Types

Core discovers three module types:

```text
Helpers      -> core.Helpers      -> core:GetHelper(...)
Middleware   -> core.Middleware   -> core:GetMiddleware(...)
Managers     -> core.Managers     -> core:GetManager(...)
```

Core also discovers shared helpers:

```text
ReplicatedStorage/Shared  -> core.Helpers -> core:GetHelper(...)
Server/Shared             -> published into ReplicatedStorage.Shared, then loaded as helpers
```

The folder decides the module type. For example:

```text
Server/Helpers/DataStore.luau
```

becomes:

```text
Helper:DataStore
```

and is retrieved with:

```lua
local DataStore = core:GetHelper("DataStore")
```

## Shared Helpers

Shared is for helper modules that should be available through `core:GetHelper(...)`.

Replicated shared helpers can live here:

```text
ReplicatedStorage/
  Shared/
    ItemTypes.luau
    Signal.luau
```

Server-owned shared helpers can live here:

```text
ServerScriptService/
  Server/
    Shared/
      ItemTypes.luau
      Signal.luau
```

When the server starts Core, `Server/Shared` is automatically cloned into:

```text
ReplicatedStorage/
  Shared/
```

The client waits for the Core module attribute `ServerSharedLoaded` before it loads. This prevents the client from racing the server publishing step.

Shared helpers load before side-specific helpers, middleware, and managers.

Load order:

```text
1. ReplicatedStorage.Shared
2. Root.Helpers
3. Root.Middleware
4. Root.Managers
```

After publishing, `Server/Shared` is part of `ReplicatedStorage.Shared`, so both client and server use the same helper registry path:

```lua
local ItemTypes = core:GetHelper("ItemTypes")
local Signal = core:GetHelper("Signal")
```

Do not put server-private code or secrets in `Server/Shared`. It is automatically published to the client.

If a module in `Server/Shared` has the same name as one already in `ReplicatedStorage.Shared`, Core warns and stops loading instead of overwriting it.

## Module Format

Simple module:

```lua
return function(core)
	local Services = core.Services
	local ReplicatedStorage = Services.ReplicatedStorage

	return {
		ReplicatedStorage = ReplicatedStorage,
	}
end
```

Module with metadata:

```lua
return {
	Name = "ExampleManager",
	Requires = {
		"Helper:Example",
		"Middleware:Data",
	},

	Factory = function(core)
		local Services = core.Services
		local ReplicatedStorage = Services.ReplicatedStorage

		local Middleware = core:GetMiddleware("Data")
		local HelperOne, HelperTwo = core:GetHelper("Example", "ExampleTwo")

		return {
			Middleware = Middleware,
			HelperOne = HelperOne,
			HelperTwo = HelperTwo,
			ReplicatedStorage = ReplicatedStorage,
		}
	end,
}
```

Roblox ModuleScripts must return exactly one value. Use `Factory` when a module needs metadata and construction logic.

```lua
return {
	Name = "ExampleManager",
	Requires = {
		"Helper:Example",
		"Middleware:Data",
	},

	Factory = function(core)
		local Middleware = core:GetMiddleware("Data")

		return {
			Middleware = Middleware,
		}
	end,
}
```

Tuple-table metadata format is also supported. This keeps the old metadata-plus-factory shape while still returning one Roblox-safe value:

```lua
local Meta = {
	Name = "ExampleManager",
	Requires = {
		"Helper:Example",
		"Middleware:Data",
	},
}

return {
	Meta,
	function(core)
		local Middleware = core:GetMiddleware("Data")

		return {
			Middleware = Middleware,
		}
	end,
}
```

Both `Factory = function(...)` and `{ Meta, function(...) }` are Roblox-safe. Avoid `return Meta, function(...)` because Roblox ModuleScripts must return exactly one value.

## Manager-Local Extensions

Manager folder modules can own private helpers, middleware, and services beneath themselves.

A manager-local service is a private, potentially stateful subsystem owned by one manager. It may coordinate helpers, middleware, and other local services, but it is not registered as a public Core manager or exposed through `core.Services`.

```text
Managers/
  InventoryManager/
    init.luau
    Extension/
      Helpers/
        ItemBuilder.luau
      Middleware/
        ValidateSlot.luau
      Services/
        SlotService.luau
```

Core loads these extension modules immediately before the owning manager factory runs. They are available through the second factory argument:

```lua
return {
	Name = "InventoryManager",
	Requires = {
		"Helper:ItemTypes",
	},
	Factory = function(core, Manager)
		local ItemTypes = core:GetHelper("ItemTypes")
		local ItemBuilder = Manager:GetHelper("ItemBuilder")
		local ValidateSlot = Manager:GetMiddleware("ValidateSlot")
		local SlotService = Manager:GetService("SlotService")

		return {
			ItemTypes = ItemTypes,
			ItemBuilder = ItemBuilder,
			ValidateSlot = ValidateSlot,
			SlotService = SlotService,
		}
	end,
}
```

The manager-local context contains:

```text
Manager.Name
Manager.Helpers
Manager.Middleware
Manager.Services
Manager:GetHelper(...)
Manager:GetMiddleware(...)
Manager:GetService(...)
```

Manager-local getters support the same calling convention as public Core getters:

```lua
local SlotService = Manager:GetService("SlotService")
local One, Two = Manager:GetService("One", "Two")
local Services = Manager:GetService()
```

Local helpers, middleware, and services use the same module formats as public Core modules.

```lua
return {
	Name = "ItemBuilder",
	Factory = function(core, Manager)
		return {}
	end,
}
```

Manager modules and manager-local extension modules can also use tuple-table format:

```lua
local Meta = {
	Name = "InventoryManager",
}

return {
	Meta,
	function(core, Manager)
		return {}
	end,
}
```

Local extension modules are private to their owning manager. They are not available through `core:GetHelper(...)` or `core:GetMiddleware(...)`, and other managers cannot fetch them.

Manager-local services are also private. They are not available through `core:GetManager(...)`, `core:GetHelper(...)`, `core:GetMiddleware(...)`, or `core.Services`. `core.Services.Players` uses the lazy Roblox/Core service table; `Manager:GetService("SlotService")` retrieves a private subsystem belonging to that manager.

Local `Requires` only order modules inside the same manager-local extension set:

```lua
return {
	Name = "ValidateSlot",
	Requires = {
		"Helper:ItemBuilder",
	},
	Factory = function(core, Manager)
		local ItemBuilder = Manager:GetHelper("ItemBuilder")

		return {
			ItemBuilder = ItemBuilder,
		}
	end,
}
```

Service modules can be simple factories, metadata factories, or tuple-table modules:

```lua
return {
	Name = "SlotService",
	Requires = {
		"Helper:ItemBuilder",
	},
	Factory = function(core, Manager)
		local ItemBuilder = Manager:GetHelper("ItemBuilder")
		local SlotService = {}

		function SlotService:GetSlot(Player, SlotId)
		end

		return SlotService
	end,
}
```

Manager-local dependency ids use:

```text
Helper:Name
Middleware:Name
Service:Name
```

Base discovery order is helpers, middleware, then services. The dependency graph decides final construction order, so explicit dependencies can reorder modules across those kinds. Helper or middleware dependencies on services are allowed by the graph but are discouraged because services are intended to coordinate lower-level local modules.

If a local extension needs a public helper, middleware, or manager to already exist, put that dependency on the owning manager:

```lua
return {
	Name = "InventoryManager",
	Requires = {
		"Helper:ItemTypes",
		"Manager:BaseManager",
	},
	Factory = function(core, Manager)
		return {}
	end,
}
```

Manager extension modules do not register Core lifecycle hooks. Keep `Init`, `Start`, `PlayerAdded`, and `CharacterAdded` on the owning manager, and call local helper, middleware, or service behavior from there when needed. A service may expose methods with lifecycle-like names, but Core does not discover or bind them automatically.

To opt a manager out of child extension scanning, set `NoCheckChildren`:

```lua
return {
	Name = "InventoryManager",
	NoCheckChildren = true,
	Factory = function(core)
		return {}
	end,
}
```

Use `NoCheckChildren` when a manager has private children that it loads manually with `require(script.Child)` and should not be inspected for `Extension`, `Helpers`, `Middleware`, or `Services`.

## Dependencies

Use `Requires` to control load order.

```lua
return {
	Name = "InventoryManager",
	Requires = {
		"Helper:ItemFactory",
		"Middleware:Data",
	},
	Factory = function(core)
		local ItemFactory = core:GetHelper("ItemFactory")
		local Data = core:GetMiddleware("Data")

		return {
			ItemFactory = ItemFactory,
			Data = Data,
		}
	end,
}
```

Managers can require other managers when they need `core:GetManager(...)` during construction.

```lua
return {
	Name = "TradeManager",
	Requires = {
		"Manager:InventoryManager",
		"Helper:ItemTypes",
	},
	Factory = function(core)
		local InventoryManager = core:GetManager("InventoryManager")
		local ItemTypes = core:GetHelper("ItemTypes")

		return {
			InventoryManager = InventoryManager,
			ItemTypes = ItemTypes,
		}
	end,
}
```

In this example, `InventoryManager` is constructed and registered before `TradeManager` runs.

Dependency ids use this format:

```text
Helper:Name
Middleware:Name
Manager:Name
```

If the type prefix is omitted, Core assumes the current module type.

```lua
return {
	Name = "Data",
	Requires = {
		"Serializer",
	},
	Factory = function(core)
		local Serializer = core:GetMiddleware("Serializer")

		return {
			Serializer = Serializer,
		}
	end,
}
```

Core warns and stops startup when:

- a dependency is missing
- two modules resolve to the same id
- a circular dependency is found
- a module factory errors

## Deterministic Loading

Core discovery is deterministic.

Base discovery order is:

```text
1. Shared helpers
2. Helpers
3. Middleware
4. Managers
```

Within each folder, modules are discovered by name.

After discovery, the dependency graph decides the final load order. Dependencies always load before the modules that require them, even across module types.

For example:

```lua
return {
	Name = "ExampleManager",
	Requires = {
		"Manager:BaseManager",
	},
	Factory = function(core)
		local BaseManager = core:GetManager("BaseManager")

		return {
			BaseManager = BaseManager,
		}
	end,
}
```

`BaseManager` loads before `ExampleManager`, even though both are managers.

If two modules have no dependency relationship, their relative order follows the deterministic discovery order above.

## Lookup API

Each getter supports one or more names.

```lua
local Example = core:GetHelper("Example")
local One, Two = core:GetHelper("Example", "ExampleTwo")

local Data = core:GetMiddleware("Data")
local Inventory = core:GetManager("InventoryManager")
```

Calling a getter with no names returns the whole registry.

```lua
local Helpers = core:GetHelper()
local Middleware = core:GetMiddleware()
local Managers = core:GetManager()
```

Missing names warn immediately and return `nil`. This keeps runtime failures visible without throwing from Core-owned lookup paths.

## Services

Services are lazy-loaded through `core.Services`.

This is separate from manager-local services. `core.Services.Players` retrieves a Roblox service from the lazy Core service table. `Manager:GetService("SlotService")` retrieves a private subsystem owned by one manager.

```lua
return function(core)
	local Services = core.Services

	local Players = Services.Players
	local ReplicatedStorage = Services.ReplicatedStorage
	local Promise = Services.Promise
end
```

`Promise` is exposed through `core.Services.Promise` even though it is not a Roblox service. This keeps shared async utilities in one place without requiring duplicate modules.

The Promise module lives under `RunTime`:

```text
ReplicatedStorage/
  Core/
    RunTime/
      Promise.luau
```

## Load State

Use `core:IsLoaded()` for a quick check.

```lua
if core:IsLoaded() then
	print("Core is ready")
end
```

Use `core:WaitForLoad()` when a script needs to yield until startup completes.

```lua
local Loaded, Result = core:WaitForLoad(10)

if not Loaded then
	warn("Core did not load:", Result)
	return
end
```

Core startup uses `RunTime.Promise` internally. Load failures warn, mark Core as failed, and are returned through `WaitForLoad()` instead of being thrown by Core-owned load paths.

Core warnings use the side prefix:

```text
[SERVER]
[CLIENT]
```

`WaitForLoad` returns:

```text
true, core
```

or:

```text
false, reason
```

Inside modules, prefer `Requires` over `WaitForLoad`. `WaitForLoad` is mostly for bootstrap scripts or external scripts that need to wait for the runtime.

## Lifecycle Hooks

Returned tables can define lifecycle methods.

```lua
return {
	Name = "ExampleManager",
	Factory = function(core)
		local Manager = {}

		function Manager:Init(core)
			-- Runs after every module is constructed and registered.
		end

		function Manager:Start(core)
			-- Runs after all Init methods finish.
		end

		function Manager.PlayerAdded(Player)
			-- Server only.
		end

		function Manager.CharacterAdded(Character, Player)
			-- Server and client.
		end

		return Manager
	end,
}
```

Lifecycle order:

```text
1. Server publishes Server.Shared into ReplicatedStorage.Shared
2. Client waits for ServerSharedLoaded
3. Discover modules
4. Sort dependencies
5. Load each manager's local helpers, middleware, and services in local dependency order, unless `NoCheckChildren` is true
6. Run module factories in dependency order
7. Register returned values
8. Run Init methods
9. Run Start methods
10. Bind PlayerAdded and CharacterAdded hooks
11. Mark Core loaded
```

If a load step fails, Core warns, stops the remaining startup work, fires the load event, and stores the reason in `core.State.FailureReason`.

`PlayerAdded` and `CharacterAdded` can also be tables of named callbacks:

```lua
return {
	PlayerAdded = {
		CreateInventory = function(Player)
		end,

		LoadProfile = function(Player)
		end,
	},
}
```

## Development Overrides

Each public folder can contain a `Development` folder.

```text
Managers/
  InventoryManager.luau
  Development/
    InventoryManager.luau
```

When a matching development module exists, Core loads the override instead of the normal module.

## Naming Rules

Use PascalCase for module names, variables, functions, and public fields.

Preferred:

```lua
local Services = core.Services
local ReplicatedStorage = Services.ReplicatedStorage
local InventoryManager = core:GetManager("InventoryManager")
```

There are two lowercase exceptions:

Use lowercase `core` for module factory parameters:

```lua
return function(core)
end
```

Use lowercase `self` for metatable/object construction:

```lua
local self = setmetatable({}, InventoryManager)
```

## Internal Runtime Modules

The `RunTime` folder is a folder module. `Core/init.luau` protected-requires `Core/RunTime`, and `RunTime/init.luau` preloads the internal modules in a fixed order before Core returns its public module. If the runtime preflight fails, requiring Core still returns an inert Core module; calling `Core.new(...)` warns and returns `nil`.

The runtime is split so Core stays manageable:

```text
init.luau            protected runtime preflight and load order
LoadFailure.luau     structured load failure formatting
Logger.luau           logging and stage output
Services.luau         lazy service table
ModuleCatalog.luau    discovers modules and reads metadata
DependencyGraph.luau  dependency sorting and cycle detection
Loader.luau           constructs modules and runs Init/Start
ManagerExtensions.luau loads manager-local Helpers, Middleware, and Services
Lifecycle.luau        player and character hook binding
```

Game modules should not require these directly. Use the public Core API from `ReplicatedStorage.Core`.

Use:

```lua
local CreateCore = require(ReplicatedStorage.Core)
local core = CreateCore(Root)
```

instead of the old helper-function loader.
