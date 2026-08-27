import Witness

@inlinable
public func withWitnesses<T, E: Swift.Error>(
    _ modify: (inout Witness.Values) -> Void,
    operation: () throws(E) -> T
) throws(E) -> T {
    try Witness.Context.with(modify, operation: operation)
}

@inlinable
nonisolated(nonsending)
    public func withWitnesses<T, E: Swift.Error>(
        _ modify: (inout Witness.Values) -> Void,
        operation: nonisolated(nonsending) () async throws(E) -> T
    ) async throws(E) -> T
{
    try await Witness.Context.with(modify, operation: operation)
}
