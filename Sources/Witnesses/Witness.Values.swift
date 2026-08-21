public import Dependency_Primitives
public import Ownership_Primitives
import Witness_Primitives

extension Witness {

    public struct Values: Sendable {

        @usableFromInline
        internal var _storage: _Storage

        @usableFromInline
        internal var _preparedRef: Witness.Preparation.Store?

        @inlinable
        public init() {
            self._storage = _Storage()
            self._preparedRef = nil
        }

        @usableFromInline
        internal init(preparedStore: Witness.Preparation.Store?) {
            self._storage = _Storage()
            self._preparedRef = preparedStore
        }
    }
}

extension Witness.Values {

    @usableFromInline
    final class _Storage: @unchecked Sendable {
        @usableFromInline
        var dict: [ObjectIdentifier: UnsafeRawPointer]

        @usableFromInline
        init() {
            unsafe (self.dict = [:])
        }

        deinit {
            var iter = unsafe dict.values.makeIterator()
            while let ptr = unsafe iter.next() {
                unsafe Unmanaged<AnyObject>.fromOpaque(ptr).release()
            }
        }
    }
}

extension Witness.Values {

    @inlinable
    package mutating func _ensureUnique() {
        if !isKnownUniquelyReferenced(&_storage) {
            let newStorage = _Storage()

            var iter = unsafe _storage.dict.makeIterator()
            while let (key, ptr) = unsafe iter.next() {
                _ = unsafe Unmanaged<AnyObject>.fromOpaque(ptr).retain()
                unsafe newStorage.set(ptr, for: key)
            }
            _storage = newStorage
        }
    }

    @usableFromInline
    internal func value<K: Witness.Key>(for key: K.Type, mode: Witness.Context.Mode) -> K.Value
    where K.Value: Copyable {
        let id = ObjectIdentifier(K.self)

        if let ptr = unsafe _storage.dict[id] {
            return unsafe Unmanaged<Ownership.Immutable<K.Value>>.fromOpaque(ptr)
                .takeUnretainedValue()
                .value
        }

        if let prepared = _preparedRef?.get(K.self) {
            return prepared
        }

        switch mode {
        case .live:
            return K.liveValue

        case .preview:
            return K.previewValue

        case .test:
            return K.testValue
        }
    }

    @usableFromInline
    internal func value<K: Witness.Key.Test>(for key: K.Type, mode: Witness.Context.Mode) -> K.Value
    where K.Value: Copyable {
        let id = ObjectIdentifier(K.self)

        if let ptr = unsafe _storage.dict[id] {
            return unsafe Unmanaged<Ownership.Immutable<K.Value>>.fromOpaque(ptr)
                .takeUnretainedValue()
                .value
        }

        if let prepared = _preparedRef?.get(K.self) {
            return prepared
        }

        switch mode {
        case .live:

            Witness.Diagnostics.testDefaultServedInLive(K.self)
            return K.testValue

        case .test:
            return K.testValue

        case .preview:
            return K.previewValue
        }
    }

    @usableFromInline
    internal func withValue<K: Witness.Key, R>(
        for key: K.Type,
        mode: Witness.Context.Mode,
        _ body: (borrowing K.Value) -> R
    ) -> R {
        let id = ObjectIdentifier(K.self)

        if let ptr = unsafe _storage.dict[id] {
            return body(
                unsafe Unmanaged<Ownership.Immutable<K.Value>>.fromOpaque(ptr)
                    .takeUnretainedValue()
                    .value
            )
        }

        if let result = _preparedRef?.withValue(K.self, body) {
            return result
        }

        return switch mode {
        case .live: body(K.liveValue)
        case .preview: body(K.previewValue)
        case .test: body(K.testValue)
        }
    }

    @inlinable
    public subscript<K: Witness.Key>(key: K.Type) -> K.Value where K.Value: Copyable {
        get {
            value(for: key, mode: .live)
        }
        set {
            _ensureUnique()
            let id = ObjectIdentifier(K.self)

            if let oldPtr = unsafe _storage.dict[id] {
                unsafe Unmanaged<AnyObject>.fromOpaque(oldPtr).release()
            }

            let box = Ownership.Immutable(newValue)
            let ptr = unsafe UnsafeRawPointer(Unmanaged.passRetained(box).toOpaque())
            unsafe _storage.set(ptr, for: id)
        }
    }

    @inlinable
    public subscript<K: Witness.Key.Test>(key: K.Type) -> K.Value where K.Value: Copyable {
        get {
            value(for: key, mode: .test)
        }
        set {
            _ensureUnique()
            let id = ObjectIdentifier(K.self)

            if let oldPtr = unsafe _storage.dict[id] {
                unsafe Unmanaged<AnyObject>.fromOpaque(oldPtr).release()
            }

            let box = Ownership.Immutable(newValue)
            let ptr = unsafe UnsafeRawPointer(Unmanaged.passRetained(box).toOpaque())
            unsafe _storage.set(ptr, for: id)
        }
    }

    @inlinable
    public subscript<K: Dependency.Key>(key: K.Type) -> K.Value where K.Value: Copyable {
        get {
            let id = ObjectIdentifier(K.self)
            if let ptr = unsafe _storage.dict[id] {
                return unsafe Unmanaged<Ownership.Immutable<K.Value>>.fromOpaque(ptr)
                    .takeUnretainedValue()
                    .value
            }
            return Dependency.Scope.current[K.self]
        }
        set {
            _ensureUnique()
            let id = ObjectIdentifier(K.self)
            if let oldPtr = unsafe _storage.dict[id] {
                unsafe Unmanaged<AnyObject>.fromOpaque(oldPtr).release()
            }
            let box = Ownership.Immutable(newValue)
            let ptr = unsafe UnsafeRawPointer(Unmanaged.passRetained(box).toOpaque())
            unsafe _storage.set(ptr, for: id)
        }
    }

    public mutating func set<K: Witness.Key>(_ key: K.Type, _ value: consuming K.Value) {
        _ensureUnique()
        let id = ObjectIdentifier(K.self)

        if let oldPtr = unsafe _storage.dict[id] {
            unsafe Unmanaged<AnyObject>.fromOpaque(oldPtr).release()
        }

        let box = Ownership.Immutable(value)
        let ptr = unsafe UnsafeRawPointer(Unmanaged.passRetained(box).toOpaque())
        unsafe _storage.set(ptr, for: id)
    }

    @safe
    public func merging(_ other: Witness.Values) -> Witness.Values {
        var result = Witness.Values()

        result._preparedRef = other._preparedRef ?? self._preparedRef

        result._storage.copyFrom(_storage)

        result._storage.copyFrom(other._storage)
        return result
    }
}

extension Witness.Values._Storage {
    @usableFromInline
    func set(_ ptr: UnsafeRawPointer, for key: ObjectIdentifier) {
        unsafe (dict[key] = ptr)
    }

    @usableFromInline
    func copyFrom(_ other: Witness.Values._Storage) {
        var iter = unsafe other.dict.makeIterator()
        while let (key, ptr) = unsafe iter.next() {
            if let oldPtr = unsafe dict[key] {
                unsafe Unmanaged<AnyObject>.fromOpaque(oldPtr).release()
            }
            _ = unsafe Unmanaged<AnyObject>.fromOpaque(ptr).retain()
            unsafe set(ptr, for: key)
        }
    }
}
