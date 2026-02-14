# Project Conventions

## Commit Messages

- Use Conventional Commits prefixes: `feat:`, `fix:`, `refactor:`, `chore:`, `docs:`, etc.
- Use bulleted lists in the commit body for details

## Sprite Workflow

- Canvas: 28x18, `SpriteGrid = [[UInt8]]`, 1 = white pixel, 0 = transparent
- `isTemplate = true` on NSImage for automatic light/dark menu bar adaptation
- States defined in `CatState` enum in `CatSpriteRenderer.swift` — keep switch cases and sprite variables in the same order
- Build & run: `pkill -f ClaudeTokenCat; ./build.sh && open build/ClaudeTokenCat.app`

### Converting .piskel to Swift

1. Read the .piskel file (JSON with embedded base64 PNG spritesheet)
2. Decode the base64 PNG, open with PIL as RGBA
3. Detect color scheme:
   - **Transparent bg + black pixels**: `a > 128 and r < 128` → 1 (most common)
   - **Black bg + white pixels**: `r > 128` → 1 (no transparency)
4. Extract each frame at `x_offset = frame_index * width`
5. Output as Swift `[SpriteGrid]` array matching existing format
6. Replace the corresponding `*Frames` variable in `CatSpriteRenderer.swift`

### Tools

- `tools/preview_sprites.py` — Parse and preview sprites from Swift source as ASCII or PNG (`--png --state idle`)
- `tools/piskel2swift.py` — Convert .piskel files to Swift arrays
- `tools/live_preview.sh` — Watch Swift file and auto-regenerate preview PNGs on save
- `tools/screenshot.sh` — Capture PNG screenshots and GIF recordings of the menu bar icon

### Recording Menu Bar GIFs

- Requires a full-screened black terminal behind the menu bar (translucent menu bar shows wallpaper otherwise)
- Region: `-r X,5,70,28` (menu bar icon area including percentage number — X coordinate varies by desktop setup)
- Playback FPS (`-p`) should be lower than capture FPS (`-f`) because `screencapture` overhead makes real capture slower than nominal

| State    | Frames | Interval | Command |
|----------|--------|----------|---------|
| idle     | 4      | 0.35s    | `./tools/screenshot.sh gif -r X,5,70,28 -d 5 -f 5 -p 3` |
| jumping  | 7      | 0.15s    | `./tools/screenshot.sh gif -r X,5,70,28 -d 5 -f 10 -p 5` |
| walking  | 4      | 0.4s     | `./tools/screenshot.sh gif -r X,5,70,28 -d 7 -f 3 -p 2` |
| tired    | 3      | 0.8s     | `./tools/screenshot.sh gif -r X,5,70,28 -d 7 -f 5` |
| sleeping | 2      | 1.2s     | `./tools/screenshot.sh gif -r X,5,70,28 -d 4 -f 5` |

## Release Process

1. Create a **local tag**: `git tag vX.Y.Z`
2. Build: `./build.sh` (reads version from the tag automatically)
3. Create DMG: `hdiutil create -volname ClaudeTokenCat -srcfolder build/ClaudeTokenCat.app -ov -format UDZO build/ClaudeTokenCat.dmg`
4. Create GitHub release **with DMG attached in one step**: `gh release create vX.Y.Z build/ClaudeTokenCat.dmg`
5. The "Update Homebrew Tap" Action runs automatically — do NOT manually update the tap

**Rules:**
- Never replace assets on an existing release (`--clobber`) — if the binary changes, bump the version
- Never manually edit the Homebrew tap SHA — always let the Action handle it
- `Info.plist` version is a baseline; `build.sh` injects the real version from the git tag at build time

## Code Quality

- Before presenting Swift code changes, self-review for:
  - Dead code (unused functions, variables, imports)
  - Security issues (injection, insecure storage, hardcoded secrets)
  - Memory leaks (retain cycles, missing `[weak self]` in closures)
  - Inefficient logic (unnecessary allocations, O(n²) where O(n) is possible)
- Flag any concerns explicitly in your response

### Bug Analysis Checklist

When a user reports a bug, follow this structured process:

1. **Trace the code path** — from trigger to symptom, identify every function in the chain
2. **Identify root cause** — not just the surface error, but why the code fails
3. **Search for the same pattern** — grep the codebase for similar error handling gaps
4. **Check error recovery paths** — what happens when things fail? Is there a fallback?
5. **Verify the fix prevents recurrence** — don't just patch the symptom
