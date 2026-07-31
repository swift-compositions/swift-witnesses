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

public import Async_Lifecycle_Primitives
public import Either_Primitives
import Witness_Primitives

/// Composes the C1 unimplemented-placeholder vehicle across the ruled
/// `Either<Async.Lifecycle.Error, Leaf>` witness-error shape
/// (swift-foundations/swift-witnesses#3, comment 5143943680, ratified by
/// comment 5143970225).
///
/// A witness operation typed `throws(Either<Async.Lifecycle.Error, Leaf>)`
/// needs `@Witness`'s generated `unimplemented()` placeholder to produce a
/// total value of that exact `Either` type. The lifecycle envelope
/// (`Async.Lifecycle.Error`) never represents "this witness has no
/// implementation" — that fact belongs to the operation's own domain, so the
/// placeholder always resolves into `.right`, forwarding into the leaf
/// error's own `Representable` conformance (already required by C1 for
/// leaf-typed operations).
extension Either: Witness.Unimplemented.Representable
where Left == Async.Lifecycle.Error, Right: Witness.Unimplemented.Representable {
    public static func unimplemented(_ error: Witness.Unimplemented.Error) -> Self {
        .right(.unimplemented(error))
    }
}
