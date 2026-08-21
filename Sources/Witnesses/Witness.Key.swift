public import Dependency_Primitives
import Witness_Primitives

public protocol __WitnessKeyTest<Value>: Sendable {

    associatedtype Value: ~Copyable & Sendable = Self

    static var testValue: Value { get }

    static var previewValue: Value { get }
}

extension __WitnessKeyTest where Value: Copyable {

    @inlinable
    public static var previewValue: Value { testValue }
}

extension Witness {

    public protocol Key<Value>: Dependency.Key, __WitnessKeyTest {

        static var liveValue: Value { get }
    }
}

extension Witness.Key where Value: Copyable {

    @inlinable
    public static var previewValue: Value { liveValue }

    @inlinable
    public static var testValue: Value { previewValue }
}

extension Witness.Key {

    public typealias Test = __WitnessKeyTest
}
