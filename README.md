# CoreExample

CoreExample is a culmination of nearly **10 years of developing in Luau** and represents many of the patterns, systems, and lessons I've learned while building large Roblox projects. It serves as both a portfolio project and a reference implementation of how I approach architecture, module loading, and framework design.

If you see a folder and a script with the same name, the folder simply represents the script's contents as it appears in Roblox Studio.

This repository also exists as proof of authorship. Unfortunately, Roblox development sees its fair share of code theft, and having a public history makes it much easier to demonstrate that these systems originated here.

## Using CoreExample

You're welcome to use, modify, or learn from anything in this repository. I'd genuinely love to see these systems help other developers build something great.

The only thing I ask is that you leave a small credit somewhere; whether that's in your game's credits, documentation, or even just a comment in the source.

## Versions

CoreExample has gone through several major iterations over the years, each reflecting how my approach to Luau architecture has evolved.

### V4 (Current)

V4 is the current generation of CoreExample and is where the framework became an actual service loader.

V4 exists because earlier versions eventually reached the point where implicit loading, manual initialization order, and growing interdependencies became difficult to maintain. The runtime was redesigned around explicit dependency resolution, deterministic startup, and modular ownership.

At this point, it is no longer just a helper module with a few loading functions. V4 has a real runtime layer, an explicit runtime load order, dependency handling, lifecycle binding, shared server/client publishing, structured logging, failure reporting, load promises, and registry access for Helpers, Middleware, and Managers.

The runtime itself loads in a defined order, including modules like Promise, LoadFailure, Logger, Services, SharedPublisher, DependencyGraph, ModuleCatalog, ManagerExtensions, Loader, and Lifecycle. This makes the system much more predictable and maintainable than the older versions.

V4 is the version that best represents how I currently think about large Luau architecture.

### V3

It is simpler than V4, but that is also part of why it is still useful. For smaller projects, V3 can be easier to drop in and work with because it focuses mainly on loading Services, Helpers, and Managers without the extra runtime structure that V4 has.

V3 was also the first version where the loader started feeling like a real framework instead of just a startup script. It added better helper loading, manager loading, player/character lifecycle hooks, Promise usage, xpcall-based error handling, lazy service access, and support for shared modules.

### Legacy (V1 & V2)

The original V1 and V2 implementations are available in the **Legacy** folder. They're kept primarily for historical purposes to show how the framework evolved over time.

They aren't very good. They were built much earlier in my Luau journey and don't reflect how I write code today, but they may still be interesting if you're curious about the progression.

---

Whether you're looking for inspiration, architecture ideas, or simply want to see how a large Luau codebase can be organized, I hope you find something useful here.

If this example saves you time or teaches you something new, then it's done exactly what I hoped it would.
