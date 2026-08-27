public import Dependency
import Witness

public protocol __WitnessKeyTest<Value>: Sendable {

    associatedtype Value: ~Copyable & ~Escapable & Sendable = Self

    static var testValue: Value { get }

    static var previewValue: Value { get }
}

extension __WitnessKeyTest where Value: Copyable & Escapable {

    @inlinable
    public static var previewValue: Value { testValue }
}

extension Witness {

    public protocol Key<Value>: Dependency.Key, __WitnessKeyTest
    where Value: ~Copyable & ~Escapable {

        static var liveValue: Value { get }
    }
}

extension Witness.Key where Value: Copyable & Escapable {

    @inlinable
    public static var previewValue: Value { liveValue }

    @inlinable
    public static var testValue: Value { previewValue }
}

extension Witness.Key where Value: ~Copyable & ~Escapable {

    public typealias Test = __WitnessKeyTest
}
