public import Async_Lifecycle
public import Either
import Witness

extension Either: Witness.Unimplemented.Representable
where Left == Async.Lifecycle.Error, Right: Witness.Unimplemented.Representable {
    public static func unimplemented(_ error: Witness.Unimplemented.Error) -> Self {
        .right(.unimplemented(error))
    }
}
