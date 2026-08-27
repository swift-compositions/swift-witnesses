import Witness

extension Witness {

    public enum Preparation {}
}

extension Witness.Preparation {

    @TaskLocal
    internal static var store: Store?

    public static var current: Store? {
        store
    }
}

extension Witness.Preparation {

    nonisolated(nonsending)
        public static func with<T, E: Swift.Error>(
            _ configure: (Store) -> Void,
            operation: nonisolated(nonsending) () async throws(E) -> T
        ) async throws(E) -> T
    {
        let newStore = Store()
        configure(newStore)
        return try await $store.withValue(newStore) {
            do throws(E) {
                return Result<T, E>.success(try await operation())
            } catch {
                return Result<T, E>.failure(error)
            }
        }.get()
    }

    public static func with<T, E: Swift.Error>(
        _ configure: (Store) -> Void,
        operation: () throws(E) -> T
    ) throws(E) -> T {
        let newStore = Store()
        configure(newStore)
        return try $store.withValue(newStore) {
            do throws(E) {
                return Result<T, E>.success(try operation())
            } catch {
                return Result<T, E>.failure(error)
            }
        }.get()
    }
}
