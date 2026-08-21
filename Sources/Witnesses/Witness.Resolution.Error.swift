extension Witness.Resolution {

    public enum Error: Swift.Error, Sendable, Equatable {

        case cycle(trace: Trace)
    }
}
