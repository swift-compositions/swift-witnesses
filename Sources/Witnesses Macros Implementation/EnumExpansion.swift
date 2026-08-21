import SwiftDiagnostics
@_spi(RawSyntax) import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

struct EnumCase: Sendable {
    let name: String
    let parameters: [EnumCaseParameter]
}

struct EnumCaseParameter: Sendable {
    let label: String?
    let type: String
}

func extractEnumCases(from enumDecl: EnumDeclSyntax) -> [EnumCase] {
    var cases: [EnumCase] = []

    for member in enumDecl.memberBlock.members {
        guard let caseDecl = member.decl.as(EnumCaseDeclSyntax.self) else {
            continue
        }

        for element in caseDecl.elements {
            let name = element.name.text
            var parameters: [EnumCaseParameter] = []

            if let parameterClause = element.parameterClause {
                for param in parameterClause.parameters {
                    let label = param.firstName?.text
                    parameters.append(
                        EnumCaseParameter(
                            label: label,
                            type: param.type.trimmedDescription
                        )
                    )
                }
            }

            cases.append(EnumCase(name: name, parameters: parameters))
        }
    }

    return cases
}

func generateEnumPrismMembers(for cases: [EnumCase], enumName: String) -> [DeclSyntax] {
    var members: [DeclSyntax] = []

    for enumCase in cases {
        members.append(generateEnumComputedProperty(for: enumCase))
    }

    let caseCount = cases.count
    let escapedCaseNames = cases.map { escapeIdentifier($0.name) }
    let caseCases = escapedCaseNames.map { "case \($0)" }.joined(separator: "\n            ")
    let caseOrdinalCases = cases.enumerated().map { index, c in
        "case .\(escapeIdentifier(c.name)): Ordinal_Primitives.Ordinal(\(index))"
    }.joined(separator: "\n                ")
    let uncheckedInitCases = cases.enumerated().map { index, c in
        if index == cases.count - 1 {
            "default: self = .\(escapeIdentifier(c.name))"
        } else {
            "case \(index): self = .\(escapeIdentifier(c.name))"
        }
    }.joined(separator: "\n                ")
    let selfCaseCases = cases.map { c in
        let escaped = escapeIdentifier(c.name)
        return "case .\(escaped): .\(escaped)"
    }.joined(separator: "\n            ")

    let caseEnum: DeclSyntax = """
        public enum Case: Finite_Primitives.Finite.Enumerable, Sendable {
            \(raw: caseCases)

            @inlinable
            public static var count: Cardinal_Primitives.Cardinal { Cardinal_Primitives.Cardinal(\(raw: caseCount)) }

            @inlinable
            public var ordinal: Ordinal_Primitives.Ordinal {
                switch self {
                \(raw: caseOrdinalCases)
                }
            }

            @inlinable
            public init(_unchecked: Void, ordinal: Ordinal_Primitives.Ordinal) {
                switch ordinal.rawValue {
                \(raw: uncheckedInitCases)
                }
            }
        }
        """
    members.append(caseEnum)

    let caseProperty: DeclSyntax = """
        @inlinable
        public var `case`: Case {
            switch self {
            \(raw: selfCaseCases)
            }
        }
        """
    members.append(caseProperty)

    let prismProperties = cases.map { enumCase in
        generateEnumPrismProperty(for: enumCase, enumName: enumName)
    }.joined(separator: "\n\n        ")

    let prismsStruct: DeclSyntax = """
        public struct Prisms: Sendable {
            @inlinable
            public init() {}

            \(raw: prismProperties)
        }
        """
    members.append(prismsStruct)

    let prismsProperty: DeclSyntax = """
        @inlinable
        public static var prisms: Prisms { Prisms() }
        """
    members.append(prismsProperty)

    let isMethod: DeclSyntax = """
        @inlinable
        public func `is`<Value>(_ keyPath: KeyPath<Prisms, Optic_Primitives.Optic.Prism<\(raw: enumName), Value>>) -> Bool {
            Self.prisms[keyPath: keyPath].extract(self) != nil
        }
        """
    members.append(isMethod)

    let prismSubscript: DeclSyntax = """
        @inlinable
        public subscript<Value>(prism keyPath: KeyPath<Prisms, Optic_Primitives.Optic.Prism<\(raw: enumName), Value>>) -> Value? {
            Self.prisms[keyPath: keyPath].extract(self)
        }
        """
    members.append(prismSubscript)

    let modifyMethod: DeclSyntax = """
        @inlinable
        public mutating func modify<Value>(_ keyPath: KeyPath<Prisms, Optic_Primitives.Optic.Prism<\(raw: enumName), Value>>, _ transform: (inout Value) -> Void) {
            let prism = Self.prisms[keyPath: keyPath]
            guard var value = prism.extract(self) else { return }
            transform(&value)
            self = prism.embed(value)
        }
        """
    members.append(modifyMethod)

    return members
}

private func generateEnumComputedProperty(for enumCase: EnumCase) -> DeclSyntax {
    if enumCase.parameters.isEmpty {
        return """
            @inlinable
            public var \(raw: enumCase.name): Void? {
                if case .\(raw: enumCase.name) = self { () } else { nil }
            }
            """
    } else if enumCase.parameters.count == 1 {
        let param = enumCase.parameters[0]
        let paramType = param.type
        let extractPattern = param.label.map { "\($0): let v" } ?? "let v"

        return """
            @inlinable
            public var \(raw: enumCase.name): \(raw: paramType)? {
                if case .\(raw: enumCase.name)(\(raw: extractPattern)) = self { v } else { nil }
            }
            """
    } else {
        let tupleTypes = enumCase.parameters.map { param in
            if let label = param.label {
                let escaped = escapeIdentifier(label)
                return "\(escaped): \(param.type)"
            } else {
                return param.type
            }
        }.joined(separator: ", ")

        let extractPatterns = enumCase.parameters.enumerated().map { index, param in
            if let label = param.label {
                return "\(label): let v\(index)"
            } else {
                return "let v\(index)"
            }
        }.joined(separator: ", ")

        let extractTuple = enumCase.parameters.enumerated().map { index, param in
            if let label = param.label {
                let escaped = escapeIdentifier(label)
                return "\(escaped): v\(index)"
            } else {
                return "v\(index)"
            }
        }.joined(separator: ", ")

        return """
            @inlinable
            public var \(raw: enumCase.name): (\(raw: tupleTypes))? {
                if case .\(raw: enumCase.name)(\(raw: extractPatterns)) = self { (\(raw: extractTuple)) } else { nil }
            }
            """
    }
}

private func generateEnumPrismProperty(for enumCase: EnumCase, enumName: String) -> String {
    let prismCase = PrismCase(
        caseName: escapeIdentifier(enumCase.name),
        rootTypeName: enumName,
        parameters: enumCase.parameters.map {
            (
                $0.label.map { escapeIdentifier($0) },
                $0.type
            )
        }
    )
    return generatePrism(for: prismCase)
}

struct PrismCase {
    let caseName: String
    let rootTypeName: String
    let parameters: [(label: String?, type: String)]
}

func generatePrism(for prismCase: PrismCase) -> String {
    let name = prismCase.caseName
    let root = prismCase.rootTypeName

    if prismCase.parameters.isEmpty {
        return """
            public var \(name): Optic_Primitives.Optic.Prism<\(root), Void> {
                        Optic_Primitives.Optic.Prism(
                            embed: { _ in .\(name) },
                            extract: { if case .\(name) = $0 { return () } else { return nil } }
                        )
                    }
            """
    } else if prismCase.parameters.count == 1 {
        let param = prismCase.parameters[0]
        let paramType = param.type
        let embedArg = param.label != nil ? "\(param.label!): $0" : "$0"
        let extractPattern = param.label != nil ? "\(param.label!): let v" : "let v"

        return """
            public var \(name): Optic_Primitives.Optic.Prism<\(root), \(paramType)> {
                        Optic_Primitives.Optic.Prism(
                            embed: { .\(name)(\(embedArg)) },
                            extract: { if case .\(name)(\(extractPattern)) = $0 { return v } else { return nil } }
                        )
                    }
            """
    } else {
        let tupleTypes = prismCase.parameters.map { p in
            p.label != nil ? "\(p.label!): \(p.type)" : p.type
        }.joined(separator: ", ")

        let embedArgs = prismCase.parameters.enumerated().map { i, p in
            p.label != nil ? "\(p.label!): $0.\(i)" : "$0.\(i)"
        }.joined(separator: ", ")

        let extractPatterns = prismCase.parameters.enumerated().map { i, p in
            p.label != nil ? "\(p.label!): let v\(i)" : "let v\(i)"
        }.joined(separator: ", ")

        let extractTuple = prismCase.parameters.enumerated().map { i, p in
            p.label != nil ? "\(p.label!): v\(i)" : "v\(i)"
        }.joined(separator: ", ")

        return """
            public var \(name): Optic_Primitives.Optic.Prism<\(root), (\(tupleTypes))> {
                        Optic_Primitives.Optic.Prism(
                            embed: { .\(name)(\(embedArgs)) },
                            extract: { if case .\(name)(\(extractPatterns)) = $0 { return (\(extractTuple)) } else { return nil } }
                        )
                    }
            """
    }
}

func escapeIdentifier(_ identifier: String) -> String {
    let isKeyword = Array(identifier.utf8).withUnsafeBufferPointer { buffer in
        let text = SyntaxText(baseAddress: buffer.baseAddress, count: buffer.count)
        return Keyword(text) != nil
    }
    if isKeyword {
        return "`\(identifier)`"
    }
    return identifier
}
