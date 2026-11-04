# swift-witnesses

Use this package when you describe a dependency as a struct of closures and want the boilerplate generated and the value resolved per scope, with separate live, preview and test defaults. Mark the struct with `@Witness`, conform it to `Witness.Key`, read it with `Witness.Context` and override it for one operation with `withWitnesses(_:operation:)` or `Witness.Context.withTest(_:operation:)`. `@Witness` on an enum generates case prisms instead. If you only need the `Witness` namespace and marker protocol, use swift-witness. If you only need values bound per task with live and test defaults, use swift-dependency.

## Laws

- A context is in live mode unless `Witness.Context.withTest(_:operation:)`, `Witness.Context.withPreview(_:operation:)` or `Witness.Context.with(mode:_:operation:)` set a mode. A nested scope that sets no mode keeps the outer one. Test mode also marks the underlying swift-dependency scope as a test context.
- A scope starts from the values of the scope around it. A value set in a scope wins over the key's default in every mode, and the outer value is back when the scope ends.
- Without an override, a `Witness.Key` resolves to `liveValue`, `previewValue` or `testValue` by mode. For a copyable value, `previewValue` defaults to `liveValue` and `testValue` defaults to `previewValue`. A key that only conforms to `Witness.Key.Test` has `previewValue` default to `testValue`.
- `Witness.Context.current` holds the scope's values but not its mode, so reading a `Witness.Key` through it falls back to `liveValue` even in a test scope. Subscripting `Witness.Context` itself, and `Witness.Context.withValue(_:_:)`, use the scope's mode.
- `Witness.Context.withValue(_:_:)` with a value that is neither copyable nor escapable ignores overrides and always uses the mode's default.
- A key that only conforms to `Witness.Key.Test`, resolved in live mode with no override, traps in debug builds. In release builds it serves `testValue` and prints a warning to standard error once per key, unless the environment variable `DEPENDENCIES_STRICT` is `1`, which makes it trap.
- `Witness.Values.merging(_:)` keeps every value of both, and the argument's value wins when both hold the same key.
- `Witness.Access` captures the context when it is created and reads through the current context merged over it, so an override at the read site wins.
- `Witness.Context.Escaped` carries both values and mode. `Witness.CapturedContext` and `Witness.Scope` carry only values, so their operation runs in whatever mode is current where it is called.
- `Witness.Cycle` returns its values in order and starts again after the last. `Witness.Sequence` returns its values in order and then keeps returning the last.
- `@Witness` makes a method for every non-optional closure with at least one named parameter, and uses the parameter names as argument labels, so `(_ id: Int)` gives `fetch(id:)`. A closure with only unnamed parameters gets no method.
- In `unimplemented()`, an operation that throws untyped errors, in any spelling, or `Witness.Unimplemented.Error` throws a `Witness.Unimplemented.Error`. An operation with another typed error throws that type's `unimplemented(_:)` case. A non-throwing operation, or one that throws `Never`, traps when called. Optional closures are nil.
- A `Witness.Unimplemented.Error` from `unimplemented()` names the struct, the operation as `name(label:)`, and the place where `unimplemented()` was called.
- With `.mock`, every non-optional operation returns the given value whatever its arguments. Operations returning `Void` need no value. `.generator` only takes effect on a struct with exactly one closure.
- `observe` calls `before` ahead of the operation and `after` once it returns or throws. A thrown error is then rethrown unchanged. `Calls` leaves out `borrowing`, `consuming` and `inout` parameters. A `nonisolated(nonsending)` async closure, or an optional `@Sendable` async closure, is passed through without being observed.
- An operation named `count`, `ordinal` or `allCases` gets a trailing underscore in `Calls.Case`, such as `count_`. `Calls` keeps the exact name.
- `@WitnessAccessors` adds static methods that call through `Witness.Context.current`, so they see overrides but always fall back to `liveValue`. A leading underscore on the closure name is dropped from the method name.
