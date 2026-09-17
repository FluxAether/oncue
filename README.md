# OnCue

Desktop interview copilot for **macOS** and **Windows**, built with **Tauri 2** and **React 19**.

Bring your own API keys. Settings, resumes, interview history, and keys stay on the local machine.

## Features

- **Stealth Copilot** — Capture system audio and/or the microphone, transcribe in real time, and show structured answer suggestions in a floating window.
- **AI Mock Interviews** — Generate a role-specific plan, ask follow-ups, score answers, and produce a practice report. Voice turns are supported.
- **Resume Optimizer** — Match a resume against a job description and export an edited DOCX.
- **History** — Review saved Copilot and mock-interview sessions, including recordings when they were captured.

The UI supports Simplified Chinese, Traditional Chinese, and English. Theme follows Light, Dark, or System.

## Requirements

- Node.js 20+
- Rust stable (for native builds)
- On macOS 14.2+, a Swift toolchain if you want system-audio capture (AudioTee sidecar)
- Your own keys:
  - **Deepgram** for speech-to-text
  - **Groq**, **OpenAI**, **Anthropic**, or **Google Gemini** for language features

API keys are entered in **Settings**. They are stored in the local SQLite database under the app data directory (`com.oncue.desktop`). They are not committed to this repository.

Use the copilot only where interview or assessment rules allow assistance tools.

## Getting Started

```bash
npm install
npm run tauri dev
```

On macOS, system-audio capture in development:

```bash
npm run tauri:mac-audio
```

Frontend-only (no native audio or windows):

```bash
npm run dev
```

## Build

```bash
# Current platform
npm run tauri build

# macOS universal app with AudioTee
npm run build:mac

# Windows x64
npm run build:win
```

Checks used in development:

```bash
npm run lint
npm run verify:copilot
npm run verify:mock
npm run verify:resume
npm run verify:theme
npm run verify:db-storage
```

## Audio Capture

Stealth Copilot can listen to **your microphone**, **the interviewer's playback** (system output), or both. When both are enabled, the native layer mixes them.

### macOS

- **14.2+** uses a bundled [AudioTee](https://github.com/makeusabrew/audiotee) sidecar for 16 kHz mono capture of the default system output.
- Microphone capture uses `cpal` and is optional.
- The sidecar source commit is pinned; `scripts/build-audiotee.sh` verifies it and writes architecture checksums to `src-tauri/target/audiotee-checksums.txt`. Policy and reference hashes live in `src-tauri/binaries/audiotee.lock`.
- The first system-audio session requests **System Audio Recording** permission. AudioTee does not capture the screen.
- macOS 13.0–14.1 stays on microphone-only mode.

### Windows

- System audio uses WASAPI loopback on the default render device (shared mode) via `cpal`.
- Microphone capture is optional; both sources mix in the native layer.
- If the default output device changes, restart capture. Exclusive-mode playback and DRM-protected content are not supported.

Other platforms fall back to microphone-only mode. See **Settings → Audio Capture**.

## Privacy

- BYOK and Apple speech recognition work without an OnCue account. Interview content stays on this device.
- Optional hosted mode signs in through the Gateway OIDC Provider using Authorization Code + PKCE. The refresh token is stored in the OS keychain; access tokens stay in memory.
- Resume text, history, settings, and BYOK API keys live in local app data.
- Recordings are files under the app data directory, not in this git tree.
- In BYOK mode, speech and model calls go directly from the app to the providers you configure.

`.env` files, local AI tool directories, and generated sidecars are gitignored. Copy `.env.example` for desktop and Gateway configuration.

## Releases

Pushing a `v*` tag runs `.github/workflows/release.yml`. The workflow builds macOS (universal) and Windows installers, then publishes them to this repository's GitHub Release together with `latest.json` and `SHA256SUMS.txt`.

The in-app updater reads `plugins.updater.endpoints` in `src-tauri/tauri.conf.json`. That URL must be publicly downloadable.

Optional CI secrets for signed builds:

| Secret | Purpose |
| --- | --- |
| `APPLE_CERTIFICATE`, `APPLE_CERTIFICATE_PASSWORD`, `KEYCHAIN_PASSWORD` | macOS signing |
| `TAURI_SIGNING_PRIVATE_KEY`, `TAURI_SIGNING_PRIVATE_KEY_PASSWORD` | Updater signatures |

Unsigned packages may trigger OS security warnings. Prefer Release assets and check `SHA256SUMS.txt`.

macOS notarization and Windows Authenticode signing are operator-specific; see `src-tauri/tauri.conf.json`, `src-tauri/entitlements.plist`, and the release workflow.

## Project Layout

```text
src/                 React UI and feature logic
src-tauri/           Tauri / Rust host, audio, speech, windows
server/              Hosted Gateway and OIDC Provider
docs/                Design notes and feature plans
scripts/             Build, verify, and migration helpers
.github/workflows/   Release and Gateway workflows
```

## Tech Stack

Tauri 2 (Rust) · React 19 · TypeScript · Tailwind · Lucide · SQLite · Deepgram (STT) · Groq / OpenAI / Anthropic / Gemini (LLM)

## License

[MIT](LICENSE)
