import Async_Lifecycle
import Either
import Testing
public import Witnesses

@Witness
struct TestAPI: Sendable {
    var fetch: @Sendable (_ id: Int) async throws(Witness.Unimplemented.Error) -> String
    var update:
        @Sendable (_ id: Int, _ value: String) async throws(Witness.Unimplemented.Error) -> Void
}

@Witness(.mock)
struct MockableAPI: Sendable {
    var fetchUser: @Sendable (_ id: Int) async throws(Witness.Unimplemented.Error) -> String
    var getCount: @Sendable () throws(Witness.Unimplemented.Error) -> Int
    var deleteUser: @Sendable (_ id: Int) async throws(Witness.Unimplemented.Error) -> Void
}

struct SomeHandle: Sendable {
    let id: Int
}

@Witness
struct OwnershipAPI: Sendable {
    var borrow:
        @Sendable (_ handle: borrowing SomeHandle) throws(Witness.Unimplemented.Error) -> Int
    var consume:
        @Sendable (_ handle: consuming SomeHandle) throws(Witness.Unimplemented.Error) -> Void
    var mutate: @Sendable (_ buffer: inout [UInt8]) throws(Witness.Unimplemented.Error) -> Int
    var mixed:
        @Sendable (_ handle: borrowing SomeHandle, _ count: Int, _ buffer: inout [UInt8])
            throws(Witness.Unimplemented.Error) -> Void
}

struct UniqueHandle: ~Copyable, Sendable {
    let id: Int
}

struct HandleProvider: Witness.Key, Sendable {
}

extension HandleProvider {
    typealias Value = UniqueHandle

    static var liveValue: UniqueHandle { UniqueHandle(id: 1) }
    static var testValue: UniqueHandle { UniqueHandle(id: 99) }
    static var previewValue: UniqueHandle { UniqueHandle(id: 50) }
}

struct TokenProvider: Witness.Key, Sendable {
}

extension TokenProvider {
    typealias Value = UniqueHandle

    static var liveValue: UniqueHandle { UniqueHandle(id: 1000) }
    static var testValue: UniqueHandle { UniqueHandle(id: 9999) }
    static var previewValue: UniqueHandle { UniqueHandle(id: 5000) }
}

struct ScopedHandle: ~Copyable, ~Escapable, Sendable {
    let id: Int
}

struct ScopedHandleProvider: Witness.Key, Sendable {
}

extension ScopedHandleProvider {
    typealias Value = ScopedHandle

    static var liveValue: ScopedHandle { fatalError("A nonescapable value requires a scope") }
    static var testValue: ScopedHandle { fatalError("A nonescapable value requires a scope") }
    static var previewValue: ScopedHandle { fatalError("A nonescapable value requires a scope") }
}

@Witness
struct DriverPatternAPI: Sendable {
    let capabilities: Int
    let create: @Sendable () throws(Witness.Unimplemented.Error) -> String
    let operate:
        @Sendable (_ handle: borrowing SomeHandle, _ count: Int) throws(Witness.Unimplemented.Error)
            -> Void
    let close:
        @Sendable (_ handle: consuming SomeHandle) throws(Witness.Unimplemented.Error) -> Void
}

struct NoncopyableHandle: ~Copyable, Sendable {
    let fd: Int32
}

@Witness
struct NoncopyableDriverAPI: Sendable {
    let create: @Sendable () throws(Witness.Unimplemented.Error) -> NoncopyableHandle
    let register:
        @Sendable (borrowing NoncopyableHandle, Int32) throws(Witness.Unimplemented.Error) -> Int
    let poll:
        @Sendable (borrowing NoncopyableHandle, inout [Int32]) throws(Witness.Unimplemented.Error)
            -> Int
    let close: @Sendable (consuming NoncopyableHandle) -> Void
}

@Witness
struct ExistingInitAPI: Sendable {
    var fetch: @Sendable (_ id: Int) throws(Witness.Unimplemented.Error) -> String

    init(fetch: @escaping @Sendable (_ id: Int) throws(Witness.Unimplemented.Error) -> String) {
        self.fetch = fetch
    }
}

@Witness(.generator)
struct IntGenerator: Sendable {
    var generate: @Sendable () throws(Witness.Unimplemented.Error) -> Int
}

enum CustomError: Witness.Unimplemented.Representable, Sendable, Equatable {
    case failed
    case notImplemented(Witness.Unimplemented.Error)

    static func unimplemented(_ error: Witness.Unimplemented.Error) -> Self {
        .notImplemented(error)
    }
}

@Witness
struct ThrowsMatrixAPI: Sendable {
    var bareSync: @Sendable () throws -> Int
    var bareAsync: @Sendable (_ id: Int) async throws -> String
    var typedSync: @Sendable () throws(CustomError) -> Int
    var typedAsync: @Sendable (_ id: Int) async throws(CustomError) -> String
    var nonThrowing: @Sendable () -> Int
}

enum LeafOperationError: Witness.Unimplemented.Representable, Sendable {
    case domainFailure
    case notImplemented(Witness.Unimplemented.Error)

    static func unimplemented(_ error: Witness.Unimplemented.Error) -> Self {
        .notImplemented(error)
    }
}

@Witness
struct UnimplementedThrowsMatrixAPI: Sendable {
    var untyped: @Sendable () throws -> Int
    var leafTyped: @Sendable () throws(LeafOperationError) -> Int
    var neverTyped: @Sendable () throws(Never) -> Int
    var nonThrowing: @Sendable () -> Int
}

@Witness
struct LifecycleComposedAPI: Sendable {
    var fetch: @Sendable () throws(Either<Async.Lifecycle.Error, LeafOperationError>) -> Int
}

@Witness
struct UntypedExistentialSpellingAPI: Sendable {
    var implicitUntyped: @Sendable () throws -> Int
    var explicitAnySwiftError: @Sendable () throws(any Swift.Error) -> Int

    var explicitAnyError: @Sendable () throws(any Error) -> Int
    var explicitSwiftError: @Sendable () throws(Swift.Error) -> Int
    var explicitError: @Sendable () throws(Error) -> Int
}

@Witness
struct TypedLeafNearMissAPI: Sendable {
    var domainLeaf: @Sendable () throws(LeafOperationError) -> Int
    var lifecycleComposedLeaf:
        @Sendable () throws(Either<Async.Lifecycle.Error, LeafOperationError>) -> Int
}

@Witness
struct LineWrappedUntypedExistentialAPI: Sendable {
    var create:
        @Sendable (_ request: Int) async throws(any Swift
            .Error) -> Int
}

@Witness
struct LineWrappedTypedLeafNearMissAPI: Sendable {
    var create: @Sendable (_ request: Int) async throws(LeafOperationError) -> Int
}

@Witness
struct CountedOperationsAPI: Sendable {
    var count: @Sendable () throws(Witness.Unimplemented.Error) -> Int
    var fetch: @Sendable (_ id: Int) throws(Witness.Unimplemented.Error) -> String
}

enum APINamespace {
}

extension APINamespace {
    @Witness
    struct Client: Sendable {
        var fetch: @Sendable (_ id: Int) throws(Witness.Unimplemented.Error) -> String
    }
}

@Witness
struct OptionalCallbackAPI: Sendable {
    var onEvent: @Sendable (_ name: String) throws(Witness.Unimplemented.Error) -> Void
    var onClose: (@Sendable () -> Void)?
}

@Witness
struct NonsendingAPI: Sendable {
    var run:
        nonisolated(nonsending) @Sendable (_ id: Int) async throws(Witness.Unimplemented.Error) ->
            String
    var shutdown: nonisolated(nonsending) @Sendable () async -> Void
    var sync: @Sendable () throws(Witness.Unimplemented.Error) -> Int
}

@Witness
struct OptionalNonsendingAPI: Sendable {
    var onEvent: @Sendable (_ name: String) throws(Witness.Unimplemented.Error) -> Void
    var onComplete: (nonisolated(nonsending) @Sendable () async -> Void)?
}

@Witness
struct RestrictedAccessAPI: Sendable {
    package var restricted: @Sendable () -> Void
    var open: @Sendable () throws(Witness.Unimplemented.Error) -> Void
}

extension TestAPI: Witness.Key {
    static var liveValue: TestAPI {
        TestAPI(
            fetch: { id in "Live result for \(id)" },
            update: { _, _ in }
        )
    }

    static var testValue: TestAPI {
        TestAPI(
            fetch: { id in "Test result for \(id)" },
            update: { _, _ in }
        )
    }
}
