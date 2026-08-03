# Handoff notes for debugging the Windows port

Written 2026-08-02 by a Claude session running on Brad's Mac, for a Claude session running on Brad's Windows machine. Delete this file once the port builds and runs.

## Situation

Everything in `windows/` is a port of the macOS screensaver in `../macOS` (Swift, ~2,200 lines) to C#/.NET 8 WPF. **It was written entirely on macOS and has never been compiled** — .NET's Windows UI stack doesn't exist on Mac, so not even `dotnet build` was possible. Brad reported "the test build isn't working" with no further detail; the first job is simply getting `dotnet build windows` clean, then `dotnet run --project windows -- /w` (windowed test mode) working.

Brad has never done Windows development before — when the build works, tell him plainly what to run and what he should see.

## What each file is (and its Swift source of truth)

| C# file | Ported from | Notes |
|---|---|---|
| `Program.cs` | (no equivalent) | Entry point; screensaver arg contract `/s` `/c` `/p <hwnd>`, plus custom `/w` windowed test mode. No args → config dialog. |
| `UI/ScreensaverWindow.cs` | `macOS/Ealain/EalainView.swift` | The heart. Two stacked `Image`s crossfading (5s fades, 15s swap timer), status + message labels, recently-used URL cycling. Logic was ported method-for-method; when in doubt about intent, read the Swift. |
| `Services/GenerationService.cs` | `EalainView.swift` `generateNewImages()` | One instance per orientation shared across monitors (deliberate change from macOS, which runs one loop per screen). Same timings, same status strings. |
| `Horde/HordeApi.cs`, `Horde/HordeModels.cs` | `Horde API/*.swift` | Near line-for-line. |
| `Services/ImageCache.cs` | parts of `EalainView.swift` | Downloads WebP from the horde, re-encodes to JPEG via ImageSharp (WPF has no reliable WebP codec). Cache: `%LOCALAPPDATA%\Ealain\<styleId>\<orientation>\`. |
| `Services/DisplayRegistry.cs` | (new) | Tracks on-screen files so pruning never deletes a displayed image. |
| `Settings.cs` | `Database.swift` | JSON at `%APPDATA%\Ealain\settings.json`, one setting: `StyleIdOverride`. |
| `UI/ConfigWindow.cs` | `ConfigureSheet/*` | |
| `Core.cs`, `Log.cs`, `NativeMethods.cs` | misc | Log file: `%LOCALAPPDATA%\Ealain\ealain.log` — a running screensaver has no console, this is where errors go. |

## Design constraints — please preserve

- **No XAML, deliberately.** All UI is built in C# code so errors surface at compile time instead of as runtime XAML parse crashes. Fix in place; don't convert to XAML.
- **Behavior parity with the Swift version is the spec.** Timings, status message wording, cache limits (100 images, prune 2 at a time), the 5s polling cadence — all mirror `EalainView.swift`. Don't "improve" behavior while debugging.
- Only NuGet dependency is `SixLabors.ImageSharp` (WebP decode). Avoid adding more.
- The messages.json lookup key is `windows-1.0` (vs `1.0` on macOS) so Brad can message platforms independently.

## Things the Mac session could not verify — likeliest bug sites

Compile-level risks:

1. **`System.Text.Json` positional records** (`Horde/HordeModels.cs`): constructor-parameter binding against `[property: JsonPropertyName]` attributes. If deserialization returns wrong/default values, switch the records to plain classes with `{ get; set; }` properties.
2. **ImageSharp API surface** (`Services/ImageCache.cs`): `Image.Load(byte[])` and `SaveAsJpegAsync(..., JpegEncoder)` were written from memory against v3.1.5. Check signatures if it doesn't compile.
3. `NativeMethods.RECT` uses `readonly` expression-bodied members inside a mutable struct — fine in C# 12, but if the compiler complains, drop the `readonly` modifiers.

Runtime-level risks (build succeeds, behavior wrong):

4. **Fullscreen positioning / DPI** (`ScreensaverWindow.OnSourceInitialized` + `app.manifest`): windows are placed with raw pixel `SetWindowPos` under a PerMonitorV2 manifest. If a window covers only part of a scaled monitor or lands on the wrong one, this interaction is the culprit.
5. **The `/p` preview** (`Program.RunPreview`): WPF `HwndSource` parented into the Screen Saver Settings thumbnail. Fiddliest code in the port and cosmetic-only — if it misbehaves, it's acceptable to make `/p` just exit (black thumbnail) rather than sink time into it.
6. **Opacity state machine** (`ScreensaverWindow`): the crossfade logic branches on exact `Opacity == 0.0 / 1.0` checks (faithful to the Swift). The `Fade` helper clears the animation and pins the base value in its `Completed` handler to make those exact checks valid. If images stop cycling after the first fade, look here.
7. **Single-file publish**: `PublishSingleFile` + `IncludeNativeLibrariesForSelfExtract` flags in the README publish command are unverified for WPF-on-.NET-8; if publish fails, try dropping `IncludeNativeLibrariesForSelfExtract` (a multi-file publish folder is an acceptable fallback — the `.scr` just needs its DLLs next to it).

Already fixed preemptively (don't re-introduce): `Dispatcher.BeginInvoke(lambda)` doesn't compile (lambdas don't convert to `Delegate`) — everything uses `Dispatcher.InvokeAsync` now.

## How to verify once it builds

1. `dotnet run --project windows -- /w` → windowed 1280×720. Expect a black window with "Ealain is starting..." bottom-left, status updates as the horde queue progresses (can take minutes — free volunteer GPU network), then images crossfading every ~15s. Esc closes.
2. Second run should start showing cached images immediately.
3. `dotnet run --project windows -- /c` → settings dialog; save a style ID, confirm it lands in `%APPDATA%\Ealain\settings.json`; blank it again.
4. `dotnet run --project windows -- /s` → fullscreen on every monitor, cursor hidden, exits on mouse move/key.
5. Full `.scr` install per `windows/README.md` (publish → rename → right-click Install), including the settings-dialog preview thumbnail.
6. Check `%LOCALAPPDATA%\Ealain\ealain.log` for ERROR lines even when things look fine.

When it all works: update `windows/README.md` (remove the "never compiled" warning), delete this file, and suggest Brad merge `windows-support` → `main` via the PR GitHub already offered.
