# Iman native iPhone companion

Native SwiftUI face and microphone remote for the existing Mac assistant. No WebView, Safari, browser speech API or phone language model. Minimum iOS 17; actual iPhone compatibility must be verified after the cloud build.

## Build without local Xcode

This directory is a self-contained public source repository. Only its files go to GitHub: no Mac runtime, model, conversations, notes, certificates or pairing secrets.

1. Upload this directory to the **public** `ElhassanSoussi/Iman_Pet` GitHub repository, preserving `.github/workflows/ios-build.yml`.
2. The workflow uses the standard `macos-15` GitHub-hosted runner. Standard runners are free for public repositories; do not switch to paid larger runners.
3. Source pushes to `main` start the build automatically. You can also open Actions and manually run **Build Iman for AltStore**. It uses Apple's iPhone SDK on a cloud Mac, XcodeGen and `xcodebuild`; nothing installs Xcode on your laptop.
4. Download **Iman-for-AltStore**. This contains an unsigned IPA. It cannot be installed directly until AltStore signs it.
5. Install official AltServer on the Mac and AltStore Classic on the iPhone. Use your Apple Account only in AltServer/Apple's own login prompt, never in source, cloud secrets or chat. Enable Developer Mode and trust your own developer identity if requested.
6. In AltStore, import the IPA. A free account requires refreshing the app within seven days; keep AltServer reachable over Wi-Fi/USB. The user installed and paired the first build; each voice update still needs an on-device check.

No Apple signing credentials belong in the cloud build. The workflow runs for source changes on `main` or a manual request, has a 20-minute timeout and stores artifacts for only three days. A successful cloud compile and a real device test are required before claiming the iPhone app works.

## Pair and use

Open Iman on Mac → Connect iPhone. Open the **native Iman app** → Connect → Scan Mac code. The QR contains the private IPv4 endpoint, one-use 10-minute code and exact server certificate SHA-256 fingerprint. The app verifies certificate pin, host and certificate trust using that certificate as a private anchor; redirects are refused. No system certificate profile is required.

Session cookies live only in the app's ephemeral session, expire after eight hours, and are invalidated by restarting the Mac gateway. Reopening the iPhone app requires pairing again in this first build. Renewal of the Mac server certificate also requires pairing again. No credentials are embedded in the binary.

Tap the face/microphone, speak, finish, review the words and send. Offline English speech is used only when supported by the device; typing is available otherwise. No background microphone. A sun button keeps the screen awake only while the app is active. Locking or leaving the app stops recording. It cannot appear over other iPhone apps or on the lock screen.

Try `Hi Iman`, `Give me a kiss`, then `Open Calculator`. Short replies appear on the face screen; longer answers appear on the Mac's right-side panel. The Mac must be awake and on the same Wi-Fi. Actions remain limited to the existing reviewed Mac command router.

## Architecture

- `Iman/App`: app entry, screen composition and state ownership.
- `Iman/Face`: animated native eyes/mouth over the existing Iman body artwork.
- `Iman/Voice`: bounded on-device recognition; explicit microphone lifecycle.
- `Iman/Connection`: validated pairing ticket, certificate pinning, camera scanner and serialized Mac jobs.
- `project.yml`: reproducible Xcode project generated only in the cloud.
- `scripts`: unsigned IPA packaging.

Sources: https://faq.altstore.io/altstore-classic/how-to-install-altstore-macos
https://docs.github.com/en/billing/concepts/product-billing/github-actions

## Hands-free mode (1.1)

After pairing, enable **Hands-free · Hi Iman**. Say “Hi Iman” followed by one command; a 1.4-second pause sends it. New words reset the pause. Ordinary speech without the wake phrase is not sent. Recognition stays on-device, pauses while the Mac works, and turns off if Iman leaves the foreground or loses its connection. Enable it again when returning. The sun button can keep the visible face awake; no background or lock-screen listening is enabled.

`WakePhrase` parses only a leading greeting. `HandsFreeSession` owns pause timing, cancellation and connection lifecycle separately from `VoiceInput`. Manual review/send is still available when hands-free mode is off.
