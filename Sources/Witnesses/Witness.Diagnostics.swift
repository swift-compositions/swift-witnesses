import Synchronization
import Witness_Primitives

#if canImport(Darwin)
    import Darwin
#elseif canImport(Glibc)

    @preconcurrency import Glibc
#elseif canImport(Musl)

    @preconcurrency import Musl
#elseif os(Windows)

    import CRT
#endif

extension Witness {

    internal enum Diagnostics {

        private static let reported = Mutex<Set<ObjectIdentifier>>([])

        private static let strict: Bool =
            unsafe getenv("DEPENDENCIES_STRICT").map { unsafe String(cString: $0) == "1" } ?? false

        static func testDefaultServedInLive<K: Witness.Key.Test>(_ key: K.Type)
        where K.Value: Copyable & Escapable {
            let message = """
                [swift-witnesses] Test default served in LIVE context: key '\(K.self)' \
                (value: \(K.Value.self)) has no liveValue (Witness.Key.Test-only) and was \
                resolved in .live mode with no explicit override or prepared value — its \
                testValue is standing in for production behavior. Register the value in the \
                app's composition root, or give the key a Witness.Key (liveValue) conformance \
                visible to the accessor's module. (di-composition-root-design.md §4.2)
                """
            #if DEBUG
                fatalError(message)
            #else
                if strict { fatalError(message) }
                let first = reported.withLock { $0.insert(ObjectIdentifier(K.self)).inserted }
                if first {
                    message.withCString { _ = fputs($0, stderr) }
                    _ = fputs("\n", stderr)
                }
            #endif
        }
    }
}
