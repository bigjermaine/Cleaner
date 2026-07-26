# Cleaner

[![Downloads](https://img.shields.io/github/downloads/bigjermaine/Cleaner/total?label=downloads)](https://github.com/bigjermaine/Cleaner/releases)
[![Latest release](https://img.shields.io/github/v/release/bigjermaine/Cleaner)](https://github.com/bigjermaine/Cleaner/releases/latest)

A macOS app that removes Git merge-conflict markers from pasted text. Choose a simple rule-based strategy, or let on-device **Apple Intelligence** pick a smart resolution.

## Features

- Paste conflicted text and clean it instantly
- Resolution strategies:
  - **HEAD** — keep the first side of each conflict
  - **Incoming** — keep the second side
  - **Remove** — drop both sides (markers and conflicted lines)
  - **Smart** — use Apple’s on-device Foundation Model to resolve conflicts
- Copy cleaned result to the clipboard

## Requirements

- macOS 26 or later
- Xcode 26+ (to build from source)
- **Smart** mode requires [Apple Intelligence](https://www.apple.com/apple-intelligence/) enabled on a supported Mac

## Download

Grab the latest build from [Releases](https://github.com/bigjermaine/Cleaner/releases). The downloads badge at the top updates automatically from Release asset downloads.

> Gatekeeper note: if macOS blocks the app, Right-click the app → **Open**, then confirm.

## Build from source

1. Open `Cleaner.xcodeproj` in Xcode
2. Select the **Cleaner** scheme
3. Product → Run (or Archive for a release build)

## Usage

1. Paste text that contains Git conflict markers (`<<<<<<<`, `=======`, `>>>>>>>`)
2. Pick a resolution strategy
3. Click **Clean Merge Conflicts**
4. Copy the cleaned output

## How Smart mode works

Smart mode uses Apple’s **Foundation Models** (`SystemLanguageModel`) on device. Your pasted text stays on your Mac — no cloud API key and no network call for cleaning.

If Apple Intelligence isn’t available, use HEAD / Incoming / Remove instead.

## Privacy

- Conflict text is processed locally in the app
- Smart resolution runs on-device via Apple Intelligence
- No analytics or accounts required for the core cleaner
