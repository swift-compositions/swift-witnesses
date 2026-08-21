import Synchronization
import Testing

@testable import Witnesses

extension Witness.Test.Unit {
    @Test
    func `Untyped throws derives any Error failure type`() throws {
        let error: any Swift.Error = CustomError.failed

        let syncResult = ThrowsMatrixAPI.Result.bareSync(
            Standard_Library_Extensions.Result<Int, any Swift.Error>.failure(error)
        )
        switch consume syncResult {
        case .bareSync(.failure(let captured)):
            #expect((captured as? CustomError) == .failed)

        default:
            Issue.record("Expected .bareSync(.failure)")
        }

        let asyncResult = ThrowsMatrixAPI.Result.bareAsync(
            Standard_Library_Extensions.Result<String, any Swift.Error>.failure(error)
        )
        switch consume asyncResult {
        case .bareAsync(.failure(let captured)):
            #expect((captured as? CustomError) == .failed)

        default:
            Issue.record("Expected .bareAsync(.failure)")
        }
    }

    @Test
    func `Typed throws derives the concrete failure type`() throws {

        let syncResult = ThrowsMatrixAPI.Result.typedSync(
            Standard_Library_Extensions.Result<Int, CustomError>.failure(.failed)
        )
        switch consume syncResult {
        case .typedSync(.failure(let captured)):
            #expect(captured == .failed)

        default:
            Issue.record("Expected .typedSync(.failure)")
        }

        let asyncResult = ThrowsMatrixAPI.Result.typedAsync(
            Standard_Library_Extensions.Result<String, CustomError>.failure(.failed)
        )
        switch consume asyncResult {
        case .typedAsync(.failure(let captured)):
            #expect(captured == .failed)

        default:
            Issue.record("Expected .typedAsync(.failure)")
        }
    }

    @Test
    func `Non-throwing derives Never failure type`() throws {

        let result = ThrowsMatrixAPI.Result.nonThrowing(
            Standard_Library_Extensions.Result<Int, Never>.success(42)
        )
        switch consume result {
        case .nonThrowing(.success(let value)):
            #expect(value == 42)

        default:
            Issue.record("Expected .nonThrowing(.success)")
        }
    }
}

extension Witness.Test.Integration {
    @Test
    func `Observe after runs on untyped async throws failure path`() async throws {
        let base = ThrowsMatrixAPI(
            bareSync: { 1 },
            bareAsync: { _ in throw CustomError.failed },
            typedSync: { 2 },
            typedAsync: { _ in "unused" },
            nonThrowing: { 3 }
        )

        let observedCalls = Synchronization.Mutex<[String]>([])
        let observed = base.observe.after { outcome in
            observedCalls.withLock { $0.append("\(outcome.action.case)") }
        }

        await #expect(throws: CustomError.self) {
            _ = try await observed.bareAsync(id: 7)
        }
        #expect(observedCalls.withLock { $0 } == ["bareAsync"])
    }
}
