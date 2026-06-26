import Foundation
import PidlyCore

// LaunchAgent helper entry point (PID-EPIC-27). Runs exactly one scan per
// invocation and exits — launchd re-launches it on the StartInterval cadence
// authored in PID-27.4. Reads scan config from the shared Application-Support
// JSON file (written by the app in PID-27.5/.6), falling back to defaults when
// absent. Posting notifications + the app↔helper dedupe handoff land in PID-27.5;
// for now the helper just enumerates and reports the candidate count.

let config = HelperConfig.load()
let items = ScanCore.enumerate(elapsedThreshold: config.elapsedThreshold,
                               ignoredNames: config.ignoredNames)
print("Pidly helper: \(items.count) stray candidate(s) found")
exit(0)
