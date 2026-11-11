internal import Environment
internal import ISO_9899
import Synchronization
import Witness

extension Witness {

    internal enum Diagnostics {

        private static let reported = Mutex<Set<ObjectIdentifier>>([])

        private static let strict: Bool =
            Environment.read("DEPENDENCIES_STRICT") == "1"

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
                    (message + "\n").withCString { (pointer) -> Void in
                        unsafe ISO_9899.Stdio.put(pointer, to: .error)
                    }
                }
            #endif
        }
    }
}
