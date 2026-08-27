import Witness

extension Witness.Unimplemented {

    public protocol Representable: Swift.Error {

        static func unimplemented(_ error: Witness.Unimplemented.Error) -> Self
    }
}
