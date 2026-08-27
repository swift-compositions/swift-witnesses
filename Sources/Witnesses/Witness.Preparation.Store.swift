internal import Ownership
import Synchronization

extension Witness.Preparation {

    @safe
    public final class Store: @unsafe @unchecked Sendable {

        private var storage: [ObjectIdentifier: UnsafeRawPointer]

        private let lock: Mutex<Void>

        public init() {
            unsafe (self.storage = [:])
            self.lock = Mutex(())
        }

        deinit {
            var iter = unsafe storage.values.makeIterator()
            while let ptr = unsafe iter.next() {
                unsafe Unmanaged<AnyObject>.fromOpaque(ptr).release()
            }
        }
    }
}

extension Witness.Preparation.Store {

    public func get<K: Witness.Key.Test>(_ key: K.Type) -> K.Value?
    where K.Value: Copyable & Escapable {
        lock.withLock { _ in
            let id = ObjectIdentifier(K.self)
            guard let ptr = unsafe storage[id] else {
                return nil
            }
            return unsafe Unmanaged<Ownership.Immutable<K.Value>>.fromOpaque(ptr)
                .takeUnretainedValue()
                .value
        }
    }

    public func withValue<K: Witness.Key.Test, R>(
        _ key: K.Type,
        _ body: (borrowing K.Value) -> R
    ) -> R? where K.Value: ~Copyable & Escapable {
        lock.withLock { _ in
            let id = ObjectIdentifier(K.self)
            guard let ptr = unsafe storage[id] else { return nil }
            return body(
                unsafe Unmanaged<Ownership.Immutable<K.Value>>.fromOpaque(ptr)
                    .takeUnretainedValue()
                    .value
            )
        }
    }

    public func set<K: Witness.Key.Test>(_ key: K.Type, value: consuming K.Value)
    where K.Value: ~Copyable & Escapable {

        let ptr = unsafe UnsafeRawPointer(
            Unmanaged.passRetained(Ownership.Immutable(value)).toOpaque()
        )
        lock.withLock { _ in
            let id = ObjectIdentifier(K.self)

            if let oldPtr = unsafe storage[id] {
                unsafe Unmanaged<AnyObject>.fromOpaque(oldPtr).release()
            }

            unsafe storage[id] = ptr
        }
    }

    @discardableResult
    public func remove<K: Witness.Key.Test>(_ key: K.Type) -> K.Value?
    where K.Value: Copyable & Escapable {
        lock.withLock { _ in
            let id = ObjectIdentifier(K.self)
            guard let ptr = unsafe storage.removeValue(forKey: id) else {
                return nil
            }
            let box = unsafe Unmanaged<Ownership.Immutable<K.Value>>.fromOpaque(ptr)
                .takeRetainedValue()
            return box.value
        }
    }
}
