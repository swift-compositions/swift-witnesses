import Testing

@testable import Witnesses

extension Witness.Derive {
    @Suite
    struct Test {
        @Suite struct Unit {}
        @Suite struct EdgeCase {}
        @Suite struct Integration {}
        @Suite(.serialized) struct Performance {}
    }
}

extension Witness.Derive.Test.Unit {
    @Test
    func `Mock generates static method with value parameters`() async throws {

        let api = MockableAPI.mock(
            fetchUser: "Test User",
            getCount: 42

        )

        let user = try await api.fetchUser(id: 999)
        #expect(user == "Test User")

        let count = try api.getCount()
        #expect(count == 42)

        try await api.deleteUser(id: 1)
    }

    @Test
    func `Mock with all explicit values`() async throws {
        let api = MockableAPI.mock(
            fetchUser: "Explicit User",
            getCount: 100,
            deleteUser: ()
        )

        let user = try await api.fetchUser(id: 1)
        #expect(user == "Explicit User")

        let count = try api.getCount()
        #expect(count == 100)
    }

    @Test
    func `Mock returns same value for any input`() async throws {
        let api = MockableAPI.mock(
            fetchUser: "Always This",
            getCount: 0
        )

        let user1 = try await api.fetchUser(id: 1)
        let user2 = try await api.fetchUser(id: 999)
        let user3 = try await api.fetchUser(id: -1)

        #expect(user1 == "Always This")
        #expect(user2 == "Always This")
        #expect(user3 == "Always This")
    }

    @Test
    func `Mock also has unimplemented available`() async throws {

        let mockApi = MockableAPI.mock(fetchUser: "Test", getCount: 0)
        let unimplApi = MockableAPI.unimplemented()

        let result = try await mockApi.fetchUser(id: 1)
        #expect(result == "Test")

        await #expect(throws: Witness.Unimplemented.Error.self) {
            _ = try await unimplApi.fetchUser(id: 1)
        }
    }
}

extension Witness.Derive.Test.Unit {
    @Test
    func `Generator callAsFunction returns closure result`() throws {
        let gen = IntGenerator(generate: { 42 })
        let result = try gen()
        #expect(result == 42)
    }

    @Test
    func `Generator constant returns same value`() throws {
        let gen = IntGenerator.constant(99)
        #expect(try gen() == 99)
        #expect(try gen() == 99)
    }

    @Test
    func `Generator unimplemented throws`() {
        let gen = IntGenerator.unimplemented()
        #expect(throws: Witness.Unimplemented.Error.self) {
            _ = try gen()
        }
    }
}

extension Witness.Derive.Test.EdgeCase {
    @Test
    func `Mock with empty string value`() async throws {
        let api = MockableAPI.mock(
            fetchUser: "",
            getCount: 0
        )

        let user = try await api.fetchUser(id: 1)
        #expect(user.isEmpty)
    }

    @Test
    func `Mock with negative count`() async throws {
        let api = MockableAPI.mock(
            fetchUser: "User",
            getCount: -1
        )

        let count = try api.getCount()
        #expect(count == -1)
    }

    @Test
    func `Mock with zero count`() async throws {
        let api = MockableAPI.mock(
            fetchUser: "User",
            getCount: 0
        )

        let count = try api.getCount()
        #expect(count == 0)
    }

    @Test
    func `Mock with large count`() async throws {
        let api = MockableAPI.mock(
            fetchUser: "User",
            getCount: Int.max
        )

        let count = try api.getCount()
        #expect(count == Int.max)
    }
}

extension Witness.Derive.Test.Integration {
    @Test
    func `Mock in context scope`() async throws {
        let mockApi = MockableAPI.mock(
            fetchUser: "Context User",
            getCount: 42
        )

        try await Witness.Context.with { _ in

        } operation: {
            let user = try await mockApi.fetchUser(id: 1)
            #expect(user == "Context User")
        }
    }

    @Test
    func `Multiple mock instances are independent`() async throws {
        let mock1 = MockableAPI.mock(fetchUser: "User 1", getCount: 1)
        let mock2 = MockableAPI.mock(fetchUser: "User 2", getCount: 2)

        let user1 = try await mock1.fetchUser(id: 1)
        let user2 = try await mock2.fetchUser(id: 1)

        #expect(user1 == "User 1")
        #expect(user2 == "User 2")
    }
}

extension Witness.Derive.Test.Performance {
    @Test
    func `Mock creation`() {

        for _ in 0..<100 {
            _ = MockableAPI.mock(fetchUser: "User", getCount: 42)
        }

        for _ in 0..<1000 {
            _ = MockableAPI.mock(fetchUser: "User", getCount: 42)
        }
    }

    @Test
    func `Mock invocation`() async throws {
        let api = MockableAPI.mock(fetchUser: "User", getCount: 42)

        for _ in 0..<100 {
            _ = try await api.fetchUser(id: 1)
        }

        for _ in 0..<1000 {
            _ = try await api.fetchUser(id: 1)
        }
    }
}
