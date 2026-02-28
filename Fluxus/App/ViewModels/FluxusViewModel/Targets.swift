import Foundation

extension FluxusViewModel {
    func addRootTarget() {
        config.roots.append(
            RootRuleConfig(
                name: "",
                path: "",
                retentionDays: 30,
                action: .trash,
                exclusions: .default
            )
        )
    }

    func removeRootTarget(at index: Int) {
        guard config.roots.indices.contains(index) else {
            return
        }
        config.roots.remove(at: index)
    }
}
