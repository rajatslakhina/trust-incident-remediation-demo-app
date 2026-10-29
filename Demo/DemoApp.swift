import SwiftUI
import TrustRemediation
import TrustRemediationUI

/// The app's compiled-in remediation policy.
///
/// This is the part a real app owns and the library cannot: which network
/// capabilities exist, which trust store each one actually uses, and what this binary's
/// version is. The manifest can only restrict what is declared here.
enum AppPolicy {
    static func makeScenario() -> LabScenario? {
        guard let vulnerable = BuildVersion("4.1.0"),
              let fixed = BuildVersion("4.2.0"),
              let older = BuildVersion("4.0.2"),
              let legacy = BuildVersion("3.9.0"),
              let internalBuild = BuildVersion("4.3.0"),
              let affected = VersionRange(introduced: nil, fixed: fixed),
              let catalog = CapabilityCatalog([
                  CapabilityDescriptor(id: "partnerSync", displayName: "Partner sync (Firestore-style SDK)",
                                       trustPath: .embeddedTrustStore),
                  CapabilityDescriptor(id: "crashReports", displayName: "Crash reporting SDK",
                                       trustPath: .embeddedTrustStore, blockedWhenUpgradeRequired: false),
                  CapabilityDescriptor(id: "photoBackup", displayName: "Photo backup (URLSession)",
                                       trustPath: .systemTrust),
                  CapabilityDescriptor(id: "aiAssistant", displayName: "AI assistant (own gateway → Claude)",
                                       trustPath: .systemTrust),
              ])
        else { return nil }

        return LabScenario(
            catalog: catalog,
            vulnerableBuild: vulnerable,
            fixedBuild: fixed,
            incidentRules: [
                CapabilityRule(id: "CA-2026-10-1", capability: "partnerSync", action: .disable,
                               affectedBuilds: [affected],
                               reason: "SDK's embedded root bundle trusts the compromised CA"),
                CapabilityRule(id: "CA-2026-10-2", capability: "crashReports", action: .degrade,
                               affectedBuilds: [affected],
                               reason: "Buffer reports on device until the fixed SDK ships"),
            ],
            hardEnforcementAfterDays: 3,
            initialFleet: [
                InstallCohort(build: vulnerable, activeInstalls: 6_000),
                InstallCohort(build: older, activeInstalls: 1_500),
                InstallCohort(build: legacy, activeInstalls: 30),
                InstallCohort(build: internalBuild, activeInstalls: 9),
            ],
            minimumCohortSize: 50)
    }
}

@main
struct TrustIncidentDemoApp: App {
    /// Created once for the app's lifetime; the view only observes it.
    @State private var model: RemediationConsoleModel? = AppPolicy.makeScenario().map { scenario in
        RemediationConsoleModel(scenario: scenario)
    }

    var body: some Scene {
        WindowGroup {
            if let model {
                RemediationConsoleView(model: model)
            } else {
                Text("The compiled-in policy is invalid.")
            }
        }
    }
}
