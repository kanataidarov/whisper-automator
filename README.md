# whisper-automator

A native macOS desktop app that records your speech and transcribes it using the OpenAI Whisper API. 

## Requirements

- macOS 14 (Sonoma) or later
- Swift 6.0+ toolchain (Xcode CLI tools)
- An OpenAI API key with access to the Whisper model

## Build & Run

Build the `.app` bundle (no Xcode required):

```bash
./Scripts/build-app.sh --run
```

This will:
1. `swift build` the executable
2. Assemble `dist/Whisper Automator.app` with proper `Info.plist`
3. Ad-hoc codesign the bundle
4. Launch the app (with `--run`)

For a release build:

```bash
./Scripts/build-app.sh --release --run
```

Or just build without launching:

```bash
./Scripts/build-app.sh
```

## Setup

1. Launch the app
2. Open Settings (**Cmd+,**)
3. Paste your OpenAI API key and click **Save Key**
4. The key is stored securely in macOS Keychain

## Usage

1. Select the transcription language (Русский / Қазақша / English)
2. Press **Record** (or hit **Space**)
3. Speak into your microphone
4. Press **Stop** — the audio is sent to the Whisper API
5. The transcribed text appears in the app
6. Click **Copy to Clipboard** to use the text elsewhere

## Microphone Permission

On first recording the system will prompt for microphone access. Grant it to `Whisper Automator.app`. If you previously denied access, re-enable it in **System Settings > Privacy & Security > Microphone**.

## Privacy

- Microphone permission is requested on first recording attempt.
- Your API key is stored in macOS Keychain and never written to disk in plain text.
- Audio files are temporary and deleted immediately after transcription.
