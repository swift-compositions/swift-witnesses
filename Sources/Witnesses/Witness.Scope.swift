import Witness_Primitives

extension Witness {

    public struct Scope: ~Copyable, Sendable {
        @usableFromInline
        internal var values: Witness.Values

        @usableFromInline
        internal var consumed: Bool = false

        @inlinable
        public init(values: Witness.Values) {
            self.values = values
        }

        @inlinable
        public init() {
            self.values = Witness.Context.current
        }

        deinit {
            precondition(
                consumed,
                "Witness.Scope was never used. Call run(_:) to execute with the captured context."
            )
        }
    }
}

extension Witness.Scope {

    @inlinable
    public consuming func run<R, E: Swift.Error>(
        _ operation: () throws(E) -> R
    ) throws(E) -> R {
        consumed = true
        return try Witness.Context.with({ $0 = values }, operation: operation)
    }

    @inlinable
    nonisolated(nonsending)
        public consuming func run<R, E: Swift.Error>(
            _ operation: nonisolated(nonsending) () async throws(E) -> R
        ) async throws(E) -> R
    {
        consumed = true
        return try await Witness.Context.with({ $0 = values }, operation: operation)
    }
}
