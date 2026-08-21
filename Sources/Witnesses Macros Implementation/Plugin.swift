import SwiftCompilerPlugin
import SwiftSyntaxMacros

@main
struct WitnessesMacrosPlugin: CompilerPlugin {

    let providingMacros: [any Macro.Type] = [
        WitnessMacro.self,
        WitnessScopeMacro.self,
        WitnessAccessorsMacro.self,
    ]
}
