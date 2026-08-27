import Witness

extension Witness.Unimplemented {

    public struct Error: Swift.Error, Sendable, Hashable {

        public let witness: String

        public let operation: String

        public let location: Source.Location

        @inlinable
        public init(witness: String, operation: String, location: Source.Location) {
            self.witness = witness
            self.operation = operation
            self.location = location
        }
    }
}

extension Witness.Unimplemented.Error: CustomStringConvertible {
    public var description: String {
        "\(witness).\(operation) is not implemented (created at \(location))"
    }
}
