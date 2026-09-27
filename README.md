# OnCue

[![Website](https://img.shields.io/badge/Website-oncue.top-2563eb?style=flat-square)](https://www.oncue.top)
[![Release](https://img.shields.io/github/v/release/FluxAether/oncue?style=flat-square)](https://github.com/FluxAether/oncue/releases/latest)
[![Platform](https://img.shields.io/badge/Platform-macOS%20%7C%20Windows-gray?style=flat-square)]()
[![License](https://img.shields.io/badge/License-MIT-green?style=flat-square)](LICENSE)

> Local-first desktop AI interview copilot and career preparation engine for **macOS** and **Windows**, built with **Tauri 2** and **React 19**.
>
> 🌐 **Official Website / 官网**: [https://www.oncue.top](https://www.oncue.top)  
> 🌐 **English Portal**: [https://www.oncue.top/en](https://www.oncue.top/en)  
> ⬇️ **Download Installer**: [Latest Releases](https://github.com/FluxAether/oncue/releases/latest) · [Website Downloads](https://www.oncue.top)  
> 💳 **Plans & BYOK Access**: [https://www.oncue.top/subscribe](https://www.oncue.top/subscribe) ([English](https://www.oncue.top/en/subscribe))

OnCue helps candidates prepare for and navigate interviews with confidence. It captures system audio and your microphone in real time with zero acoustic feedback, transcribes conversations with low latency, and generates structured answer suggestions in a floating copilot window. It also provides realistic voice-based mock interviews with comprehensive scoring reports, and deep resume optimization tailored to target job descriptions.

All resumes, interview recordings, transcripts, settings, and BYOK credentials remain securely on your local device.

## Features / 功能特性

- **Stealth Copilot (实时隐形面试辅助)**:
  - Dual-channel real-time audio capture: captures interviewer playback (system audio loopback) and/or your microphone with zero acoustic feedback.
  - Low-latency real-time speech-to-text (STT) transcription.
  - Live structured answer suggestions and question-by-question outlines in a discreet floating or docked window.
  - Global shortcut toggles visibility instantly.
  - [Learn more about Live Copilot](https://www.oncue.top/features/live-copilot)
- **AI Mock Interviews (多轮语音实战模拟)**:
  - Generate customized interview question sets based on your resume and target Job Description (JD).
  - Practice with natural, multi-turn voice interaction and dynamic follow-up probing.
  - Receive actionable diagnostic scoring reports covering technical depth, communication, and structure.
  - [Learn more about Mock Interviews](https://www.oncue.top/features/mock-interview)
- **Targeted Resume Optimizer (简历针对性优化)**:
  - Deep semantic comparison between candidate resumes (PDF / DOCX) and target job specifications.
  - Highlights quantifiable impact, enhances technical keywords, and exports formatted DOCX files.
- **Session History & Review (面试复盘与录音回溯)**:
  - Automatically saves Copilot sessions, questions, answer outlines, and optional native audio recordings for post-interview review and learning.
- **Internationalization & Themes**:
  - UI supports **Simplified Chinese (简体中文)**, **Traditional Chinese (繁體中文)**, and **English**.
  - Built-in **Light**, **Dark**, and **System** appearance modes.

## Download & Installation / 下载安装

Pre-built releases for macOS and Windows are available on the [Official Website](https://www.oncue.top) and [GitHub Releases](https://github.com/FluxAether/oncue/releases/latest).

| Platform | Requirements | Architecture | Package |
| --- | --- | --- | --- |
| **macOS** | macOS 14.2+ (for system audio) / 13.0+ | Universal (Apple Silicon & Intel) | [`.dmg`](https://github.com/FluxAether/oncue/releases/latest) |
| **Windows** | Windows 10 / 11 (64-bit) | x64 | [`.exe` installer](https://github.com/FluxAether/oncue/releases/latest) |

> **macOS Note**: System audio capture on macOS 14.2+ utilizes a bundled AudioTee sidecar. On first launch, grant **System Audio Recording** permissions when prompted. Screen recording is not used.
>
> **Windows Note**: System audio capture uses WASAPI loopback on your default playback device.

## AI Providers (BYOK)

OnCue supports both **Bring Your Own Key (BYOK)** and **Hosted Account Mode**:

- **Speech-to-Text (STT)**:
  - [Deepgram](https://deepgram.com) (Nova-2 / Nova-3, real-time streaming)
  - Apple Speech Recognition (macOS local offline recognition)
- **Large Language Models (LLM)**:
  - [Google Gemini](https://ai.google.dev)
  - [OpenAI](https://platform.openai.com)
  - [Groq](https://groq.com)
  - [Anthropic Claude](https://anthropic.com)

API keys are configured in **Settings** and stored in the local SQLite database under the app data directory (`com.oncue.desktop`). They are never committed or uploaded to intermediary servers in BYOK mode.

Use the copilot only where interview or assessment rules allow assistance tools.

## Requirements

- Node.js 20+
- Rust stable (for native builds)
- On macOS 14.2+, a Swift toolchain if you want system-audio capture (AudioTee sidecar)

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

Tauri 2 (Rust) · React 19 · TypeScript · Tailwind CSS · Lucide · SQLite · Deepgram (STT) · Groq / OpenAI / Anthropic / Gemini (LLM)

## Official Links / 官方资源

- **Official Website (官网)**: [https://www.oncue.top](https://www.oncue.top)
- **English Portal**: [https://www.oncue.top/en](https://www.oncue.top/en)
- **Live Copilot Guide**: [https://www.oncue.top/features/live-copilot](https://www.oncue.top/features/live-copilot)
- **Mock Interview Guide**: [https://www.oncue.top/features/mock-interview](https://www.oncue.top/features/mock-interview)
- **Subscription & Credits**: [https://www.oncue.top/subscribe](https://www.oncue.top/subscribe) ([English](https://www.oncue.top/en/subscribe))
- **GitHub Repository**: [https://github.com/FluxAether/oncue](https://github.com/FluxAether/oncue)
- **Releases & Changelog**: [https://github.com/FluxAether/oncue/releases](https://github.com/FluxAether/oncue/releases)

## License

[MIT](LICENSE)
