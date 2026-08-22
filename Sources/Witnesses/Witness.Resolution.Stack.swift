extension Witness.Resolution {

    public struct Stack: Sendable {

        @usableFromInline
        internal var keys: [ObjectIdentifier]

        @usableFromInline
        internal init(keys: [ObjectIdentifier] = []) {
            self.keys = keys
        }
    }
}

extension Witness.Resolution.Stack {

    @TaskLocal
    public static var current: Witness.Resolution.Stack = Self()

    @inlinable
    public static func withPushed<K: Witness.Key, T>(
        _ key: K.Type,
        mode: Witness.Context.Mode,
        operation: () -> Result<T, Witness.Resolution.Error>
    ) -> Result<T, Witness.Resolution.Error> where K.Value: ~Copyable & ~Escapable {
        let id = ObjectIdentifier(key)
        var stack = current

        if stack.keys.contains(id) {
            let trace = Witness.Resolution.Trace(stack: stack.keys + [id], mode: mode)
            return .failure(.cycle(trace: trace))
        }

        stack.keys.append(id)
        return $current.withValue(stack) {
            operation()
        }
    }

    @inlinable
    nonisolated(nonsending)
        public static func withPushed<K: Witness.Key, T>(
            _ key: K.Type,
            mode: Witness.Context.Mode,
            operation: nonisolated(nonsending) () async -> Result<T, Witness.Resolution.Error>
        ) async -> Result<T, Witness.Resolution.Error>
        where K.Value: ~Copyable & ~Escapable
    {
        let id = ObjectIdentifier(key)
        var stack = current

        if stack.keys.contains(id) {
            let trace = Witness.Resolution.Trace(stack: stack.keys + [id], mode: mode)
            return .failure(.cycle(trace: trace))
        }

        stack.keys.append(id)
        return await $current.withValue(stack) {
            await operation()
        }
    }
}
