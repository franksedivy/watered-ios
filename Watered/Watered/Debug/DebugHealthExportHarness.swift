#if DEBUG
import Foundation
import Observation

/// In-memory, one-shot interventions for controlled device verification. No logging,
/// permission requests, payload changes or persisted test flags. Relaunch clears the hooks.
@MainActor @Observable
final class DebugHealthExportHarness {
    enum Intervention: String, CaseIterable, Identifiable {
        case none = "Normal export"
        case failNextWrite = "Fail next upload before writing"
        case pauseAfterSave = "Pause next successful write before acknowledgement"
        case failNextDeletion = "Fail next cleanup before deleting"
        case pauseAfterDeletion = "Pause next successful cleanup before acknowledgement"
        var id: Self { self }
    }

    var nextIntervention: Intervention = .none
    private(set) var pausedType: HealthWriteType?
    private(set) var lastIntervention = "None this launch"
    @ObservationIgnored private var continuation: CheckedContinuation<Void, Never>?
    var isPaused: Bool { pausedType != nil }

    /// A simulated temporary failure uses the normal durable retry path, without Health I/O.
    func beforeWrite() throws {
        guard nextIntervention == .failNextWrite else { return }
        nextIntervention = .none
        lastIntervention = "Simulated temporary failure before HealthKit write"
        throw HealthExportFailure.temporary
    }

    /// Called only after a successful real/fake client response, while durable state is inFlight.
    /// Stop the process here to exercise recovery, or resume to persist the ordinary outcome.
    func afterSuccessfulWrite(type: HealthWriteType) async {
        guard nextIntervention == .pauseAfterSave else { return }
        nextIntervention = .none
        pausedType = type
        lastIntervention = "HealthKit reported success; acknowledgement paused"
        await withCheckedContinuation { continuation = $0 }
        pausedType = nil
        lastIntervention = "Acknowledgement resumed"
    }

    func beforeDeletion() throws {
        guard nextIntervention == .failNextDeletion else { return }
        nextIntervention = .none
        lastIntervention = "Simulated temporary failure before HealthKit deletion"
        throw HealthExportFailure.temporary
    }

    func afterSuccessfulDeletion(type: HealthWriteType) async {
        guard nextIntervention == .pauseAfterDeletion else { return }
        nextIntervention = .none
        pausedType = type
        lastIntervention = "HealthKit reported cleanup success; acknowledgement paused"
        await withCheckedContinuation { continuation = $0 }
        pausedType = nil
        lastIntervention = "Acknowledgement resumed"
    }

    func resumeAcknowledgement() {
        let pending = continuation
        continuation = nil
        pending?.resume()
    }
}
#endif
