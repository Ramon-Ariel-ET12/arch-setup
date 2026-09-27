# ASP.NET Core

Load this reference when the project uses ASP.NET Core — DI, options,
middleware, endpoint routing, hosted services, health checks,
`IHttpClientFactory`, rate limiting, caching, `ProblemDetails`. Web API
concerns (routing, minimal APIs, controllers) are part of this domain and
covered here.

## Framework mechanisms

Use the ASP.NET Core APIs and execution model supported by the application's
target framework.

Prefer established framework mechanisms for:

- dependency injection
- configuration and options
- middleware
- endpoint routing
- hosted services
- health checks
- `IHttpClientFactory`
- rate limiting
- resilience
- caching
- `ProblemDetails`

Follow the APIs and application model supported by the project's actual ASP.NET
Core version. Do not assume APIs introduced in newer releases are available.

## Dependency injection

Preserve .NET DI lifetime semantics:

- `Singleton`
- `Scoped`
- `Transient`

Understand how service lifetimes interact with the ASP.NET Core request,
application, and hosting lifecycles.

Use constructor injection and framework-supported service registration patterns
where the application uses the built-in container.

## Options

Use the .NET options abstractions according to their lifetime and update
semantics:

- `IOptions<T>`
- `IOptionsSnapshot<T>`
- `IOptionsMonitor<T>`

Prefer typed options when configuration values represent application options
consumed by .NET services.

## HTTP clients

For outbound HTTP managed by ASP.NET Core:

- Use the application's established `IHttpClientFactory` pattern.
- Use typed, named, or generated clients according to the existing application.
- Configure client behavior through the supported .NET HTTP client mechanisms.
- Propagate cancellation through supported APIs.
