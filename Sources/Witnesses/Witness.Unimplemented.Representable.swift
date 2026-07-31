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

import Witness_Primitives

extension Witness.Unimplemented {
    /// A domain leaf error that can represent an unimplemented witness operation.
    ///
    /// `@Witness` generates `unimplemented()` placeholders whose closures throw
    /// `Witness.Unimplemented.Error` when invoked. A closure property typed
    /// untyped `throws` (or `throws(Witness.Unimplemented.Error)`) throws that
    /// error directly. A closure property typed `throws(SomeLeaf.Error)` cannot:
    /// the leaf enum's cases describe that operation's own domain failures and
    /// must not gain a foreign, macro-owned case.
    ///
    /// Conforming the leaf error to `Representable` gives the macro a total way
    /// to produce a placeholder value of that exact type, so `unimplemented()`
    /// throws for every operation — leaf-typed included — instead of falling
    /// back to `fatalError`.
    ///
    /// ```swift
    /// enum Error: Witness.Unimplemented.Representable {
    ///     case invalidInput
    ///     case notImplemented(Witness.Unimplemented.Error)
    ///
    ///     static func unimplemented(_ error: Witness.Unimplemented.Error) -> Self {
    ///         .notImplemented(error)
    ///     }
    /// }
    /// ```
    ///
    /// The wrapping case must not itself be named `unimplemented` — an enum
    /// case's implicit constructor and a static func of the same name and
    /// parameter list collide ("invalid redeclaration"), so it cannot share
    /// this requirement's name.
    public protocol Representable: Swift.Error {
        /// Produces a placeholder value of `Self` carrying the unimplemented
        /// witness's diagnostic information.
        ///
        /// - Parameter error: The witness name, operation signature, and source
        ///   location captured by the generated `unimplemented()` call.
        static func unimplemented(_ error: Witness.Unimplemented.Error) -> Self
    }
}
