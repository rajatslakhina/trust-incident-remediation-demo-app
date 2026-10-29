# Trust Incident Demo

**A CA gets compromised on Monday. Your OS update covers `URLSession`, but not the SDK that ships its own root list.** This app walks one trust incident from start to finish against the real [`TrustRemediation`](https://github.com/rajatslakhina/trust-incident-remediation-kit) library. You declare the incident, attack the channel the fix travels on, let the manifest go stale, reboot the phone with its clock wound back, and ship the fixed build. At each step you can watch which network paths the app still allows.

It is deliberately a separate repository. The app consumes the library the way a product team would: as a **remote Swift package pinned to `1.x`** (`XCRemoteSwiftPackageReference`, `upToNextMajorVersion` from `1.0.0`), not as a local path or a branch.

## Why this matters

When a trust incident hits, the people who have to act are leads, not individual feature owners. They need to know which network paths the OS block doesn't reach, how to switch those paths off in binaries already on phones, how to stop an attacker from replaying yesterday's "all clear", when to move from "please update" to "update required", and how much of the fleet is still exposed. This demo makes each of those decisions visible and lets you try to break it.

## What you can do in it

The first nine buttons on screen are the rows of this table, in this order. Run them top to bottom, starting with **Declare incident**: before the incident there is nothing older to replay, and no deadline for the clock to pass. The last three buttons (**Refresh manifest**, **+1 day**, **Toggle network**) are free play. If you take the network down, bring it back before **Install fixed build** and **Publish all-clear**, because both need a fetch.

| Button | What happens | What to look for |
|---|---|---|
| **Declare incident** | The in-process server signs a manifest that disables partner sync and degrades crash reporting on builds below 4.2.0, and schedules hard enforcement 3 days out | Capability badges flip to OFF / DEGRADED; the upgrade banner shows the deadline; fleet exposure jumps |
| **Replay old manifest** | The network replays the first, unrestricted, validly signed manifest | Rejected as rollback; badges don't change |
| **Tamper in transit** | One byte of the payload is flipped | Rejected: `badSignature` |
| **Equivocating signer** | A second, different (unrestricted) manifest is signed at the same version | It doesn't replace the first copy. Both copies' restrictions are enforced, so badges stay OFF, and an equivocation warning appears |
| **+8 days offline** | Time passes with no fetch | The manifest goes stale but keeps its restrictions; the deadline passes and enforcement becomes *required* |
| **Phone clock −10 days** | The user winds the wall clock back | Nothing changes, because trusted time is signed time plus uptime |
| **Reboot device** | Uptime resets, so there is no signed anchor this boot | Time basis shows "Wall clock (floored)"; still *required* |
| **Install fixed build** | The app becomes 4.2.0 and relaunches | The rules no longer match; the upgrade requirement clears |
| **Publish all-clear** | A newer manifest lifts every rule | Everything returns to FULL |

The compiled-in policy lives in [`Demo/DemoApp.swift`](Demo/DemoApp.swift) (`AppPolicy`). It declares four capabilities, each with the trust store it actually uses, and that file is the only thing a real app would need to write.

## Design decisions

- **The app owns only its policy.** `AppPolicy` declares which network capabilities exist and which trust store each actually uses. Everything else (verification, rollback floor, trusted time, gating, enforcement) is the library's job. The manifest can only restrict what this file declares, so this file is also the complete list of things an incident can switch off.
- **Crash reporting degrades instead of switching off, and survives hard enforcement** (`blockedWhenUpgradeRequired: false`). During an incident, crash data from the vulnerable fleet is what tells you whether the fix works. So reports are buffered on device rather than dropped, and they are sent once the fixed SDK ships. Partner sync, which moves user data over the exposed path, is switched off completely.
- **An in-process, deterministic lab instead of a real server.** The "server" signs real Ed25519 manifests, and the hostile network replays, tampers with and forks them, all inside the app. The clock, uptime and fleet are simulated. This makes every step repeatable and lets the library's `LabTests` drive the same script on Linux. *What it leaves untested:* real TLS, real push delivery, and real `URLSession` behaviour under a distrusted root. *Rejected:* a hosted demo backend. It would add infrastructure to keep alive, and it couldn't simulate the attacks honestly.
- **k = 50 on the exposure dashboard.** A 30-install legacy cohort and a 9-install internal build are folded into one "other" bucket with exposure withheld. That shows the k-anonymity rule doing something without hiding the headline number.
- **A version requirement, not a lockfile.** The project pins `upToNextMajorVersion` from `1.0.0`. No `Package.resolved` is committed yet, because it can only be generated by opening the project in Xcode, which the creating session couldn't do. This is listed under Verification.

## Screenshots

**None exist.** This app has not been run on a Simulator or a device. See Verification below for why; this section will only ever hold real captures.

## How to run it

1. `git clone https://github.com/rajatslakhina/trust-incident-remediation-demo-app.git`
2. Open `Demo.xcodeproj` in Xcode 16 or later. Xcode resolves `trust-incident-remediation-kit` (1.x) and `swift-crypto` from GitHub.
3. Select the **Demo** scheme and any iOS 17+ Simulator.
4. Build and Run, then tap **Declare incident**.

## Verification

- **Simulator run: not done.** This app has never been launched on a Simulator or a device. It was created by a scheduled, unattended session in a Linux sandbox with no macOS toolchain, so no screenshots exist.
- **Never compiled.** `Demo/DemoApp.swift`, `project.pbxproj` and the library's SwiftUI console have not been compiled by any toolchain. The `build-demo` CI job is what will resolve the remote package from GitHub and build this app for `generic/platform=iOS Simulator`. Until a run appears in the Actions tab, no CI result is claimed. Even a green build only shows that the app builds for a Simulator, not that it runs on one.
- **What was checked instead.** The pbxproj was parsed with the `pbxproj` Python parser (22 objects, 0 dangling references, balanced braces and parens). A scratch copy of `AppPolicy` (with the SwiftUI `App` struct removed) was compiled against the library on Linux, then run through the start and **Declare incident** steps. After **Declare incident**, partner sync was OFF, crash reports DEGRADED, and photo backup and the AI assistant FULL. That scratch test is not committed. The full button script runs in the library's `LabTests`, against a similar but not identical scenario.
- **No committed `Package.resolved`.** Resolution is pinned by the `upToNextMajorVersion` requirement (1.x). Xcode writes the exact revisions on first open.

## License

MIT
