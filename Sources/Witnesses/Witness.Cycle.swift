public import Synchronization
import Witness

extension Witness {

    public final class Cycle<T: Sendable>: @unsafe @unchecked Sendable {
        @usableFromInline
        internal let values: [T]

        @usableFromInline
        internal let _index: Mutex<Int>

        @inlinable
        public init(_ values: [T]) {
            precondition(!values.isEmpty, "Witness.Cycle requires at least one value")
            self.values = values
            self._index = Mutex(0)
        }

        @inlinable
        public func callAsFunction() -> T {
            let i = _index.withLock { index -> Int in
                let current = index
                index = (current + 1) % values.count
                return current
            }
            return values[i]
        }
    }
}
