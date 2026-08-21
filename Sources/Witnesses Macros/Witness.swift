@_exported public import Finite_Primitives
@_exported public import Optic_Primitives
@_exported public import Witness_Primitives

extension Witness {

    public struct Derive: OptionSet, Sendable, Hashable {
        public let rawValue: UInt8

        @inlinable
        public init(rawValue: UInt8) {
            self.rawValue = rawValue
        }
    }
}

extension Witness.Derive {

    public static let mock = Self(rawValue: 1 << 0)

    public static let generator = Self(rawValue: 1 << 1)
}

@attached(member, names: arbitrary)
@attached(memberAttribute)
@attached(
    extension,
    conformances: Witness_Primitives.__WitnessProtocol,
    Optic_Primitives.__OpticPrismAccessible,
    names: named(unimplemented),
    named(mock)
)
public macro Witness() =
    #externalMacro(
        module: "Witnesses_Macros_Implementation",
        type: "WitnessMacro"
    )

@attached(member, names: arbitrary)
@attached(memberAttribute)
@attached(
    extension,
    conformances: Witness_Primitives.__WitnessProtocol,
    Optic_Primitives.__OpticPrismAccessible,
    names: named(unimplemented),
    named(mock)
)
public macro Witness(_ derive: Witness.Derive) =
    #externalMacro(
        module: "Witnesses_Macros_Implementation",
        type: "WitnessMacro"
    )

@attached(member, names: named(_capturedContext))
@attached(memberAttribute)
public macro WitnessScope() =
    #externalMacro(
        module: "Witnesses_Macros_Implementation",
        type: "WitnessScopeMacro"
    )

@attached(peer, names: arbitrary)
public macro WitnessAccessors() =
    #externalMacro(
        module: "Witnesses_Macros_Implementation",
        type: "WitnessAccessorsMacro"
    )
