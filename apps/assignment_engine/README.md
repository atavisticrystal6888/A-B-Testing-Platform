# AssignmentEngine

Elixir wrapper app for the Rust assignment core.

Responsibilities:

- Expose deterministic assignment functions through `AssignmentEngine.Native`
- Load the Rustler NIF when available
- Provide a stable BEAM-side interface for assignment services

Run focused tests:

```powershell
mix test apps/assignment_engine/test
```

