# Roblox Sync Module Layout

This repository uses Roblox Sync.

The Core system follows this layout:

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

  Client/
    Helpers/
    Middleware/
    Managers/
  Shared/

ServerScriptService/
  Server/
    Helpers/
    Middleware/
    Managers/
    Shared/
```

Core only treats direct child modules of `Helpers`, `Middleware`, `Managers`, and `Shared` as public modules.

`RunTime` is a folder module. `Core/init.luau` protected-requires `Core/RunTime`, and `RunTime/init.luau` owns the internal runtime load order before Core returns its public module. If a runtime module fails to require, Core returns an inert Core module that warns and returns `nil` from `Core.new(...)`.

Core modules with metadata must return one Roblox ModuleScript value. Use either a table with `Factory = function(...)` or a tuple table shaped like `{ Meta, function(...) }`. Do not use `return Meta, function(...)`.

## Module Representation

A Roblox ModuleScript can be represented in two ways on disk.

## Single-File Module

Use a single `.luau` file when the module has no private children.

```text
Helpers/
  Theme.luau
```

This becomes:

```text
Helpers
  Theme (ModuleScript)
```

Core sees this as:

```text
Helper:Theme
```

and the module can be loaded with:

```lua
local Theme = core:GetHelper("Theme")
```

## Folder Module

Use a folder containing `init.luau` when the module owns private child modules.

```text
Helpers/
  UIManager/
    init.luau
    Diagnostics.luau
    Debug.luau
```

This becomes:

```text
Helpers
  UIManager (ModuleScript)
    Diagnostics (ModuleScript)
    Debug (ModuleScript)
```

The folder itself is still the public module. Consumers require or fetch `UIManager`, not `init`.

```lua
local UIManager = core:GetHelper("UIManager")
```

Inside `UIManager/init.luau`, private children can be required through `script`.

```lua
local Diagnostics = require(script.Diagnostics)
local Debug = require(script.Debug)

return {
	Name = "UIManager",
	Factory = function(core)
		return {
			Diagnostics = Diagnostics,
			Debug = Debug,
		}
	end,
}
```

This is the preferred way to grow a module once it needs internal files.

## Core Module Example

A Core helper can be either a single file:

```text
ReplicatedStorage/
  Client/
    Helpers/
      InventoryTheme.luau
```

or a folder module:

```text
ReplicatedStorage/
  Client/
    Helpers/
      InventoryTheme/
        init.luau
        Colors.luau
        Icons.luau
```

Both forms expose the same helper name:

```lua
local InventoryTheme = core:GetHelper("InventoryTheme")
```

Callers do not need to change when `InventoryTheme.luau` becomes `InventoryTheme/init.luau`.

## Shared Helpers

`Shared` is helper-only in this Core system.

These are valid:

```text
ReplicatedStorage/
  Shared/
    ItemTypes.luau
    Signals/
      init.luau
      Connection.luau

ServerScriptService/
  Server/
    Shared/
      ItemTypes.luau
```

Shared helpers are injected into `core.Helpers`.

```lua
local ItemTypes = core:GetHelper("ItemTypes")
local Signals = core:GetHelper("Signals")
```

`Server/Shared` is automatically published into `ReplicatedStorage/Shared`, so do not put server-private code or secrets there.

## Do Not Duplicate Modules

A module should only have one representation.

Do not do this:

```text
Helpers/
  UIBase.luau
  UIBase/
    init.luau
```

Choose one representation.

If a single-file module later needs private children:

1. Create a folder with the same name.
2. Move the module contents into `init.luau`.
3. Add any private child modules.
4. Remove the original `.luau` file.

Result:

```text
Helpers/
  UIBase/
    init.luau
    Components.luau
```

Core still sees this as:

```text
Helper:UIBase
```

## Public vs Private Modules

Only direct child modules of a public Core folder should be considered public API.

Public folders:

```text
Helpers/
Middleware/
Managers/
Shared/
```

Private implementation modules should live beneath the module that owns them.

Example:

```text
Helpers/
  UIBase/
    init.luau
    Components/
      Button.luau
      Badge.luau
      Loading.luau
```

Consumers use:

```lua
local UIBase = core:GetHelper("UIBase")
```

The internal modules are implementation details and should only be required by `UIBase`.

## Manager Example With Children

Managers can also be folder modules.

```text
ServerScriptService/
  Server/
    Managers/
      InventoryManager/
        init.luau
        ItemSerializer.luau
        Transactions.luau
```

`InventoryManager/init.luau`:

```lua
local ItemSerializer = require(script.ItemSerializer)
local Transactions = require(script.Transactions)

return {
	Name = "InventoryManager",
	Requires = {
		"Helper:ItemTypes",
	},
	Factory = function(core)
		local ItemTypes = core:GetHelper("ItemTypes")

		return {
			ItemTypes = ItemTypes,
			ItemSerializer = ItemSerializer,
			Transactions = Transactions,
		}
	end,
}
```

Core sees this as:

```text
Manager:InventoryManager
```

and other modules can use:

```lua
local InventoryManager = core:GetManager("InventoryManager")
```

## Manager-Local Extension Modules

Managers can own private helpers, middleware, and services. These modules initialize before the owning manager factory and stay scoped to that manager.

A manager-local service is a private, potentially stateful subsystem owned by one manager. It may coordinate helpers, middleware, and other local services, but it is not registered as a public Core manager or exposed through `core.Services`.

Preferred layout:

```text
ServerScriptService/
  Server/
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
ServerScriptService/
  Server/
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

Use one layout per manager. Core warns and stops loading if both `Extension/Helpers` and `Helpers`, both `Extension/Middleware` and `Middleware`, or both `Extension/Services` and `Services` exist under the same manager.

`InventoryManager/init.luau`:

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

The manager-local context contains `Manager.Helpers`, `Manager.Middleware`, and `Manager.Services`, plus `Manager:GetHelper(...)`, `Manager:GetMiddleware(...)`, and `Manager:GetService(...)`.

`Manager:GetService(...)` follows the same lookup behavior as the other local getters:

```lua
local SlotService = Manager:GetService("SlotService")
local One, Two = Manager:GetService("One", "Two")
local Services = Manager:GetService()
```

`InventoryManager/Extension/Middleware/ValidateSlot.luau`:

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

`InventoryManager/Extension/Services/SlotService.luau`:

```lua
return {
	Name = "SlotService",
	Requires = {
		"Helper:ItemBuilder",
		"Middleware:ValidateSlot",
	},
	Factory = function(core, Manager)
		local ItemBuilder = Manager:GetHelper("ItemBuilder")
		local ValidateSlot = Manager:GetMiddleware("ValidateSlot")

		return {
			ItemBuilder = ItemBuilder,
			ValidateSlot = ValidateSlot,
		}
	end,
}
```

Local extension `Requires` only refer to modules inside the same manager's extension folders. Public dependencies should stay on the owning manager's `Requires`.

Manager-local dependency ids are `Helper:Name`, `Middleware:Name`, and `Service:Name`. Base discovery order is helpers, middleware, then services, but explicit dependencies decide final construction order. Dependencies from helpers or middleware to services are allowed by the graph but discouraged because services are intended to coordinate lower-level local modules.

Manager-local services stay private to the owning manager. They are not available through `core:GetManager(...)`, `core:GetHelper(...)`, `core:GetMiddleware(...)`, or `core.Services`. `core.Services.Players` is the lazy Roblox/Core service table; `Manager:GetService("SlotService")` retrieves a private manager subsystem.

Manager-local helpers, middleware, and services do not register Core lifecycle hooks. Keep `Init`, `Start`, `PlayerAdded`, and `CharacterAdded` on the owning manager and manually forward into a local service if needed.

Use `NoCheckChildren` to skip extension scanning for a manager:

```lua
return {
	Name = "InventoryManager",
	NoCheckChildren = true,
	Factory = function(core)
		return {}
	end,
}
```

This is useful when the manager has private children that it requires manually and does not want Core to inspect for `Extension`, `Helpers`, `Middleware`, or `Services`.

## Module Ownership

Each folder module owns everything beneath it.

```text
Networking/
  Client/
    init.luau
    PacketHandlers/
    Compression/
```

Everything inside `Networking/Client` belongs to that module unless intentionally exposed by `Networking/Client/init.luau`.

This keeps implementation details encapsulated while maintaining a stable public API.

## Why This Structure?

Using `init.luau` folder modules has several advantages:

- keeps related implementation files together
- allows modules to grow without changing their public name
- avoids namespace conflicts between files and folders
- produces a predictable Roblox hierarchy after synchronization
- works consistently with sync tools that map folders with `init.luau` to ModuleScripts

As a result, modules can evolve from a single file into a complete subsystem without requiring callers to change how they import, require, or fetch the module from Core.
