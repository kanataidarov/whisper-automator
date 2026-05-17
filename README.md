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
4. Configure the **Hold to dictate** shortcut
5. Grant Accessibility access when prompted so text can be inserted into other apps
6. The key is stored securely in macOS Keychain

## Usage

1. Click in any text input where you want the dictated text to appear
2. Hold your configured dictation shortcut
3. Speak into your microphone
4. Release the shortcut — the audio is sent to the Whisper API
5. The transcribed text is pasted into the focused input field

Whisper Automator also appears in the macOS menu bar. Use the menu bar item to view status, start or stop recording, open the app, open Settings, or quit.

## Microphone Permission

On first recording the system will prompt for microphone access. Grant it to `Whisper Automator.app`. If you previously denied access, re-enable it in **System Settings > Privacy & Security > Microphone**.

## Accessibility Permission

Text insertion into other apps requires Accessibility access. If you skip the permission, transcriptions are copied to the clipboard instead. You can request access from Settings.

## Privacy

- Microphone permission is requested on first recording attempt.
- Your API key is stored in macOS Keychain and never written to disk in plain text.
- Audio files are temporary and deleted immediately after transcription.
