// ===----------------------------------------------------------------------===//
//
// This source file is part of the swift-foundations open source project
//
// Copyright (c) 2024-2025 Coen ten Thije Boonkkamp and the swift-foundations
// project authors
// Licensed under Apache License v2.0
//
// See LICENSE for license information
//
// ===----------------------------------------------------------------------===//

import Testing

@testable import Witnesses

// MARK: - Reserved Case-Name Collision
//
// Regression coverage for `invalid redeclaration of 'count'`: the generated
// `Case` enum conforms to `Finite.Enumerable`, which fixes a `count` protocol
// requirement on that type. A witness operation literally named `count`
// previously produced a case of the same name in `Case`, colliding with the
// requirement — an enum case and a static member share the same namespace in
// Swift regardless of how the member's value is computed, so the two `count`s
// could not coexist. The escaped case identifier (`count_`) lives only on
// `Case`; the outer `Calls` enum, which does not conform to `Finite.Enumerable`,
// keeps the operation's exact name throughout.

extension Witness.Test.Unit {
    @Test
    func `Witness with an operation literally named count expands and compiles`() {
        // Merely constructing this exercises the fixed codegen: prior to the
        // fix, expanding @Witness on CountedOperationsAPI failed with
        // "invalid redeclaration of 'count'".
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
        // Finite.Enumerable.count: the number of cases in Case (2), not
        // anything to do with the "count" operation itself.
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
