import AppKit

@MainActor
enum AppAppearanceManager {
    static func apply(_ appearance: AppAppearance) {
        apply(appearance, application: NSApp)
    }

    static func apply(_ appearance: AppAppearance, application: AppearanceManagingApplication?) {
        guard let application else {
            return
        }

        // Keep menu bar status icon in the system appearance by not overriding NSApp.appearance.
        application.appearance = nil

        let windowAppearance = resolvedWindowAppearance(for: appearance)

        // Apply to all opened app windows (dashboard, settings, and menu bar extra window).
        for window in application.appearanceManagedWindows {
            window.appearance = windowAppearance
            window.refreshForAppearanceChange()
        }
    }

    static func resolvedWindowAppearance(for appearance: AppAppearance) -> NSAppearance? {
        appearance.nsAppearanceName.flatMap { NSAppearance(named: $0) }
    }
}

@MainActor
protocol AppearanceManagingWindow: AnyObject {
    var appearance: NSAppearance? { get set }
    func refreshForAppearanceChange()
}

extension NSWindow: AppearanceManagingWindow {
    func refreshForAppearanceChange() {
        contentView?.needsDisplay = true
        contentView?.displayIfNeeded()
    }
}

@MainActor
protocol AppearanceManagingApplication: AnyObject {
    var appearance: NSAppearance? { get set }
    var appearanceManagedWindows: [AppearanceManagingWindow] { get }
}

extension NSApplication: AppearanceManagingApplication {
    var appearanceManagedWindows: [AppearanceManagingWindow] {
        windows
    }
}
