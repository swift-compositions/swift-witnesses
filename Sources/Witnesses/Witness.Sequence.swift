public import Synchronization
import Witness_Primitives

extension Witness {

    public final class Sequence<T: Sendable>: @unsafe @unchecked Sendable {
        @usableFromInline
        internal let values: [T]

        @usableFromInline
        internal let _index: Mutex<Int>

        @inlinable
        public init(_ values: [T]) {
            precondition(!values.isEmpty, "Witness.Sequence requires at least one value")
            self.values = values
            self._index = Mutex(0)
        }

        @inlinable
        public func callAsFunction() -> T {
            let i = _index.withLock { index -> Int in
                let current = index
                if current < values.count - 1 { index = current + 1 }
                return current
            }
            return values[i]
        }
    }
}
