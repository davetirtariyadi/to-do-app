# Todo

A small, keyboard-first to-do window for macOS. It floats above other apps, lives in the menu bar and opens from anywhere.

## Build and install

```bash
scripts/make-app.sh          # builds build/Todo.app and installs it to ~/Applications
open ~/Applications/Todo.app
scripts/test.sh              # runs the unit tests
```

Only `main` installs. On any other branch `make-app.sh` builds `build/Todo.app` as "Todo Dev" (`com.local.todo.dev`) and leaves `~/Applications` alone. For quick tries, `swift run` works too.

To have `main` reinstall itself after every merge, run this once from the checkout that stays on `main`:

```bash
scripts/install-auto-update.sh              # checks every 5 min and on local merges
scripts/install-auto-update.sh --uninstall
```

It fetches `origin/main`, rebuilds only when the commit changes, and reopens the app if it was running. Progress goes to `~/Library/Logs/todo-auto-update.log`.

You only need the Command Line Tools (`xcode-select --install`). Xcode and an Apple Developer account aren't required. Run the tests with `scripts/test.sh` rather than plain `swift test`. With only the Command Line Tools, `swift test` can't find the Swift Testing macros ("plugin for module 'TestingMacros' not found"), so the script points the compiler at them. It passes any extra arguments through, e.g. `scripts/test.sh --filter StoreTests`.

## Using it

| Where | Keys |
|---|---|
| Anywhere | **⌃⌘Space** show/hide · **⌃⌥N** add a to-do · **⌃⌥B** brain dump |
| Home | ↑↓ ⏎ · **A** add · **B** brain dump · **C** catch up · **V** view · Esc hides |
| Add | type → **⏎** add · **⇧⏎** add another · **Tab** → Group → Date → Today → Add · **⌘⏎** add from anywhere |
| Brain dump | type → **⏎** dump · **⇧⏎** dump another · **⌘⏎** dump from anywhere · Esc back |
| Group picker | ⏎ open · ↑↓ or first letter · ⏎ pick · "New group…" to create one |
| Calendar | ←→ day · ↑↓ week · PgUp/PgDn month · **T** today · ⌫ clear · ⏎ pick |
| View | ↑↓ ⏎ · **T** Today · **A** All · **B** Board · **G** Groups · **N** Notes |
| Notes | ↑↓ move · **⏎** or **A** turn into a to-do · **⌫** delete · Esc back to View |
| Today / All / Board | ↑↓ move · Space done · **T** toggle Today · **G** move to group (or click the dot) · **R** rename · **⌫** delete · **1–3** switch · ←→ columns on Board |
| Groups | ↑↓ · **⏎** rename · **C** / ⇧C colour · **⌥↑↓** reorder (Board columns follow) · **⌫** delete (choose where its to-dos go) · **N** new |
| Catch up | **1** to-dos · **2** notes · → done, or make a to-do · ← not done, or keep · **⌫** delete a note · **Z** undo · **R** run again |

Esc always goes back one level, and pressing it on Home hides the window. The menu bar icon shows how many Today items are still open. Its menu has **Brain dump…**, **Manage groups…**, **Keep on top**, **Appearance** (Match System, Light or Dark) and **Launch at login**. Notes are stored beside to-dos. They stay out of the to-do deck and that count, and Catch up reviews them on their own pass.

## Data

Everything is stored in `~/Library/Application Support/Todo/todos.json`, a plain JSON file you can back up or edit. Only the installed app (`com.local.todo`) uses it. Dev builds and `swift run` use `~/Library/Application Support/Todo-dev/todos.json`, so testing never touches real data.

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
