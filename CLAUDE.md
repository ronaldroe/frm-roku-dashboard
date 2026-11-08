# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

A Roku SceneGraph/BrightScript app (`roku-frm/`) that shows a live Satisfactory factory dashboard. It polls the HTTP API of the Ficsit Remote Monitoring (FRM) mod directly from the TV; there is no server-side component. The app is read-only: it never calls FRM's POST endpoints.

## Commands

There is no build step, linter or test suite. Code is verified by sideloading it to a Roku in developer mode and checking it on the device.

```sh
./deploy.sh                    # zip roku-frm/ and sideload to the Roku in .env (prints "Install Success" or the compile failure)
./release.sh --dry-run X.Y.Z   # preview a release; drop --dry-run to tag, push and publish a GitHub release with the zip
```

`.env` (gitignored, see `.env.example`) holds the Roku's `IP`, `user` (`rokudev`) and `pass`. Never commit it.

Device-side debugging and verification:

- **Compile and runtime errors** only appear on the Roku debug console, port 8085. `deploy.sh` reports just "Compilation Failed", so capture the console during the install to see the file and line:
  `timeout 20 bash -c "exec 3<>/dev/tcp/$IP/8085; cat <&3"`. Only one console connection is allowed at a time. `print` output from the app goes there too.
- **Simulating the remote** uses ECP on port 8060: `curl -d '' http://$IP:8060/keypress/Down` (also `Select`, `Back`, `Play`, `Info` for `*`, `Lit_<char>` to type into keyboards), and `curl -d '' http://$IP:8060/launch/dev` to relaunch.
- **Screenshots**: POST `mysubmit=Screenshot` to `http://$IP/plugin_inspect` with digest auth, then GET the `pkgs/dev.jpg?time=...` path it returns.
- The person who owns the TV may be using it at the same time, so keep keypress sequences short and put state back afterwards (unpin test pins, exit preview modes).

## Architecture

**Startup:** `source/main.brs` reads `frm_url` (optional, normally empty) and `refresh_seconds` from the manifest via `roAppInfo` and sets `MainScene.config`. `MainScene.onConfig` uses the server saved in the registry, falling back to the manifest value, and otherwise shows `SetupScreen` (first run).

**Data flow:** `FetchTask` (a Task node, its own thread) loops forever, polling FRM and condensing the raw JSON into small summaries before publishing one `result` assocarray per cycle. Everything heavy (parsing, grouping machines by type, recipe lookups) happens on the task thread, so the render thread only formats values. Polling is tiered:
- Every cycle (5 s): `getSessionInfo`, `getPower`, `getProdStats`, `getSpaceElevator`, `getHUBTerminal`, `getWorldInv`.
- Every 4th cycle: `getFactory` + `getExtractor`, `getGenerators`, `getResourceSink`, `getStorageInv`, `getCloudInv`. These are cached in `slow` and merged into every result.
- About every 10 minutes: `getRecipes` (~580 KB), kept in task memory as an item-to-recipes map. Only recipes for the current milestone and elevator parts are sent to the UI.
- Never fetch `getSchematics` (~850 KB).

Each result carries `base` (the server URL it came from). `MainScene` drops results whose `base` isn't the current server, and changing `FetchTask.baseUrl` makes the task reset its caches. On failure the result has `ok: false` plus `errKind`/`errCode` from `classifyFailure`.

**MainScene** builds the whole UI imperatively in `init()` (no XML layout) on a fixed 1920×1080 canvas. Key mechanisms:
- **Focus/tooltips:** every navigable element is registered with `addTarget(id, x, y, w, h, kind, idx)`. `isEnabled` decides from current data whether a target can be focused. `findNeighbor` picks the next target geometrically for each arrow direction. `tipFor` builds tooltip content as `[key, value]` rows; a key starting with `#` renders as a section header, and an empty value lets the key span the full width.
- **Production list:** `renderProd` builds `m.prodView`: the pinned section from `pinnedList()` (manual pins in pin order, then milestone parts, then Space Elevator parts when those auto-pin settings are on, deduplicated, capped at `MAX_PINNED_ROWS`), then the scrolling remainder at `m.prodOffset`. `m.prodAuto[i]` says whether pinned row `i` is manual (`""`) or auto (`"milestone"`/`"elevator"`); auto rows get a blue marker and can't be unpinned with OK. Row targets index into `m.prodView`, not the raw data.
- **Space Elevator alert:** fires on the not-ready to ready transition only (`m.seWasReady`), never on first load.
- **Pod status:** FRM's `ShipReturn` is broken in current mod versions (always `00:00:00`), so the app relies on `ShipDock` (true when docked). It times each trip itself in game time (paused time excluded) and stores the trip length per tier to estimate the next one. A non-zero `ShipReturn` still takes priority.

**SettingsScreen** opens on `*`. It writes its on/off options straight to the registry with `saveFlag` and sets `finished` to `"server"` (MainScene then opens `SetupScreen`, and cancelling that returns to settings) or `"done"`. MainScene re-reads the flags on close. To add an option, add an entry to `m.toggles` in `SettingsScreen.init` and read it with `loadFlag`.

**SetupScreen / ProbeTask:** `SetupScreen` handles entering an address (`StandardKeyboardDialog`), searching the network and connecting. `ProbeTask` tests one URL, or scans the Roku's /24 subnet in batches of 32 with a 1.5 s cutoff, falling back to port 8080. `SetupScreen.finished` returns either a URL or `"cancel"`.

**Common.brs** holds the shared helpers (HTTP with timeout, error classification and messages, address normalization, saved server). Each component compiles separately, so every component that uses these helpers must include `Common.brs` with its own `<script>` tag. Any function defined in `Common.brs` must not also be defined in a component's `.brs` file.

**Persisted state** is in the registry section `dashboard`: `server`, `pins` (JSON array of item names, max 5), `podTrip_<tier>`, and the settings flags `autoPinMilestone` / `autoPinElevator` (`"1"`/`"0"`, missing = off).

## BrightScript gotchas hit in this codebase

- `box` is a reserved word (a built-in function). Using it as a variable gives "Builtin function call expected".
- roAssociativeArray keys are case-insensitive, and iterating them can lowercase the keys. Store the display name inside the value (e.g. `{ name: n, count: 0 }`) and read it from there.
- An interface field only fires `onChange` when its value changes. Use `alwaysNotify="true"` for fields that may be set to the same value twice (e.g. `SetupScreen.message`, `finished`).
- To set a label's font size, assign the system font first, then the size: `l.font = "font:MediumSystemFont"` then `l.font.size = 30`.
- `LabelList` wraps around like a carousel by default; this app uses `vertFocusAnimationStyle = "floatingFocus"`.

## FRM API notes

- Default port 8080. The web server is off until started in game: pause menu → Options → Ficsit Remote Monitoring (the mod has its own Options entry; there is no Mods tab) → auto-start, or chat `/frm http start`.
- `getResourceSink[0].Percent` is 0–1, not 0–100.
- Milestone and elevator progress come from `Cost[]` / `CurrentPhase[]` using `TotalCost - RemainingCost`.
- FRM has no endpoint to submit or launch the Space Elevator. Its only write endpoints are `sendChatMessage`, `setSwitches`, `setEnabled`, `createPing` and `setModSetting`.
