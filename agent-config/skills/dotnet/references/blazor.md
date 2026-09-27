# Blazor

Load this reference when the project uses Blazor — hosting model (SSR,
Interactive Server, Interactive WebAssembly, Interactive Auto), render modes,
prerendering, lifecycle, JS interop, circuit state.

Determine the actual Blazor hosting and rendering model before changing
component code.

Identify whether the application uses:

- static SSR
- Interactive Server
- Interactive WebAssembly
- Interactive Auto
- another supported hosting model

Do not assume that a component always executes on the server or always
executes in the browser.

## Component execution

- Know where component code executes before using runtime-specific services or APIs.
- Do not reference server-only dependencies from code that can execute in WebAssembly.
- Use explicit server/API boundaries when browser-executed code requires server resources.
- Treat code and configuration shipped to a WebAssembly client as client-side resources.
- Preserve the application's existing render-mode strategy unless the task requires changing it.

## Rendering and lifecycle

- Account for prerendering when enabled.
- Account for lifecycle execution that may occur during both prerendering and interactive rendering.
- Do not perform non-idempotent operations during lifecycle execution without accounting for repeated execution.
- Dispose component-owned resources according to their lifecycle.
- Use JavaScript interop for browser-specific functionality when no suitable .NET abstraction exists.
- For server-interactive components, account for circuit lifetime, disconnection, and server-held component state.
- Do not perform long-running blocking work directly on a server circuit.

When changing render modes or lifecycle behavior, reason about execution
location and transitions between prerendered and interactive states.
