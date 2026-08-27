public import Dependency
import Witness

extension Witness {

    public struct Context: Sendable {

        public var values: Values

        public var mode: Mode

        @usableFromInline
        internal init(values: Values, mode: Mode) {
            self.values = values
            self.mode = mode
        }
    }
}

extension Witness.Context {

    @usableFromInline
    internal enum _ContextKey: Dependency.Key {}

    private static var _current: Witness.Context {
        Dependency.Scope.current[_ContextKey.self]
    }
}

extension Witness.Context._ContextKey {
    @usableFromInline
    static var liveValue: Witness.Context {
        Witness.Context(values: .init(), mode: .live)
    }

    @usableFromInline
    static var testValue: Witness.Context { liveValue }
}

extension Witness.Context {

    public static var current: Witness.Values {
        _current.values
    }

    public static var currentMode: Mode {
        _current.mode
    }
}

extension Witness.Context {

    public static subscript<K: Witness.Key>(key: K.Type) -> K.Value
    where K.Value: Copyable & Escapable {
        _current.values.value(for: key, mode: _current.mode)
    }

    public static subscript<K: Witness.Key.Test>(key: K.Type) -> K.Value
    where K.Value: Copyable & Escapable {
        _current.values.value(for: key, mode: _current.mode)
    }

    public static subscript<K: Dependency.Key>(key: K.Type) -> K.Value
    where K.Value: Copyable & Escapable {
        _current.values[K.self]
    }

    public static func value<K: Witness.Key>(
        _ key: K.Type
    ) -> Result<K.Value, Witness.Resolution.Error> where K.Value: Copyable & Escapable {
        .success(_current.values.value(for: key, mode: _current.mode))
    }

    public static func withValue<K: Witness.Key, R>(
        _ key: K.Type,
        _ body: (borrowing K.Value) -> R
    ) -> R where K.Value: ~Copyable & Escapable {
        _current.values.withValue(for: key, mode: _current.mode, body)
    }

    public static func withValue<K: Witness.Key, R>(
        _ key: K.Type,
        _ body: (borrowing K.Value) -> R
    ) -> R where K.Value: ~Copyable & ~Escapable {
        _current.values.withDefaultValue(for: key, mode: _current.mode, body)
    }
}

extension Witness.Context {

    @inlinable
    public static func _withScope<T, E: Swift.Error>(
        mode: Mode? = nil,
        _ modify: (inout Witness.Values, inout Dependency.Dependency.Values) -> Void,
        operation: () throws(E) -> T
    ) throws(E) -> T {
        try Dependency.Scope.with(
            { l1Values in
                var context = l1Values[_ContextKey.self]
                if let mode {
                    context.mode = mode
                    l1Values.isTestContext = (mode == .test)
                }
                modify(&context.values, &l1Values)
                l1Values[_ContextKey.self] = context
            },
            operation: operation
        )
    }

    @inlinable
    nonisolated(nonsending)
        public static func _withScope<T, E: Swift.Error>(
            mode: Mode? = nil,
            _ modify: (inout Witness.Values, inout Dependency.Dependency.Values) -> Void,
            operation: nonisolated(nonsending) () async throws(E) -> T
        ) async throws(E) -> T
    {
        try await Dependency.Scope.with(
            { l1Values in
                var context = l1Values[_ContextKey.self]
                if let mode {
                    context.mode = mode
                    l1Values.isTestContext = (mode == .test)
                }
                modify(&context.values, &l1Values)
                l1Values[_ContextKey.self] = context
            },
            operation: operation
        )
    }
}

extension Witness.Context {

    public static func with<T, E: Swift.Error>(
        _ modify: (inout Witness.Values) -> Void,
        operation: () throws(E) -> T
    ) throws(E) -> T {
        try _withScope(
            { witnessValues, _ in
                modify(&witnessValues)
            },
            operation: operation
        )
    }

    public static func with<T, E: Swift.Error>(
        mode: Mode,
        _ modify: ((inout Witness.Values) -> Void)? = nil,
        operation: () throws(E) -> T
    ) throws(E) -> T {
        try _withScope(
            mode: mode,
            { witnessValues, _ in
                modify?(&witnessValues)
            },
            operation: operation
        )
    }
}

extension Witness.Context {

    nonisolated(nonsending)
        public static func with<T, E: Swift.Error>(
            _ modify: (inout Witness.Values) -> Void,
            operation: nonisolated(nonsending) () async throws(E) -> T
        ) async throws(E) -> T
    {
        try await _withScope(
            { witnessValues, _ in
                modify(&witnessValues)
            },
            operation: operation
        )
    }

    nonisolated(nonsending)
        public static func with<T, E: Swift.Error>(
            mode: Mode,
            _ modify: ((inout Witness.Values) -> Void)? = nil,
            operation: nonisolated(nonsending) () async throws(E) -> T
        ) async throws(E) -> T
    {
        try await _withScope(
            mode: mode,
            { witnessValues, _ in
                modify?(&witnessValues)
            },
            operation: operation
        )
    }
}

extension Witness.Context {

    public static func withTest<T, E: Swift.Error>(
        _ modify: ((inout Witness.Values) -> Void)? = nil,
        operation: () throws(E) -> T
    ) throws(E) -> T {
        try _withScope(
            mode: .test,
            { witnessValues, _ in
                modify?(&witnessValues)
            },
            operation: operation
        )
    }

    public static func withPreview<T, E: Swift.Error>(
        _ modify: ((inout Witness.Values) -> Void)? = nil,
        operation: () throws(E) -> T
    ) throws(E) -> T {
        try _withScope(
            mode: .preview,
            { witnessValues, _ in
                modify?(&witnessValues)
            },
            operation: operation
        )
    }
}

extension Witness.Context {

    nonisolated(nonsending)
        public static func withTest<T, E: Swift.Error>(
            _ modify: ((inout Witness.Values) -> Void)? = nil,
            operation: nonisolated(nonsending) () async throws(E) -> T
        ) async throws(E) -> T
    {
        try await _withScope(
            mode: .test,
            { witnessValues, _ in
                modify?(&witnessValues)
            },
            operation: operation
        )
    }

    nonisolated(nonsending)
        public static func withPreview<T, E: Swift.Error>(
            _ modify: ((inout Witness.Values) -> Void)? = nil,
            operation: nonisolated(nonsending) () async throws(E) -> T
        ) async throws(E) -> T
    {
        try await _withScope(
            mode: .preview,
            { witnessValues, _ in
                modify?(&witnessValues)
            },
            operation: operation
        )
    }
}
