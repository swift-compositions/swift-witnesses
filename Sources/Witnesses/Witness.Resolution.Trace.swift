extension Witness.Resolution {

    public struct Trace: Sendable, Equatable {

        public let stack: [ObjectIdentifier]

        public let mode: Witness.Context.Mode

        @inlinable
        public init(stack: [ObjectIdentifier], mode: Witness.Context.Mode) {
            self.stack = stack
            self.mode = mode
        }
    }
}
