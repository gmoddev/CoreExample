# CoreExample

CoreExample is a culmination of nearly **10 years of developing in Luau** and represents many of the patterns, systems, and lessons I've learned while building large Roblox projects. It serves as both a portfolio project and a reference implementation of how I approach architecture, module loading, and framework design.

If you see a folder and a script with the same name, the folder simply represents the script's contents as it appears in Roblox Studio.

This repository also exists as proof of authorship. Unfortunately, Roblox development sees its fair share of code theft, and having a public history makes it much easier to demonstrate that these systems originated here.

## Using CoreExample

You're welcome to use, modify, or learn from anything in this repository. I'd genuinely love to see these systems help other developers build something great.

The only thing I ask is that you leave a small credit somewhere—whether that's in your game's credits, documentation, or even just a comment in the source.

## Versions

CoreExample has gone through several major iterations over the years, each reflecting how my approach to Luau architecture has evolved.

### V4 (Current)

V4 is the current generation of the framework. Unlike previous versions, it is a complete service loader rather than a few helper functions. It focuses on dependency management, initialization order, runtime loading, shared module publishing, error reporting, and building larger projects in a structured, maintainable way.

### V3

V3 is still included because I continue to use it for some projects. While it isn't as feature-rich as V4, it's significantly simpler and is often the better choice for smaller games or projects that don't need the additional complexity of a full service loader.

### Legacy (V1 & V2)

The original V1 and V2 implementations are available in the **Legacy** folder. They're kept primarily for historical purposes to show how the framework evolved over time.

They aren't very good. They were built much earlier in my Luau journey and don't reflect how I write code today, but they may still be interesting if you're curious about the progression.

---

Whether you're looking for inspiration, architecture ideas, or simply want to see how a large Luau codebase can be organized, I hope you find something useful here.

If CoreExample saves you time or teaches you something new, then it's done exactly what I hoped it would.
