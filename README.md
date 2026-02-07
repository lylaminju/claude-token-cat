# Claude Token Cat

A macOS menu bar app that tracks your Claude API token usage with an animated pixel art cat. The cat's behavior changes as you consume more tokens in a session.

```
    /\_/\          ╭──────────────────────────╮
   ( o.o )  ←───  │ Claude Token Cat      45% │
    > ^ <         │ ████████████░░░░░░░░░  ▏ │
   /|   |\        │ 135.0k / 300.0k tokens   │
                  │ 🕐 2h 58m remaining       │
                  ╰──────────────────────────╯
```

## Cat States

The cat animates in the menu bar based on your token usage:

```
  Usage         State       Animation            Speed
 ─────────────────────────────────────────────────────
  No session    idle        Sitting, tail wag     0.6s
  0 – 39%       running     Energetic sprint      0.15s
  40 – 79%      walking     Calm stroll           0.35s
  80 – 99%      tired       Lying down, yawning   0.8s
  100%          sleeping    Curled up, ZZZ...      1.2s
```

## Project Structure

```
ClaudeTokenCat/
│
├── Package.swift                          # Swift Package Manager config (macOS 13+)
├── build.sh                               # Build script → outputs .app bundle
│
├── ClaudeTokenCat/                        # App source & resources
│   ├── Info.plist                          #   App metadata (LSUIElement = true → no dock icon)
│   ├── ClaudeTokenCat.entitlements         #   Network client + Keychain access
│   ├── Assets.xcassets/                    #   Asset catalog (app icon)
│   │
│   └── Sources/
│       ├── ClaudeTokenCatApp.swift         #   @main entry point — launches NSApplication
│       ├── AppDelegate.swift               #   Status bar item, popover, animation loop
│       ├── TokenUsageManager.swift         #   Token tracking state (mock data for now)
│       ├── PopoverView.swift               #   SwiftUI popover UI (usage bar, settings)
│       └── CatSpriteRenderer.swift         #   Pixel art sprite engine + CatState enum
│
├── build/                                 # Build output
│   └── ClaudeTokenCat.app/                #   Assembled macOS .app bundle
│
└── ClaudeTokenCat.xcodeproj/              # Xcode project (optional, can use SPM)
```

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                      macOS Menu Bar                         │
│  ┌──────────────────────────────────────────────────────┐   │
│  │  NSStatusItem  ←──  animated NSImage (pixel cat)     │   │
│  └────────────┬─────────────────────────────────────────┘   │
│               │ click                                       │
│  ┌────────────▼─────────────────────────────────────────┐   │
│  │  NSPopover  →  PopoverView (SwiftUI)                 │   │
│  │  ┌───────────────────────────────────────────────┐   │   │
│  │  │  Token usage bar  ·  Session timer            │   │   │
│  │  │  Cycle State (debug)  ·  Settings / API key   │   │   │
│  │  └───────────────────────────────────────────────┘   │   │
│  └──────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────┘

┌─────────────────────┐       publishes        ┌──────────────────────┐
│  TokenUsageManager  │ ────────────────────▶   │     AppDelegate      │
│  (ObservableObject) │   @Published state      │                      │
│                     │                         │  observes changes →  │
│  · tokensUsed       │                         │  switches CatState → │
│  · tokenLimit       │   ◀──── Combine ────    │  restarts animation  │
│  · sessionStartDate │                         │                      │
│  · isSessionActive  │                         └──────────┬───────────┘
│  · catState         │                                    │
│  · usageRatio       │                                    │ frames(for:)
└─────────────────────┘                                    ▼
                                                ┌──────────────────────┐
                                                │  CatSpriteRenderer   │
                                                │                      │
                                                │  28×18 pixel grids → │
                                                │  NSImage (template)  │
                                                │                      │
                                                │  States:             │
                                                │   idle     (3 frames)│
                                                │   running  (3 frames)│
                                                │   walking  (3 frames)│
                                                │   tired    (2 frames)│
                                                │   sleeping (2 frames)│
                                                └──────────────────────┘
```

## Build & Run

```bash
./build.sh                         # Build with Swift Package Manager
open build/ClaudeTokenCat.app      # Launch the menu bar app
pkill -f ClaudeTokenCat            # Stop the app
```

Requires **macOS 13+** and Xcode command line tools.

## Status

Prototype — currently uses mock data. The popover includes a debug "Cycle State" button to preview all cat animations. Real Claude API polling is stubbed in `TokenUsageManager.fetchUsage()`.
