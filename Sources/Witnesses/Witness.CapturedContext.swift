import Witness

extension Witness {

    public final class CapturedContext: Sendable {

        public let values: Witness.Values

        @inlinable
        public init() {
            self.values = Witness.Context.current
        }
    }
}

extension Witness.CapturedContext {

    @inlinable
    public func withValues<R, E: Swift.Error>(
        _ operation: () throws(E) -> R
    ) throws(E) -> R {
        try Witness.Context.with({ $0 = self.values }, operation: operation)
    }

    @inlinable
    nonisolated(nonsending)
        public func withValues<R, E: Swift.Error>(
            _ operation: nonisolated(nonsending) () async throws(E) -> R
        ) async throws(E) -> R
    {
        try await Witness.Context.with({ $0 = self.values }, operation: operation)
    }
}
