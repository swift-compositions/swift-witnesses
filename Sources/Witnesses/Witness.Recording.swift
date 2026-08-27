public import Synchronization
import Witness

extension Witness {

    public final class Recording<Args: Sendable>: @unsafe @unchecked Sendable {
        @usableFromInline
        internal let _calls: Mutex<[Args]>

        @inlinable
        public var calls: [Args] {
            _calls.withLock { $0 }
        }

        @inlinable
        public init() {
            self._calls = Mutex([])
        }

        @inlinable
        public func record(_ args: Args) {
            _calls.withLock { $0.append(args) }
        }

        @inlinable
        public func reset() {
            _calls.withLock { $0.removeAll() }
        }

        @inlinable
        public var count: Int {
            _calls.withLock { $0.count }
        }

        @inlinable
        public var isEmpty: Bool {
            _calls.withLock { $0.isEmpty }
        }

        @inlinable
        public var last: Args? {
            _calls.withLock { $0.last }
        }

        @inlinable
        public var first: Args? {
            _calls.withLock { $0.first }
        }
    }
}
