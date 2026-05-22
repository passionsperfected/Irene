import Foundation

@MainActor @Observable
final class SprintsViewModel {
    private(set) var sprints: [Sprint] = []
    private(set) var isLoading = false
    var errorMessage: String?

    private let vaultManager: VaultManager
    private let storage = JSONStorage<Sprint>()

    init(vaultManager: VaultManager) {
        self.vaultManager = vaultManager
    }

    /// Sprints sorted with explicit sortOrder ascending; ties broken by created date desc.
    var orderedSprints: [Sprint] {
        sprints.sorted {
            if $0.sortOrder != $1.sortOrder { return $0.sortOrder < $1.sortOrder }
            return $0.created > $1.created
        }
    }

    // MARK: - Load / Save

    func loadSprints() async {
        guard let dir = try? vaultManager.directoryURL(for: .sprint) else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            sprints = try await storage.loadAll(in: dir)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func save(_ sprint: Sprint) async {
        do {
            let dir = try vaultManager.directoryURL(for: .sprint)
            let url = dir.appendingPathComponent(sprint.fileName)
            try await storage.save(sprint, to: url)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Sprint CRUD

    @discardableResult
    func createSprint(name: String) async -> Sprint? {
        let sprint = Sprint(name: name, sortOrder: sprints.count)
        await save(sprint)
        sprints.append(sprint)
        return sprint
    }

    func updateSprint(_ sprint: Sprint) async {
        guard let idx = sprints.firstIndex(where: { $0.id == sprint.id }) else { return }
        var updated = sprint
        updated.touch()
        sprints[idx] = updated
        await save(updated)
    }

    func deleteSprint(_ sprint: Sprint) async {
        do {
            let dir = try vaultManager.directoryURL(for: .sprint)
            let url = dir.appendingPathComponent(sprint.fileName)
            try await storage.delete(at: url)
            sprints.removeAll { $0.id == sprint.id }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Goal CRUD (operate within a sprint)

    func addGoal(_ goal: SprintGoal, to sprintID: UUID) async {
        guard let idx = sprints.firstIndex(where: { $0.id == sprintID }) else { return }
        var sprint = sprints[idx]
        sprint.goals.append(goal)
        sprint.touch()
        sprints[idx] = sprint
        await save(sprint)
    }

    func updateGoal(_ goal: SprintGoal, in sprintID: UUID) async {
        guard let sIdx = sprints.firstIndex(where: { $0.id == sprintID }) else { return }
        var sprint = sprints[sIdx]
        guard let gIdx = sprint.goals.firstIndex(where: { $0.id == goal.id }) else { return }
        var updated = goal
        updated.touch()
        sprint.goals[gIdx] = updated
        sprint.touch()
        sprints[sIdx] = sprint
        await save(sprint)
    }

    func deleteGoal(_ goalID: UUID, from sprintID: UUID) async {
        guard let idx = sprints.firstIndex(where: { $0.id == sprintID }) else { return }
        var sprint = sprints[idx]
        sprint.goals.removeAll { $0.id == goalID }
        sprint.touch()
        sprints[idx] = sprint
        await save(sprint)
    }

    func cycleGoalStatus(_ goal: SprintGoal, in sprintID: UUID) async {
        let next: SprintGoalStatus
        switch goal.status {
        case .planned: next = .inProgress
        case .inProgress: next = .done
        case .done: next = .dropped
        case .dropped: next = .planned
        }
        var updated = goal
        updated.status = next
        await updateGoal(updated, in: sprintID)
    }
}
