---
name: dotnet
description: Use when working in a .NET project or repository, identified by .NET project files, SDK configuration, or .NET ecosystem technologies such as C#, ASP.NET Core, EF Core, Blazor, .NET CLI, MSBuild, or NuGet. Apply when implementing, modifying, debugging, reviewing, refactoring, or configuring code that depends on .NET-specific language, runtime, framework, project-system, or tooling behavior. Do not activate for projects that do not use the .NET ecosystem.
---

# Modern .NET

"Modern" means current and idiomatic for the project's actual target framework. It does not imply upgrading the target framework, SDK, language version, runtime, or packages unless explicitly required.

## Core workflow

Before changing .NET code:

1. Establish the project's target framework, SDK, language version, and runtime.
2. Inspect the affected project and nearby code for existing conventions.
3. Identify the .NET subsystem responsible for the behavior.
4. Check capabilities already provided by the target framework and existing dependencies.
5. Make the smallest compatible change.
6. Verify using the repository's existing .NET workflow.

Never assume that the newest .NET API, language feature, SDK behavior, or package is available.

When project conventions differ from a preference in this skill, preserve the project convention unless there is a concrete .NET correctness or compatibility reason to change it.

## Reference routing

Domain-specific guidance lives in `references/`. Load only the references whose trigger conditions match the current task.

- Read [references/csharp.md](references/csharp.md) when writing or modifying C# code (language features, nullable analysis, async, cancellation, records, pattern matching, primary constructors).
- Read [references/aspnet-core.md](references/aspnet-core.md) when the project uses ASP.NET Core (DI, options, middleware, endpoint routing, hosted services, health checks, `IHttpClientFactory`, rate limiting, caching, `ProblemDetails`, HTTP clients).
- Read [references/ef-core.md](references/ef-core.md) when the project uses Entity Framework Core (query translation, tracking, materialization, `AsNoTracking`, `ExecuteUpdate`/`ExecuteDelete`, `DbContext` lifetime).
- Read [references/blazor.md](references/blazor.md) when the project uses Blazor (hosting model — SSR, Interactive Server, Interactive WebAssembly, Interactive Auto — render modes, prerendering, lifecycle, JS interop, circuit state).

Do not load a reference unless its trigger applies. For example, a Godot/C# project loads `references/csharp.md` only, not ASP.NET Core, EF Core, or Blazor.

## Project configuration

Inspect relevant .NET configuration when applicable:

- `global.json`
- target frameworks in `.csproj` or `.fsproj`
- language version settings
- `Directory.Build.props`
- `Directory.Build.targets`
- `Directory.Packages.props`
- `.editorconfig`
- `NuGet.config`
- nullable configuration
- multi-targeting
- analyzer configuration

Before changing project or package configuration:

1. Confirm the target framework and SDK.
2. Check existing package versions and package-management conventions.
3. Check whether the target framework already provides the required capability.
4. Preserve existing MSBuild and SDK conventions.
5. Verify restore and build behavior.

## Runtime compatibility

Consider the actual runtime and deployment constraints of the affected project.

Pay particular attention to:

- browser/WebAssembly
- trimming
- Native AOT
- runtime-specific APIs
- multi-targeted projects

Keep runtime-specific APIs behind explicit runtime boundaries when code is intended to execute across different .NET runtimes.

Prefer source-generated framework facilities when they provide concrete benefits for trimming, AOT, startup, compatibility, or compile-time behavior.

Do not introduce reflection workarounds, source generation, or runtime-specific branches without a concrete requirement.

## NuGet and dependencies

Before adding a NuGet package, check:

1. Whether the target .NET runtime already provides the capability.
2. Whether ASP.NET Core, EF Core, or another existing framework dependency provides it.
3. Whether an existing project dependency provides it.
4. Whether a new package is actually required.

Preserve the project's existing package-management and versioning conventions.

## .NET CLI and development processes

Use the .NET CLI commands appropriate for the task and preserve the repository's existing CLI workflow.

When `dotnet watch`, an IDE build, or another development process is actively building or running the project, assume its `bin/` and `obj/` outputs are in use.

For independent CLI operations that would otherwise write to the same project outputs:

- Do not run destructive commands such as `dotnet clean` against outputs used by the running process.
- Do not delete or modify active `bin/` or `obj/` directories to make another command succeed.
- Use `--artifacts-path` to redirect generated outputs to an isolated directory.
- Prefer an empty temporary or otherwise disposable directory for isolated operations.
- Keep the running development process using its original project outputs.

Use the corresponding `--artifacts-path` option for other .NET CLI commands when supported and isolation is required.

The goal is to prevent independent CLI operations from overwriting, cleaning, or otherwise interfering with outputs currently used by `dotnet watch` or another active development process.

## Verification

Verify changes proportionally to their risk.

- Do not build or test trivial changes such as comments, documentation, formatting, or simple text-only edits.
- For small and straightforward code changes, direct inspection may be sufficient.
- Use the appropriate .NET build, test, or compiler tooling when changes are large, syntactically complex, or likely to introduce errors that are difficult to detect by inspection.
- Prefer the narrowest relevant verification first.
- Use the repository's existing verification workflow.
