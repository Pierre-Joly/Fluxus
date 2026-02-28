import Foundation

enum DashboardSection: String, CaseIterable, Identifiable {
    case overview
    case rules
    case simulation
    case history

    var id: String { rawValue }

    var title: String {
        switch self {
        case .overview:
            return "Overview"
        case .rules:
            return "Targets"
        case .simulation:
            return "Simulation"
        case .history:
            return "History"
        }
    }

    var systemImage: String {
        switch self {
        case .overview:
            return "rectangle.grid.2x2"
        case .rules:
            return "folder.badge.gearshape"
        case .simulation:
            return "list.bullet.rectangle"
        case .history:
            return "clock.arrow.circlepath"
        }
    }
}
