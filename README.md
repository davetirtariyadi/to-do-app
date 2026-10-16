# Todo

A small, keyboard-first to-do window for macOS. It floats above other apps, lives in the menu bar and opens from anywhere.

## Build and install

```bash
scripts/make-app.sh          # builds build/Todo.app and installs it to ~/Applications
open ~/Applications/Todo.app
```

You only need the Command Line Tools (`xcode-select --install`). Xcode and an Apple Developer account aren't required. Run the tests with `swift test`.

## Using it

| Where | Keys |
|---|---|
| Anywhere | **⌃⌥Space** show/hide · **⌃⌥N** add a to-do |
| Home | ↑↓ ⏎ · **A** add · **C** catch up · **V** view · Esc hides |
| Add | type → **⏎** add · **⇧⏎** add another · **Tab** → Group → Date → Today → Add · **⌘⏎** add from anywhere |
| Group picker | ⏎ open · ↑↓ or first letter · ⏎ pick · "New group…" to create one |
| Calendar | ←→ day · ↑↓ week · PgUp/PgDn month · **T** today · ⌫ clear · ⏎ pick |
| Today / All / Board | ↑↓ move · Space done · **T** toggle Today · **1–3** switch · ←→ columns on Board |
| Catch up | → done · ← not done · **Z** undo · **R** run again |

Esc always goes back one level, and pressing it on Home hides the window. The menu bar icon shows how many Today items are still open. Its menu has **Keep on top** and **Launch at login**.

## Data

Everything is stored in `~/Library/Application Support/Todo/todos.json`, a plain JSON file you can back up or edit.

## Code map

- `Sources/TodoCore`: the model, the JSON store and day-key date maths. It has no UI and is unit tested.
- `Sources/Todo`: the app shell (menu bar, floating `NSPanel`, Carbon hotkeys) and the SwiftUI screens in `Views/`.
- `Local.swift`: a stand-in for `@State`. In this SDK `@State` is a macro whose plugin ships only with full Xcode, so the Command Line Tools build can't use it.
- `DevHarness.swift`: a scripted keyboard walkthrough that saves a screenshot of each step. It never runs in normal use:
  ```bash
  TODO_DATA_FILE=/tmp/t.json TODO_SNAPSHOT_DIR=/tmp/shots build/Todo.app/Contents/MacOS/Todo
  ```

## Later: widget

A desktop or Notification Center widget would show Today with tappable checkboxes, using App Intents on macOS 14+. It needs full Xcode to build the widget extension, plus an App Group so the app and widget share `todos.json`.
