# GitLabBar

A tiny native macOS menu bar app that shows the status of your GitLab CI/CD
pipelines so you stop refreshing the GitLab tab.

The menu bar icon changes colour based on the aggregate state of every project
you watch:

| Icon                 | State                                                          |
| -------------------- | -------------------------------------------------------------- |
| `⟳` orange + counter | At least one pipeline is running (counter = number running)    |
| `✓` green            | Every project's most recent pipeline succeeded                 |
| `✕` red              | At least one project's most recent pipeline failed             |
| `◌` grey             | Not configured yet, or no data fetched                         |

Click the icon to open a popover with the latest pipelines per project. Each
row shows the branch, status, short commit SHA, trigger source and duration.
**Click a row to copy its commit SHA** to the clipboard; hover the row and
click the arrow icon to open the pipeline page in your browser.

- Works against self-hosted GitLab and gitlab.com
- Tracks multiple projects in parallel
- Pipeline rows show commit SHA, trigger source, run duration, and relative time
- Click a row to copy the commit SHA; arrow button opens it in your browser
- Personal Access Token stored in the **macOS Keychain**, never in plist
- Optional banner notifications when a pipeline transitions to failed / success
- Dedicated **History** window with search and persistent pipeline records
- Optional **Launch at Login** toggle (via `SMAppService`)
- No dependencies, no analytics, no network calls besides your GitLab instance
- Single binary, < 1 MB on disk

---

## Requirements

- macOS 13 Ventura or later (macOS 14+ adds a subtle pulse animation while pipelines run)
- A GitLab Personal Access Token with the `read_api` scope
  ([how to create one](https://docs.gitlab.com/ee/user/profile/personal_access_tokens.html))

For building from source you additionally need:

- Xcode 15 or later (Command Line Tools alone is not enough — the build uses Xcode SDKs)
- [xcodegen](https://github.com/yonaskolb/XcodeGen) (`brew install xcodegen`)

---

## Install with Homebrew

```bash
# 1. Tap this repository
brew tap ncthanhngo/gitlab-bar https://github.com/ncthanhngo/gitlab-bar.git

# 2. Install the latest tagged release
brew install gitlab-bar
```

If you prefer to track the `main` branch instead of the latest tag:

```bash
brew install --HEAD gitlab-bar
```

To upgrade later:

```bash
brew update && brew upgrade gitlab-bar
```

To uninstall:

```bash
brew uninstall gitlab-bar
brew untap ncthanhngo/gitlab-bar
```

> The formula builds from source, so the first install spends a few seconds
> running `xcodebuild`. After install, a `gitlab-bar` launcher is placed on your
> PATH; the actual `.app` lives under the brew prefix.

---

## Run

```bash
gitlab-bar
```

That opens the app and a `GitLabBar` icon appears on the right side of your menu
bar.

First-time setup:

1. Click the menu bar icon and choose **Settings…**
2. **Connection** tab — paste your GitLab base URL
   (`https://gitlab.your-company.com`) and your Personal Access Token.
3. **Projects** tab — add each project you want to watch. Use either a numeric
   project ID (`123`) or a URL path (`group/subgroup/repo`).
4. **General** tab — pick a refresh interval (default 30 s), how many
   pipelines to show per project, toggle banner notifications, and turn on
   **Launch at Login** if you want GitLabBar to start with macOS.
5. Close Settings. The icon updates within one refresh cycle.

Click **History…** in the popover footer to open the dedicated history window.
It lists every pipeline GitLabBar has fetched (capped at 500 records),
searchable by branch / status / project, and persisted at
`~/Library/Application Support/GitLabBar/pipeline-history.json`.

Banner notifications fire only when a pipeline transitions out of a running
state into success or failure — never on the initial fetch, and never for
states that were already terminal when GitLabBar first saw them.

---

## Build from source

```bash
git clone git@github.com:ncthanhngo/gitlab-bar.git
cd gitlab-bar/GitLabBar

brew install xcodegen          # one-time, if you don't have it yet
xcodegen generate              # creates GitLabBar.xcodeproj
open GitLabBar.xcodeproj       # then Cmd+R inside Xcode
```

Or without opening Xcode:

```bash
cd GitLabBar
xcodegen generate
xcodebuild -project GitLabBar.xcodeproj \
           -scheme GitLabBar \
           -configuration Release \
           -derivedDataPath build \
           build
open build/Build/Products/Release/GitLabBar.app
```

---

## Architecture

```
GitLabBar/
├── project.yml                         # xcodegen spec (source of truth)
├── Resources/
│   ├── Info.plist                      # generated
│   └── GitLabBar.entitlements          # generated
└── Sources/
    ├── App/                            # @main entry, MenuBarExtra + Settings + History scenes
    ├── Models/                         # Pipeline, ProjectConfig, PipelineStatus, PipelineHistoryRecord
    ├── Services/                       # GitLabAPI(+Client), KeychainHelper, PipelineMonitor,
    │                                   # NotificationService, PipelineHistoryStore, LaunchAtLoginService
    ├── Stores/                         # AppSettings (ObservableObject)
    ├── Support/                        # AppConstants, AppLogger
    └── Views/                          # MenuBarContentView, PipelineRowView, SettingsView, HistoryView
Formula/
└── gitlab-bar.rb                       # Homebrew formula
```

Design rules:

- Swift 5.10 with strict concurrency enabled.
- One type per file, files stay under ~200 LoC.
- `Models/` are plain `Codable`/`Sendable` value types.
- `Services/` perform all I/O; they may not import SwiftUI.
- `Stores/` are `@MainActor` observable holders that views observe.
- Networking is `async`/`await` on top of `URLSession`. No third-party deps.

---

## Privacy & security

- Personal Access Token is written to the **macOS login Keychain** via
  `Security.framework`. It is never persisted to `UserDefaults`, plist, or
  logs.
- The app sandbox is intentionally **off**: a self-hosted GitLab URL is
  user-supplied and arbitrary; sandboxing would not be meaningful here.
- `NSAllowsArbitraryLoads` is **true** in `Info.plist` so the app can reach
  internal GitLab instances that use a private CA. Combined with the user
  supplying the URL, this is appropriate for this use case but consider it
  before deploying in a hostile environment.
- The only network calls go to the GitLab base URL you configure.

---

## Releasing (maintainers)

1. Bump `MARKETING_VERSION` in `GitLabBar/project.yml`.
2. Tag and push: `git tag v0.x.y && git push origin v0.x.y`.
3. Update `url` and `sha256` in `Formula/gitlab-bar.rb` with the tarball from
   the new tag. The SHA can be computed via
   `curl -sL <tarball-url> | shasum -a 256`.
4. Commit the formula bump on `main`.

---

## License

[MIT](./LICENSE) — Copyright (c) 2026 Thanh Ngo `<nc.thanhngo@gmail.com>`
