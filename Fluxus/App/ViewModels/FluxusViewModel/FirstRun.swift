import Foundation

extension FluxusViewModel {
    func completeFirstRunAcknowledgement() {
        guard acknowledgmentChecked else {
            setStatus("Please check 'I understand' before continuing.", isError: true)
            return
        }

        hasAcknowledgedWarning = true
        UserDefaults.standard.set(true, forKey: FluxusViewModelConstants.firstRunDefaultsKey)
        setStatus("First-run acknowledgement recorded.", isError: false)
    }

    static func firstRunAcknowledgementOverride() -> Bool? {
        guard let raw = ProcessInfo.processInfo.environment["FLUXUS_TEST_FIRST_RUN_ACKNOWLEDGED"]?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased() else {
            return nil
        }

        switch raw {
        case "1", "true", "yes":
            return true
        case "0", "false", "no":
            return false
        default:
            return nil
        }
    }
}
