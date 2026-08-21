import Testing

@testable import Witnesses

extension Witness.Test.Unit {
    @Test
    func `Witness with an operation literally named count expands and compiles`() {

        let api = CountedOperationsAPI.unimplemented()

        #expect(throws: Witness.Unimplemented.Error.self) {
            _ = try api.count()
        }
        #expect(throws: Witness.Unimplemented.Error.self) {
            _ = try api.fetch(id: 1)
        }
    }

    @Test
    func `Outer Calls enum keeps the operation's exact name`() {
        let action = CountedOperationsAPI.Calls.count
        #expect(action.case == .count_)
    }

    @Test
    func `Case enum count protocol requirement is unaffected by the colliding operation`() {

        #expect(CountedOperationsAPI.Calls.Case.count.rawValue == 2)
    }

    @Test
    func `Case discriminant round-trips through ordinal for the colliding case`() {
        let countOrdinal = CountedOperationsAPI.Calls.Case.count_.ordinal
        let roundTripped = CountedOperationsAPI.Calls.Case(_unchecked: (), ordinal: countOrdinal)
        #expect(roundTripped == .count_)
    }

    @Test
    func `Non-colliding case discriminant is untouched`() {
        let action = CountedOperationsAPI.Calls.fetch(id: 1)
        #expect(action.case == .fetch)
    }
}
