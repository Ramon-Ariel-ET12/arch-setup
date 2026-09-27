# EF Core

Load this reference when the project uses Entity Framework Core — query
translation, tracking, materialization, `AsNoTracking`, `ExecuteUpdate` /
`ExecuteDelete`, `DbContext` lifetime.

Reason about EF Core queries in terms of query translation, SQL generation,
tracking, materialization, and database round trips.

- Prefer projections when only part of an entity or graph is required.
- Use `AsNoTracking()` for read-only queries when tracking is unnecessary.
- Use EF Core asynchronous query and persistence APIs.
- Propagate `CancellationToken`.
- Keep query composition server-side when possible.
- Understand generated SQL for important or non-trivial queries.
- Avoid accidental N+1 query patterns.
- Avoid unnecessary `Include`.
- Delay materialization until the data is required.
- Use set-based APIs such as `ExecuteUpdate` and `ExecuteDelete` when their semantics fit.
- Preserve the application's established `DbContext` lifetime strategy.
- Treat `DbContext` according to its EF Core unit-of-work semantics.

When changing a non-trivial query, evaluate its translated SQL, tracking
behavior, materialization, and database round trips rather than only its LINQ
representation.
