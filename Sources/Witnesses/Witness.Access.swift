import Witness_Primitives

extension Witness {

    @propertyWrapper
    public struct Access<Key: Witness.Key>: Sendable
    where Key.Value == Key, Key.Value: Copyable & Escapable {
        @usableFromInline
        internal let initialValues: Witness.Values

        @usableFromInline
        internal let fileID: StaticString

        @usableFromInline
        internal let line: UInt

        @inlinable
        public init(
            _ key: Key.Type,
            fileID: StaticString = #fileID,
            line: UInt = #line
        ) {
            self.initialValues = Witness.Context.current
            self.fileID = fileID
            self.line = line
        }

        @inlinable
        public var wrappedValue: Key.Value {
            let merged = initialValues.merging(Witness.Context.current)
            return merged[Key.self]
        }
    }
}
