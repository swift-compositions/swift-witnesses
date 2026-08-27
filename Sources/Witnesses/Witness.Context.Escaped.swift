import Witness

extension Witness.Context {

    public struct Escaped: Sendable {
        @usableFromInline
        internal let values: Witness.Values

        @usableFromInline
        internal let mode: Mode

        @usableFromInline
        internal init() {
            self.values = Witness.Context.current
            self.mode = Witness.Context.currentMode
        }
    }

    @inlinable
    public static func withEscaped<R, E: Swift.Error>(
        _ operation: (Escaped) throws(E) -> R
    ) throws(E) -> R {
        try operation(Escaped())
    }

    @inlinable
    public static func withEscaped<R, E: Swift.Error>(
        _ operation: (Escaped) async throws(E) -> R
    ) async throws(E) -> R {
        try await operation(Escaped())
    }
}

extension Witness.Context.Escaped {

    @inlinable
    public func yield<R, E: Swift.Error>(
        _ operation: () throws(E) -> R
    ) throws(E) -> R {
        try Witness.Context.with(mode: mode, { $0 = values }, operation: operation)
    }

    @inlinable
    nonisolated(nonsending)
        public func yield<R, E: Swift.Error>(
            _ operation: nonisolated(nonsending) () async throws(E) -> R
        ) async throws(E) -> R
    {
        try await Witness.Context.with(mode: mode, { $0 = values }, operation: operation)
    }
}
