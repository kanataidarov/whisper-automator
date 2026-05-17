# whisper-automator

A native macOS menu-bar app that records your speech and transcribes it using the OpenAI Whisper API. The app lives entirely in the system tray — no Dock icon, no main window.

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

1. Launch the app — it appears only as a menu-bar icon (microphone)
2. Click the menu-bar icon → **Settings…**
3. Paste your OpenAI API key and click **Save Key**
4. Choose your output language (RU/EN/KZ). Speech is auto-detected and translated into this selected language
5. Choose a text insertion mode. **Paste (Cmd+V)** is the default; **Type ASCII** helps with RDP when paste does not work
6. Configure the **Hold to dictate** shortcut
7. Grant Accessibility access when prompted so text can be inserted into other apps
8. The key is stored securely in macOS Keychain

## Usage

### Via keyboard shortcut (hold-to-talk)

1. Focus any text input where you want the dictated text to appear
2. Hold your configured dictation shortcut
3. Speak into your microphone
4. Release the shortcut — the audio is transcribed, translated into your selected output language, and pasted into the focused input field

### Via menu-bar button

1. Focus the text input where you want the transcription
2. Click the menu-bar icon → **Start Recording**
3. Speak into your microphone
4. Click the menu-bar icon → **Stop Recording & Transcribe** — the text is transcribed, translated into your selected output language, and pasted into the previously focused app

For RDP or remote terminals, try **Type ASCII** in Settings if **Paste (Cmd+V)** misbehaves.

## Microphone Permission

On first recording the system will prompt for microphone access. Grant it to `Whisper Automator.app`. If you previously denied access, re-enable it in **System Settings > Privacy & Security > Microphone**.

## Accessibility Permission

Text insertion into other apps requires Accessibility access. If you skip the permission, transcriptions are copied to the clipboard instead. You can request access from Settings.

## Privacy

- Microphone permission is requested on first recording attempt.
- Your API key is stored in macOS Keychain and never written to disk in plain text.
- Audio files are temporary and deleted immediately after transcription.
