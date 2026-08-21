public import Async_Lifecycle_Primitives
public import Either_Primitives
import Witness_Primitives

extension Either: Witness.Unimplemented.Representable
where Left == Async.Lifecycle.Error, Right: Witness.Unimplemented.Representable {
    public static func unimplemented(_ error: Witness.Unimplemented.Error) -> Self {
        .right(.unimplemented(error))
    }
}
