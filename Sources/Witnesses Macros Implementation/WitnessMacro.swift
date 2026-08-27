import SwiftDiagnostics
@_spi(RawSyntax) import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

public struct WitnessMacro {}

struct DeriveOptions: OptionSet {
    let rawValue: UInt8
}

extension DeriveOptions {
    static let mock = Self(rawValue: 1 << 0)
    static let generator = Self(rawValue: 1 << 1)
}

private func parseDeriveOptions(from node: AttributeSyntax) -> DeriveOptions {
    guard let arguments = node.arguments,
        case .argumentList(let argList) = arguments,
        let firstArg = argList.first
    else {
        return []
    }

    var options: DeriveOptions = []

    if let memberAccess = firstArg.expression.as(MemberAccessExprSyntax.self) {
        if let option = deriveOption(from: memberAccess.declName.baseName.text) {
            options.insert(option)
        }
    }

    else if let arrayExpr = firstArg.expression.as(ArrayExprSyntax.self) {
        for element in arrayExpr.elements {
            if let memberAccess = element.expression.as(MemberAccessExprSyntax.self) {
                if let option = deriveOption(from: memberAccess.declName.baseName.text) {
                    options.insert(option)
                }
            }
        }
    }

    return options
}

private func deriveOption(from name: String) -> DeriveOptions? {
    switch name {
    case "mock": return .mock
    case "generator": return .generator
    default: return nil
    }
}

extension WitnessMacro: MemberMacro {
    public static func expansion(
        of node: AttributeSyntax,
        providingMembersOf declaration: some DeclGroupSyntax,
        conformingTo protocols: [TypeSyntax],
        in context: some MacroExpansionContext
    ) throws(Never) -> [DeclSyntax] {

        if let enumDecl = declaration.as(EnumDeclSyntax.self) {
            return expandEnum(enumDecl: enumDecl, node: node, context: context)
        }

        guard let structDecl = declaration.as(StructDeclSyntax.self) else {
            context.diagnose(
                Diagnostic(
                    node: node,
                    message: WitnessDiagnostic.requiresStructOrEnum
                )
            )
            return []
        }

        return expandStruct(structDecl: structDecl, node: node, context: context)
    }

    private static func expandStruct(
        structDecl: StructDeclSyntax,
        node: AttributeSyntax,
        context: some MacroExpansionContext
    ) -> [DeclSyntax] {
        let closureProperties = extractClosureProperties(from: structDecl)

        guard !closureProperties.isEmpty else {
            context.diagnose(
                Diagnostic(
                    node: node,
                    message: WitnessDiagnostic.noClosureProperties
                )
            )
            return []
        }

        var members: [DeclSyntax] = []

        let isPublic = structDecl.modifiers.contains { $0.name.tokenKind == .keyword(.public) }
        let inlinable = canInline(from: structDecl)
        let structName = structDecl.name.text
        let nonClosureProperties = extractNonClosureProperties(from: structDecl)

        let hasExistingInit = structDecl.memberBlock.members.contains { member in
            member.decl.is(InitializerDeclSyntax.self)
        }
        if isPublic && !hasExistingInit {
            members.append(
                generatePublicInit(
                    closureProperties: closureProperties,
                    nonClosureProperties: nonClosureProperties,
                    isPublic: isPublic
                )
            )
        }

        for property in closureProperties where property.hasLabels && !property.isOptional {
            if let method = generateMethod(for: property, inlinable: inlinable) {
                members.append(method)
            }
        }

        let isSendable =
            structDecl.inheritanceClause?.inheritedTypes.contains {
                $0.type.trimmedDescription == "Sendable"
            } ?? false

        members.append(
            contentsOf: generateCallsMembers(for: closureProperties, isSendable: isSendable)
        )

        if isPublic {
            members.append("public typealias _Witness = Self" as DeclSyntax)
        } else if inlinable {
            members.append("@usableFromInline typealias _Witness = Self" as DeclSyntax)
        } else {
            members.append("typealias _Witness = Self" as DeclSyntax)
        }

        members.append(
            generateObserveStruct(
                for: closureProperties,
                nonClosureProperties: nonClosureProperties,
                structName: structName,
                isPublic: isPublic,
                inlinable: inlinable,
                isSendable: isSendable
            )
        )
        members.append(generateObserveProperty())

        members.append(
            generateUnimplementedMember(
                structName: structName,
                closureProperties: closureProperties,
                nonClosureProperties: nonClosureProperties,
                isPublic: isPublic,
                inlinable: inlinable
            )
        )

        let deriveOptions = parseDeriveOptions(from: node)
        if deriveOptions.contains(.mock) {
            members.append(
                generateMockMember(
                    structName: structName,
                    closureProperties: closureProperties,
                    nonClosureProperties: nonClosureProperties,
                    isPublic: isPublic,
                    inlinable: inlinable
                )
            )
        }

        if deriveOptions.contains(.generator), closureProperties.count == 1 {
            let property = closureProperties[0]
            members.append(generateCallAsFunction(for: property, inlinable: inlinable))
            members.append(
                generateConstantMember(
                    structName: structName,
                    property: property,
                    isPublic: isPublic,
                    inlinable: inlinable
                )
            )
        }

        return members
    }

    private static func expandEnum(
        enumDecl: EnumDeclSyntax,
        node: AttributeSyntax,
        context: some MacroExpansionContext
    ) -> [DeclSyntax] {
        let enumCases = extractEnumCases(from: enumDecl)

        guard !enumCases.isEmpty else {
            context.diagnose(
                Diagnostic(
                    node: node,
                    message: WitnessDiagnostic.noEnumCases
                )
            )
            return []
        }

        let enumName = enumDecl.name.text
        return generateEnumPrismMembers(for: enumCases, enumName: enumName)
    }
}

extension WitnessMacro: MemberAttributeMacro {
    public static func expansion(
        of node: AttributeSyntax,
        attachedTo declaration: some DeclGroupSyntax,
        providingAttributesFor member: some DeclSyntaxProtocol,
        in context: some MacroExpansionContext
    ) throws(Never) -> [AttributeSyntax] {

        if declaration.is(EnumDeclSyntax.self) {
            return []
        }

        guard let varDecl = member.as(VariableDeclSyntax.self),
            let binding = varDecl.bindings.first,
            binding.accessorBlock == nil,
            let identifier = binding.pattern.as(IdentifierPatternSyntax.self),
            let typeAnnotation = binding.typeAnnotation
        else {
            return []
        }

        var attributes: [AttributeSyntax] = []

        if let structDecl = declaration.as(StructDeclSyntax.self) {
            let isPublicStruct = structDecl.modifiers.contains {
                $0.name.tokenKind == .keyword(.public)
            }
            let isPublicMember = varDecl.modifiers.contains {
                $0.name.tokenKind == .keyword(.public)
            }
            if isPublicStruct && !isPublicMember && !hasRestrictedAccess(varDecl.modifiers) {
                attributes.append(AttributeSyntax(stringLiteral: "@usableFromInline"))
            }
        }

        return attributes
    }
}

extension WitnessMacro: ExtensionMacro {
    public static func expansion(
        of node: AttributeSyntax,
        attachedTo declaration: some DeclGroupSyntax,
        providingExtensionsOf type: some TypeSyntaxProtocol,
        conformingTo protocols: [TypeSyntax],
        in context: some MacroExpansionContext

    ) throws -> [ExtensionDeclSyntax] {
        var extensions: [ExtensionDeclSyntax] = []

        let alreadyConformsToWitnessProtocol =
            declaration.inheritanceClause?.inheritedTypes.contains { inherited in
                let text = inherited.type.trimmedDescription
                return text == "__WitnessProtocol" || text == "Witness.`Protocol`"
                    || text == "Witness.Protocol" || text.hasSuffix(".__WitnessProtocol")
            } ?? false

        if !alreadyConformsToWitnessProtocol {
            let witnessExt = try ExtensionDeclSyntax(
                "extension \(type.trimmed): Witness.__WitnessProtocol {}"
            )
            extensions.append(witnessExt)
        }

        if declaration.is(EnumDeclSyntax.self) {
            let prismExt = try ExtensionDeclSyntax(
                "extension \(type.trimmed): Optic.__OpticPrismAccessible {}"
            )
            extensions.append(prismExt)
        }

        return extensions
    }

}

private let untypedErrorExistentialSpellings: Set<String> = [
    "any Swift.Error",
    "any Error",
    "Swift.Error",
    "Error",
]

private let normalizedUntypedErrorExistentialSpellings: Set<String> =
    Set(untypedErrorExistentialSpellings.map(removingWhitespace))

private func normalizedTypeSpelling(_ type: TypeSyntax) -> String {
    removingWhitespace(type.trimmedDescription)
}

private func removingWhitespace(_ string: String) -> String {
    string.filter { !$0.isWhitespace }
}

private func throwsUnimplementedErrorDirectly(_ property: ClosureProperty) -> Bool {
    guard property.isThrowing else { return false }
    guard let throwsType = property.throwsType else { return true }
    let typeName = normalizedTypeSpelling(throwsType)
    return typeName == "Witness.Unimplemented.Error"
        || normalizedUntypedErrorExistentialSpellings.contains(typeName)
}

private func throwsUnimplementedErrorViaLeaf(_ property: ClosureProperty) -> Bool {
    guard property.isThrowing, let throwsType = property.throwsType else { return false }
    let typeName = normalizedTypeSpelling(throwsType)
    return typeName != "Witness.Unimplemented.Error"
        && typeName != "Never"
        && !normalizedUntypedErrorExistentialSpellings.contains(typeName)
}

private func needsUnimplementedLocation(_ property: ClosureProperty) -> Bool {
    throwsUnimplementedErrorDirectly(property) || throwsUnimplementedErrorViaLeaf(property)
}

private func generateUnimplementedMember(
    structName: String,
    closureProperties: [ClosureProperty],
    nonClosureProperties: [NonClosureProperty],
    isPublic: Bool,
    inlinable: Bool = true
) -> DeclSyntax {
    let accessModifier = isPublic ? "public " : ""
    let inlinableAttr = inlinable ? "@inlinable\n    " : ""

    let needsSourceLocation = closureProperties.contains(where: needsUnimplementedLocation)

    let closureInits = closureProperties.map { property in
        generateUnimplementedClosure(for: property, structName: structName, isPublic: isPublic)
    }.joined(separator: ",\n            ")

    let nonClosureParamList = nonClosureProperties.map { "\($0.name): \($0.type)" }
    var paramParts = nonClosureParamList
    if needsSourceLocation {
        paramParts += [
            "fileID: Swift.String = #fileID",
            "filePath: Swift.String = #filePath",
            "line: Int = #line",
            "column: Int = #column",
        ]
    }
    let allParams = paramParts.joined(separator: ",\n        ")

    let allInits = joinInitArguments(
        nonClosureProperties: nonClosureProperties,
        closureInits: closureInits
    )

    let locationCode =
        needsSourceLocation
        ? "\n        let location = Source.Location(fileID: fileID, filePath: filePath, line: line, column: column)"
        : ""

    return """
        \(raw: inlinableAttr)\(raw: accessModifier)static func unimplemented(
            \(raw: allParams)
        ) -> Self {\(raw: locationCode)
            return Self(
                \(raw: allInits)
            )
        }
        """
}

private func generateMockMember(
    structName: String,
    closureProperties: [ClosureProperty],
    nonClosureProperties: [NonClosureProperty],
    isPublic: Bool,
    inlinable: Bool = true
) -> DeclSyntax {
    let accessModifier = isPublic ? "public " : ""
    let inlinableAttr = inlinable ? "@inlinable\n    " : ""

    let mockParameters = closureProperties.compactMap { property -> String? in
        property.isOptional ? nil : generateMockParameter(for: property)
    }

    let nonClosureParamList = nonClosureProperties.map { "\($0.name): \($0.type)" }
    let allParams = (nonClosureParamList + mockParameters)
        .joined(separator: ",\n        ")

    let closureInits = closureProperties.map { property in
        generateMockClosure(for: property, isPublic: isPublic)
    }.joined(separator: ",\n            ")

    let allInits = joinInitArguments(
        nonClosureProperties: nonClosureProperties,
        closureInits: closureInits
    )

    return """
        \(raw: inlinableAttr)\(raw: accessModifier)static func mock(
            \(raw: allParams)
        ) -> Self {
            Self(
                \(raw: allInits)
            )
        }
        """
}

private func joinInitArguments(
    nonClosureProperties: [NonClosureProperty],
    closureInits: String
) -> String {
    let nonClosureInits = nonClosureProperties.map { "\($0.name): \($0.name)" }
    if nonClosureInits.isEmpty {
        return closureInits
    }
    return nonClosureInits.joined(separator: ",\n            ") + ",\n            " + closureInits
}

private func generateConstantMember(
    structName: String,
    property: ClosureProperty,
    isPublic: Bool,
    inlinable: Bool = true
) -> DeclSyntax {
    let accessModifier = isPublic ? "public " : ""
    let inlinableAttr = inlinable ? "@inlinable\n    " : ""
    let initLabel = property.initLabel(isPublic: isPublic)
    let returnType = property.returnType.trimmedDescription
    let throwsAnnotation = property.throwsAnnotation

    let closureParams = property.closureParameterList(named: false)
    let closureBody = "{ \(closureParams) \(throwsAnnotation)-> \(returnType) in value }"

    return """
        \(raw: inlinableAttr)\(raw: accessModifier)static func constant(_ value: \(raw: returnType)) -> Self {
            Self(\(raw: initLabel): \(raw: closureBody))
        }
        """
}

private func generateMockParameter(for property: ClosureProperty) -> String {
    let returnType = property.returnType.trimmedDescription

    if property.returnsVoid {
        return "\(property.methodName): Void = ()"
    } else {
        return "\(property.methodName): \(returnType)"
    }
}

private func generateMockClosure(for property: ClosureProperty, isPublic: Bool) -> String {
    let initLabel = property.initLabel(isPublic: isPublic)
    if property.isOptional { return "\(initLabel): nil" }
    let returnType = property.returnType.trimmedDescription
    let throwsAnnotation = property.throwsAnnotation
    let closureParams = property.closureParameterList(named: false)

    let body = property.returnsVoid ? "" : " \(property.methodName) "
    return "\(initLabel): { \(closureParams) \(throwsAnnotation)-> \(returnType) in\(body)}"
}

struct ClosureProperty {
    let name: String
    let functionType: FunctionTypeSyntax
    let parameters: [ClosureParameter]
    let hasLabels: Bool
    let isAsync: Bool
    let isThrowing: Bool

    let throwsType: TypeSyntax?
    let returnType: TypeSyntax

    let originalType: TypeSyntax

    let isOptional: Bool
}

extension ClosureProperty {

    var isConcurrent: Bool {
        guard let attributed = originalType.as(AttributedTypeSyntax.self) else { return false }
        return attributed.attributes.contains { attr in
            attr.as(AttributeSyntax.self)?.attributeName.trimmedDescription == "concurrent"
        }
    }

    var needsNonsendingAnnotation: Bool {
        guard isAsync else { return false }
        guard let attributed = originalType.as(AttributedTypeSyntax.self) else { return false }
        return attributed.attributes.contains { attr in
            attr.trimmedDescription.hasPrefix("nonisolated")
        }
    }

    var methodName: String { name }

    var throwsAnnotation: String {
        if let throwsType {
            return "throws(\(throwsType.trimmedDescription)) "
        } else if isThrowing {
            return "throws "
        } else {
            return ""
        }
    }

    var derivedFailureType: String {
        if let throwsType {
            return throwsType.trimmedDescription
        }
        return isThrowing ? "any Swift.Error" : "Never"
    }

    var observeDoClause: String {
        if let throwsType {
            return "do throws(\(throwsType.trimmedDescription)) "
        }
        return "do "
    }

    var returnsVoid: Bool {
        let rt = returnType.trimmedDescription
        return rt == "Void" || rt == "()"
    }

    func initLabel(isPublic: Bool) -> String { name }

    var effectSpecifiers: String {
        var specs: [String] = []
        if isAsync { specs.append("async") }
        if isThrowing {
            if let throwsType {
                specs.append("throws(\(throwsType.trimmedDescription))")
            } else {
                specs.append("throws")
            }
        }
        return specs.isEmpty ? "" : " " + specs.joined(separator: " ")
    }

    var awaitPrefix: String {
        isAsync ? "await " : ""
    }

    var tryPrefix: String {
        isThrowing ? "try " : ""
    }

    var returnClause: String {
        returnsVoid ? "" : " -> \(returnType)"
    }

    func closureParameterList(named: Bool) -> String {
        if parameters.isEmpty { return "()" }
        if !named {
            let underscores = parameters.map { _ in "_" }.joined(separator: ", ")
            return "(\(underscores))"
        }
        let parts = parameters.enumerated().map { index, param in
            let n = param.label ?? "p\(index)"
            if param.isInout {
                return "\(n): inout \(param.baseType)"
            } else if let ownership = param.ownership {
                return "\(n): \(ownership) \(param.baseType)"
            }
            return n
        }
        return "(\(parts.joined(separator: ", ")))"
    }

    var callArgumentList: String {
        parameters.enumerated().map { index, param in
            let n = param.label ?? "p\(index)"
            if param.isInout { return "&\(n)" }
            if param.ownership == .consuming { return "consume \(n)" }
            return n
        }.joined(separator: ", ")
    }

    var methodParameterList: String {
        parameters.enumerated().map { index, param in
            let label = param.label ?? "_"
            let internalName = "p\(index)"
            return "\(label) \(internalName): \(param.type)"
        }.joined(separator: ", ")
    }

    var positionalCallArguments: String {
        parameters.enumerated().map { index, param in
            let prefix = param.isInout ? "&" : ""
            return "\(prefix)p\(index)"
        }.joined(separator: ", ")
    }
}

struct ClosureParameter {
    let label: String?
    let internalName: String
    let type: TypeSyntax
    let isInout: Bool

    let ownership: Keyword?
}

extension ClosureParameter {

    var hasOwnershipAnnotation: Bool {
        isInout || ownership != nil
    }

    var baseType: TypeSyntax {
        var result = type
        if hasOwnershipAnnotation,
            let attributed = result.as(AttributedTypeSyntax.self)
        {
            result = attributed.baseType
        }
        if let attributed = result.as(AttributedTypeSyntax.self) {
            let filtered = attributed.attributes.filter { attr in
                guard case .attribute(let a) = attr else { return true }
                return a.attributeName.trimmedDescription != "escaping"
            }
            if filtered.isEmpty && attributed.specifiers.isEmpty {
                return attributed.baseType.trimmed
            }
            var cleaned = attributed
            cleaned.attributes = filtered
            return TypeSyntax(cleaned).trimmed
        }
        return result.trimmed
    }
}

private func hasRestrictedAccess(_ modifiers: DeclModifierListSyntax) -> Bool {
    modifiers.contains {
        $0.name.tokenKind == .keyword(.package) || $0.name.tokenKind == .keyword(.private)
            || $0.name.tokenKind == .keyword(.fileprivate)
    }
}

private func canInline(from structDecl: StructDeclSyntax) -> Bool {
    structDecl.memberBlock.members.allSatisfy { member in
        guard let varDecl = member.decl.as(VariableDeclSyntax.self),
            let binding = varDecl.bindings.first,
            binding.accessorBlock == nil
        else { return true }
        return !hasRestrictedAccess(varDecl.modifiers)
    }
}

private func extractClosureProperties(from structDecl: StructDeclSyntax) -> [ClosureProperty] {
    var properties: [ClosureProperty] = []

    for member in structDecl.memberBlock.members {
        guard let varDecl = member.decl.as(VariableDeclSyntax.self),
            varDecl.bindingSpecifier.tokenKind == .keyword(.var)
                || varDecl.bindingSpecifier.tokenKind == .keyword(.let),
            let binding = varDecl.bindings.first,
            let identifier = binding.pattern.as(IdentifierPatternSyntax.self),
            let typeAnnotation = binding.typeAnnotation,
            let functionType = extractFunctionType(from: typeAnnotation.type)
        else {
            continue
        }

        let parameters = extractParameters(from: functionType)
        let hasLabels = parameters.contains { $0.label != nil }

        let throwsType: TypeSyntax? = functionType.effectSpecifiers?.throwsClause?.type

        properties.append(
            ClosureProperty(
                name: identifier.identifier.text,
                functionType: functionType,
                parameters: parameters,
                hasLabels: hasLabels,
                isAsync: functionType.effectSpecifiers?.asyncSpecifier != nil,
                isThrowing: functionType.effectSpecifiers?.throwsClause != nil,
                throwsType: throwsType,
                returnType: functionType.returnClause.type,
                originalType: typeAnnotation.type,
                isOptional: typeAnnotation.type.as(OptionalTypeSyntax.self) != nil
            )
        )
    }

    return properties
}

private func extractFunctionType(from type: TypeSyntax) -> FunctionTypeSyntax? {

    if let functionType = type.as(FunctionTypeSyntax.self) {
        return functionType
    }

    if let attributed = type.as(AttributedTypeSyntax.self) {
        return extractFunctionType(from: attributed.baseType)
    }

    if let optional = type.as(OptionalTypeSyntax.self) {
        return extractFunctionType(from: optional.wrappedType)
    }

    if let tuple = type.as(TupleTypeSyntax.self),
        tuple.elements.count == 1,
        let element = tuple.elements.first
    {
        return extractFunctionType(from: element.type)
    }

    return nil
}

private func extractParameters(from functionType: FunctionTypeSyntax) -> [ClosureParameter] {
    var parameters: [ClosureParameter] = []

    for (index, param) in functionType.parameters.enumerated() {
        let label: String? = {
            if let second = param.secondName?.text {
                return second
            }
            if let first = param.firstName?.text, first != "_" {
                return first
            }
            return nil
        }()
        let internalName = label ?? "p\(index)"

        var isInout = false
        var ownership: Keyword? = nil

        if let attributed = param.type.as(AttributedTypeSyntax.self) {
            for specifier in attributed.specifiers {
                if let simple = specifier.as(SimpleTypeSpecifierSyntax.self) {
                    switch simple.specifier.tokenKind {
                    case .keyword(.inout):
                        isInout = true

                    case .keyword(.borrowing):
                        ownership = .borrowing

                    case .keyword(.consuming):
                        ownership = .consuming

                    default:
                        break
                    }
                }
            }
        }

        parameters.append(
            ClosureParameter(
                label: label,
                internalName: internalName,
                type: param.type,
                isInout: isInout,
                ownership: ownership
            )
        )
    }

    return parameters
}

private func generatePublicInit(
    closureProperties: [ClosureProperty],
    nonClosureProperties: [NonClosureProperty],
    isPublic: Bool
) -> DeclSyntax {
    var initParameters: [String] = []
    var assignments: [String] = []

    for prop in nonClosureProperties {
        initParameters.append("\(prop.name): \(prop.type)")
        assignments.append("self.\(prop.name) = \(prop.name)")
    }

    for prop in closureProperties {
        let label = prop.initLabel(isPublic: isPublic)
        if prop.isOptional {

            initParameters.append("\(label): \(prop.originalType.trimmedDescription) = nil")
        } else {

            initParameters.append("\(label): @escaping \(prop.originalType.trimmedDescription)")
        }
        if label != prop.name {
            assignments.append("self.\(prop.name) = \(label)")
        } else {
            assignments.append("self.\(prop.name) = \(prop.name)")
        }
    }

    let parameterList = initParameters.joined(separator: ",\n        ")
    let assignmentList = assignments.joined(separator: "\n        ")

    return """
        public init(
            \(raw: parameterList)
        ) {
            \(raw: assignmentList)
        }
        """
}

private func generateMethod(for property: ClosureProperty, inlinable: Bool = true) -> DeclSyntax? {
    guard property.hasLabels, !property.isOptional else { return nil }
    let inlinableAttr = inlinable ? "@inlinable\n        " : ""

    return """
        \(raw: inlinableAttr)public func \(raw: property.methodName)(\(raw: property.methodParameterList))\(raw: property.effectSpecifiers)\(raw: property.returnClause) {
            \(raw: property.tryPrefix)\(raw: property.awaitPrefix)self.\(raw: property.name)(\(raw: property.positionalCallArguments))
        }
        """
}

private func generateCallAsFunction(
    for property: ClosureProperty,
    inlinable: Bool = true
) -> DeclSyntax {
    let inlinableAttr = inlinable ? "@inlinable\n        " : ""
    return """
        \(raw: inlinableAttr)public func callAsFunction(\(raw: property.methodParameterList))\(raw: property.effectSpecifiers)\(raw: property.returnClause) {
            \(raw: property.tryPrefix)\(raw: property.awaitPrefix)self.\(raw: property.name)(\(raw: property.positionalCallArguments))
        }
        """
}

private func generateMethodSignature(name: String, functionType: FunctionTypeSyntax) -> String {
    let labels = functionType.parameters.map { param in
        if let second = param.secondName?.text { return second }
        if let first = param.firstName?.text, first != "_" { return first }
        return "_"
    }

    if labels.isEmpty {
        return "\(name)()"
    }

    let labelString = labels.map { "\($0):" }.joined()
    return "\(name)(\(labelString))"
}

private func generateCallsMembers(
    for properties: [ClosureProperty],
    isSendable: Bool
) -> [DeclSyntax] {
    let actionCases = generateCallsCases(for: properties)
    let caseEnum = generateCaseEnum(for: properties)
    let caseProperty = generateCallsCaseProperty(for: properties)
    let resultEnum = generateResultEnum(for: properties)
    let prismProperties = generatePrismProperties(for: properties)

    let callsEnum: DeclSyntax = """
        public enum Calls\(raw: isSendable ? ": Sendable" : "") {
            \(raw: actionCases)

            \(raw: caseEnum)

            \(raw: caseProperty)

            public struct Prisms: Sendable {
                @inlinable
                public init() {}

                \(raw: prismProperties)
            }

            @inlinable
            public static var prisms: Prisms { Prisms() }

            @inlinable
            public func `is`<Value>(_ keyPath: KeyPath<Prisms, Optic.Optic.Prism<Calls, Value>>) -> Bool {
                Self.prisms[keyPath: keyPath].extract(self) != nil
            }

            @inlinable
            public subscript<Value>(prism keyPath: KeyPath<Prisms, Optic.Optic.Prism<Calls, Value>>) -> Value? {
                Self.prisms[keyPath: keyPath].extract(self)
            }
        }
        """

    let resultDecl: DeclSyntax = """
        \(raw: resultEnum)
        """

    let outcomeDecl: DeclSyntax = """
        public struct Outcome: ~Copyable {
            public let action: Calls
            public let result: Result

            @inlinable
            public init(action: Calls, result: consuming Result) {
                self.action = action
                self.result = result
            }

            @usableFromInline
            consuming func __consumeResult() -> Result { result }
        }
        """

    return [callsEnum, resultDecl, outcomeDecl]
}

private func generateCallsCases(for properties: [ClosureProperty]) -> String {
    properties.map { property in
        let copyableParams = property.parameters.filter { !$0.hasOwnershipAnnotation }
        if copyableParams.isEmpty {
            return "case \(property.methodName)"
        }
        let assocValues = copyableParams.map { param in
            if let label = param.label {
                return "\(label): \(param.baseType)"
            }
            return "\(param.baseType)"
        }.joined(separator: ", ")
        return "case \(property.methodName)(\(assocValues))"
    }.joined(separator: "\n            ")
}

private let reservedCaseEnumMemberNames: Set<String> = ["count", "ordinal", "allCases"]

private func caseEnumCaseName(for methodName: String) -> String {
    reservedCaseEnumMemberNames.contains(methodName) ? "\(methodName)_" : methodName
}

private func generateCaseEnum(for properties: [ClosureProperty]) -> String {
    let caseCount = properties.count
    let caseCases = properties.map { "case \(caseEnumCaseName(for: $0.methodName))" }.joined(
        separator: "\n                "
    )
    let ordinalCases = properties.enumerated().map { i, p in
        "case .\(caseEnumCaseName(for: p.methodName)): Ordinal.Ordinal(\(i))"
    }.joined(separator: "\n                    ")

    let initCases: String
    if properties.count == 1 {
        initCases = "default: self = .\(caseEnumCaseName(for: properties[0].methodName))"
    } else {
        let explicit = properties.dropLast().enumerated().map { i, p in
            "case \(i): self = .\(caseEnumCaseName(for: p.methodName))"
        }.joined(separator: "\n                    ")
        initCases =
            explicit
            + "\n                    default: self = .\(caseEnumCaseName(for: properties.last!.methodName))"
    }

    return """
        public enum Case: Finite.Finite.Enumerable, Sendable {
                    \(caseCases)

                    @inlinable
                    public static var count: Cardinal.Cardinal { Cardinal.Cardinal(\(caseCount)) }

                    @inlinable
                    public var ordinal: Ordinal.Ordinal {
                        switch self {
                        \(ordinalCases)
                        }
                    }

                    @inlinable
                    public init(_unchecked: Void, ordinal: Ordinal.Ordinal) {
                        switch ordinal.rawValue {
                        \(initCases)
                        }
                    }
                }
        """
}

private func generateCallsCaseProperty(for properties: [ClosureProperty]) -> String {
    let cases = properties.map {
        "case .\($0.methodName): .\(caseEnumCaseName(for: $0.methodName))"
    }
    .joined(separator: "\n                ")
    return """
        @inlinable
                public var `case`: Case {
                    switch self {
                    \(cases)
                    }
                }
        """
}

private func generateResultEnum(for properties: [ClosureProperty]) -> String {
    let cases = properties.map { property in
        generateTypedResultCase(for: property)
    }.joined(separator: "\n                ")
    return """
        public enum Result: ~Copyable {
                    \(cases)
                }
        """
}

private func generateTypedResultCase(for property: ClosureProperty) -> String {
    let returnType = property.returnType.trimmedDescription
    let errorType = property.derivedFailureType
    return
        "case \(property.methodName)(Standard_Library_Extensions.Result<\(returnType), \(errorType)>)"
}

private func generatePrismProperties(for properties: [ClosureProperty]) -> String {
    properties.map { property in
        generatePrismProperty(for: property)
    }.joined(separator: "\n\n                ")
}

private func generatePrismProperty(for property: ClosureProperty) -> String {
    let copyableParams = property.parameters.filter { !$0.hasOwnershipAnnotation }
    let prismCase = PrismCase(
        caseName: property.methodName,
        rootTypeName: "Calls",
        parameters: copyableParams.map { ($0.label, $0.baseType.trimmedDescription) }
    )
    return generatePrism(for: prismCase)
}

struct NonClosureProperty {
    let name: String
    let type: String
}

private func extractNonClosureProperties(from structDecl: StructDeclSyntax) -> [NonClosureProperty]
{
    var properties: [NonClosureProperty] = []
    for member in structDecl.memberBlock.members {
        guard let varDecl = member.decl.as(VariableDeclSyntax.self),
            let binding = varDecl.bindings.first,
            binding.accessorBlock == nil,
            let identifier = binding.pattern.as(IdentifierPatternSyntax.self),
            let typeAnnotation = binding.typeAnnotation,
            extractFunctionType(from: typeAnnotation.type) == nil
        else {
            continue
        }
        properties.append(
            NonClosureProperty(
                name: identifier.identifier.text,
                type: typeAnnotation.type.trimmedDescription
            )
        )
    }
    return properties
}

private func generateUnimplementedClosure(
    for property: ClosureProperty,
    structName: String,
    isPublic: Bool
) -> String {
    let initLabel = property.initLabel(isPublic: isPublic)

    if property.isOptional { return "\(initLabel): nil" }

    let operationSignature = buildOperationSignature(for: property)
    let throwsAnnotation = property.throwsAnnotation

    let returnType = property.returnType.trimmedDescription
    let hasConsumingParams = property.parameters.contains { $0.ownership == .consuming }

    let canThrowUnimplemented = throwsUnimplementedErrorDirectly(property)

    let canThrowViaLeaf = throwsUnimplementedErrorViaLeaf(property)
    let needsFatalError = !canThrowUnimplemented && !canThrowViaLeaf

    let closureStart: String
    if property.parameters.isEmpty {
        closureStart = "{ () \(throwsAnnotation)-> \(returnType) in"
    } else if needsFatalError && hasConsumingParams {
        let paramBindings = property.parameters.enumerated().map { index, param in
            if param.ownership == .consuming {
                return "p\(index): consuming \(param.baseType)"
            }
            return "_"
        }.joined(separator: ", ")
        closureStart = "{ (\(paramBindings)) \(throwsAnnotation)-> \(returnType) in"
    } else {
        let underscoreParams = property.parameters.map { _ in "_" }.joined(separator: ", ")
        closureStart = "{ (\(underscoreParams)) \(throwsAnnotation)-> \(returnType) in"
    }

    if canThrowUnimplemented {

        return """
            \(initLabel): \(closureStart)
                            throw Witness.Unimplemented.Error(
                                witness: "\(structName)",
                                operation: "\(operationSignature)",
                                location: location
                            )
                        }
            """
    } else if canThrowViaLeaf {

        return """
            \(initLabel): \(closureStart)
                            throw .unimplemented(
                                Witness.Unimplemented.Error(
                                    witness: "\(structName)",
                                    operation: "\(operationSignature)",
                                    location: location
                                )
                            )
                        }
            """
    } else if hasConsumingParams {

        let consumeStatements = property.parameters.enumerated().compactMap {
            index,
            param -> String? in
            guard param.ownership == .consuming else { return nil }
            return "_ = consume p\(index)"
        }.joined(separator: "\n                ")
        return """
            \(initLabel): \(closureStart)
                            \(consumeStatements)
                            fatalError("\\(Self.self).\\(#function) is unimplemented")
                        }
            """
    } else {

        return """
            \(initLabel): \(closureStart)
                            fatalError("\\(Self.self).\\(#function) is unimplemented")
                        }
            """
    }
}

private func buildOperationSignature(for property: ClosureProperty) -> String {
    if property.parameters.isEmpty {
        return "\(property.methodName)()"
    }

    let labels = property.parameters.map { param in
        param.label ?? "_"
    }

    let labelString = labels.map { "\($0):" }.joined()
    return "\(property.methodName)(\(labelString))"
}

private func generateObserveStruct(
    for properties: [ClosureProperty],
    nonClosureProperties: [NonClosureProperty],
    structName: String,
    isPublic: Bool,
    inlinable: Bool = true,
    isSendable: Bool = true
) -> DeclSyntax {

    let nonClosurePassthrough = nonClosureProperties.map { "\($0.name): witness.\($0.name)" }

    let bothClosures = properties.map {
        generateObserveClosure(for: $0, variant: .both, isPublic: isPublic)
    }
    let beforeClosures = properties.map {
        generateObserveClosure(for: $0, variant: .before, isPublic: isPublic)
    }
    let afterClosures = properties.map {
        generateObserveClosure(for: $0, variant: .after, isPublic: isPublic)
    }

    let bothInitArgs = (nonClosurePassthrough + bothClosures).joined(
        separator: ",\n                    "
    )
    let beforeInitArgs = (nonClosurePassthrough + beforeClosures).joined(
        separator: ",\n                    "
    )
    let afterInitArgs = (nonClosurePassthrough + afterClosures).joined(
        separator: ",\n                    "
    )

    let ufiAttr = inlinable ? "@usableFromInline\n            " : ""
    let inlinableAttr = inlinable ? "@inlinable\n            " : ""

    return """
        public struct Observe\(raw: isSendable ? ": Sendable" : "") {
            \(raw: ufiAttr)internal let witness: _Witness

            \(raw: ufiAttr)internal init(_ witness: _Witness) {
                self.witness = witness
            }

            \(raw: inlinableAttr)public func callAsFunction(
                _ before: @escaping \(raw: isSendable ? "@Sendable " : "")(Calls) -> Void,
                after: @escaping \(raw: isSendable ? "@Sendable " : "")(borrowing Outcome) -> Void
            ) -> _Witness {
                _Witness(
                    \(raw: bothInitArgs)
                )
            }

            \(raw: inlinableAttr)public func before(
                _ observer: @escaping \(raw: isSendable ? "@Sendable " : "")(Calls) -> Void
            ) -> _Witness {
                _Witness(
                    \(raw: beforeInitArgs)
                )
            }

            \(raw: inlinableAttr)public func after(
                _ observer: @escaping \(raw: isSendable ? "@Sendable " : "")(borrowing Outcome) -> Void
            ) -> _Witness {
                _Witness(
                    \(raw: afterInitArgs)
                )
            }
        }
        """
}

private func generateObserveProperty() -> DeclSyntax {
    return """
        public var observe: Observe {
            Observe(self)
        }
        """
}

private enum ObserveVariant {
    case before
    case after
    case both
}

private func generateObserveClosure(
    for property: ClosureProperty,
    variant: ObserveVariant,
    isPublic: Bool
) -> String {
    let initLabel = property.initLabel(isPublic: isPublic)
    let closureParams = property.closureParameterList(named: true)
    let callArgs = property.callArgumentList
    let returnType = property.returnType.trimmedDescription
    let throwsAnno = property.isThrowing ? property.throwsAnnotation : ""

    if property.isOptional {

        if property.isAsync,
            let optionalWrapped = property.originalType.as(OptionalTypeSyntax.self)?.wrappedType
        {

            let innerType: TypeSyntax
            if let tuple = optionalWrapped.as(TupleTypeSyntax.self),
                tuple.elements.count == 1,
                let single = tuple.elements.first
            {
                innerType = single.type
            } else {
                innerType = optionalWrapped
            }
            if let attributed = innerType.as(AttributedTypeSyntax.self),
                !attributed.attributes.contains(where: {
                    $0.as(AttributeSyntax.self)?.attributeName.trimmedDescription == "concurrent"
                }),
                attributed.attributes.contains(where: {
                    $0.as(AttributeSyntax.self)?.attributeName.trimmedDescription == "Sendable"
                })
            {
                return "\(initLabel): witness.\(property.name)"
            }
        }
        let innerBody = generateObserveBody(
            for: property,
            variant: variant,
            callExpression: "_original(\(callArgs))"
        )

        let wrappedType =
            property.originalType.as(OptionalTypeSyntax.self)?.wrappedType.trimmedDescription
            ?? property.functionType.trimmedDescription
        return """
            \(initLabel): witness.\(property.name).map { _original -> \(wrappedType) in
                            { \(closureParams) \(throwsAnno)-> \(returnType) in
                        \(innerBody)
                            }
                        }
            """
    }

    if property.needsNonsendingAnnotation {
        return "\(initLabel): witness.\(property.name)"
    }

    let body = generateObserveBody(
        for: property,
        variant: variant,
        callExpression: "witness.\(property.name)(\(callArgs))"
    )

    return """
        \(initLabel): { [witness] \(closureParams) \(throwsAnno)-> \(returnType) in
        \(body)
                    }
        """
}

private func generateObserveBody(
    for property: ClosureProperty,
    variant: ObserveVariant,
    callExpression: String
) -> String {
    let actionConstruction = formatCallsConstruction(for: property)
    let returnType = property.returnType.trimmedDescription
    let hasReturn = !property.returnsVoid
    let errorType = property.derivedFailureType
    let witnessResultType = "Standard_Library_Extensions.Result<\(returnType), \(errorType)>"

    let beforeCall: String
    let afterCall: String
    switch variant {
    case .before:
        beforeCall = "observer"
        afterCall = ""

    case .after:
        beforeCall = ""
        afterCall = "observer"

    case .both:
        beforeCall = "before"
        afterCall = "after"
    }

    func outcomeExpr(witnessResult: String) -> String {
        "Outcome(action: action, result: Result.\(property.methodName)(\(witnessResult)))"
    }

    switch variant {
    case .before:
        let returnKeyword = hasReturn ? "return " : ""
        return """
                            \(beforeCall)(\(actionConstruction))
                            \(returnKeyword)\(property.tryPrefix)\(property.awaitPrefix)\(callExpression)
            """

    case .after where property.isThrowing, .both where property.isThrowing:
        let beforeLine =
            variant == .both
            ? "\(beforeCall)(action)\n                        "
            : ""
        let successBody: String
        if hasReturn {
            successBody = """
                let __outcome = \(outcomeExpr(witnessResult: "\(witnessResultType).success(result)"))
                                    \(afterCall)(__outcome)
                                    let __result = __outcome.__consumeResult()
                                    switch consume __result {
                                    case .\(property.methodName)(.success(let __value)): return __value
                                    default: fatalError("unreachable")
                                    }
                """
        } else {
            successBody = """
                let __outcome = \(outcomeExpr(witnessResult: "\(witnessResultType).success(())"))
                                    \(afterCall)(__outcome)
                """
        }
        return """
                            let action: Calls = \(actionConstruction)
                            \(beforeLine)\(property.observeDoClause){
                                \(hasReturn ? "let result = " : "")try \(property.awaitPrefix)\(callExpression)
                                \(successBody)
                            } catch {
                                let __outcome = \(outcomeExpr(witnessResult: "\(witnessResultType).failure(error)"))
                                \(afterCall)(__outcome)
                                throw error
                            }
            """

    case .after, .both:
        let beforeLine =
            variant == .both
            ? "\(beforeCall)(action)\n                        "
            : ""
        let resultBody: String
        if hasReturn {
            resultBody = """
                let __outcome = \(outcomeExpr(witnessResult: "\(witnessResultType).success(result)"))
                            \(afterCall)(__outcome)
                            let __result = __outcome.__consumeResult()
                            switch consume __result {
                            case .\(property.methodName)(.success(let __value)): return __value
                            default: fatalError("unreachable")
                            }
                """
        } else {
            resultBody = """
                let __outcome = \(outcomeExpr(witnessResult: "\(witnessResultType).success(())"))
                            \(afterCall)(__outcome)
                """
        }
        return """
                            let action: Calls = \(actionConstruction)
                            \(beforeLine)\(hasReturn ? "let result = " : "")\(property.awaitPrefix)\(callExpression)
                            \(resultBody)
            """
    }
}

private func formatCallsConstruction(for property: ClosureProperty) -> String {
    let copyableParams = property.parameters.filter { !$0.hasOwnershipAnnotation }
    if copyableParams.isEmpty {
        return ".\(property.methodName)"
    }
    let args = copyableParams.map { param in
        let name = param.internalName
        if let label = param.label {
            return "\(label): \(name)"
        } else {
            return name
        }
    }.joined(separator: ", ")
    return ".\(property.methodName)(\(args))"
}

enum WitnessDiagnostic: String, DiagnosticMessage {
    case requiresStructOrEnum
    case noClosureProperties
    case noEnumCases
}

extension WitnessDiagnostic {
    var message: String {
        switch self {
        case .requiresStructOrEnum:
            return "@Witness can only be applied to structs or enums"

        case .noClosureProperties:
            return "@Witness requires at least one closure property"

        case .noEnumCases:
            return "@Witness requires at least one enum case"
        }
    }

    var diagnosticID: MessageID {
        MessageID(domain: "WitnessMacro", id: rawValue)
    }

    var severity: DiagnosticSeverity { .error }
}
