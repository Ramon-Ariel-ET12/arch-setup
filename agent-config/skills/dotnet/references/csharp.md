# C#

Load this reference when writing or modifying C# code (language features,
nullable analysis, async, cancellation, records, pattern matching, primary
constructors). Trigger covers any project that uses C#, including those that
do not use ASP.NET Core, EF Core, or Blazor.

## Language features

Choose C# features according to target support, semantic fit, and existing
project style.

- Treat nullable reference types and nullable warnings as compiler correctness signals.
- Use `record` and `record struct` when value semantics are appropriate.
- Use immutable DTOs and contracts when the API or framework usage benefits from immutability.
- Use `required`, `init`, primary constructors, pattern matching, collection expressions, and other modern C# features when supported and appropriate.
- Preserve classes when their identity, lifecycle, inheritance, mutability, or framework integration requires class semantics.
- Do not introduce newer syntax solely for stylistic novelty.
- Do not use `!`, `default!`, or warning suppression to hide invalid state or unresolved compiler analysis.

## Async and cancellation

Use .NET asynchronous APIs according to their actual execution semantics.

- Use `async`/`await` for asynchronous operations.
- Propagate `CancellationToken` through asynchronous framework APIs when supported.
- Prefer framework overloads that accept cancellation.
- Do not use `Task.Run` to make naturally asynchronous server I/O appear asynchronous.
- Avoid `.Result`, `.Wait()`, and `GetAwaiter().GetResult()` in normal asynchronous application flow.
- Use `async void` only where required by a framework API.
- Use `Task` by default.
- Use `ValueTask` when its allocation characteristics provide a concrete benefit.
