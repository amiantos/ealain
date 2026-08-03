# Ealain for Windows

This folder contains the Windows port of Ealain, written in C# with WPF on .NET 8. It is a faithful port of the macOS screensaver in `../macOS`: same AI Horde API flow, same crossfade timings, same status messages, same cache-and-prune behavior.

## How Windows screensavers work

A `.scr` file is just a renamed `.exe`. Windows launches it with a flag:

| Flag | Meaning |
|------|---------|
| `/s` | Run the actual screensaver, fullscreen on every monitor |
| `/c` | Show the settings dialog |
| `/p <hwnd>` | Draw a preview inside the thumbnail in Screen Saver Settings |
| `/w` | (Ours, not standard) Run in a 1280×720 window for development; add `portrait` for a 576×1024 one |

Running the exe with no arguments opens the settings dialog.

## One-time setup on your Windows machine

1. Install the .NET 8 SDK (in an Administrator PowerShell or via the installer from <https://dotnet.microsoft.com/download/dotnet/8.0>):

   ```powershell
   winget install Microsoft.DotNet.SDK.8
   ```

2. Install git if you don't have it (`winget install Git.Git`), then clone the repo and check out the branch:

   ```powershell
   git clone https://github.com/amiantos/ealain.git
   cd ealain
   git checkout windows-support
   ```

   (Optional: Visual Studio 2022 Community with the ".NET desktop development" workload gives you a full IDE and debugger, but the command line is enough.)

## Everyday development loop

Pull the latest work, then from the repo root:

```powershell
git pull

# Windowed test mode — easiest way to see it working; Esc closes it
dotnet run --project windows -- /w

# Same, but a portrait window, to exercise the portrait image cache
dotnet run --project windows -- /w portrait

# Real fullscreen mode — move the mouse or press any key to exit
dotnet run --project windows -- /s

# Settings dialog
dotnet run --project windows -- /c
```

**On first run the screen will be black with status text in the bottom-left corner for a few minutes** — that's the AI Horde generating the first images (it's a free, volunteer-run GPU network, so there's a queue). Once ~2 images are cached the crossfade cycle starts. Later runs start instantly from the cache.

## Where things live on disk

| Thing | Path |
|-------|------|
| Image cache | `%LOCALAPPDATA%\Ealain\<style-id>\<landscape or portrait>\` |
| Log file | `%LOCALAPPDATA%\Ealain\ealain.log` |
| Settings | `%APPDATA%\Ealain\settings.json` |

Paste those into the Explorer address bar as-is. If something misbehaves, check the log — a screensaver has no console, so the log is the only place errors go. Deleting the whole `%LOCALAPPDATA%\Ealain` folder resets everything.

## Building the actual screensaver (.scr)

```powershell
pwsh windows/publish.ps1
```

That publishes a self-contained single-file build, renames it to `.scr`, and writes `windows\dist\Ealain-1.0.0-Windows.zip` — the file to share. The version in the name comes from `<Version>` in `Ealain.csproj`, so bump it there for a release.

To install a build locally:

1. Copy `Ealain.scr` somewhere permanent (e.g. `C:\Screensavers\`) — Windows remembers the path of an installed screensaver, so don't leave it in `dist\` or the build folder, and don't move it afterwards.
2. Right-click it → **Install**. On Windows 11 that may be hidden behind **Show more options** (or press Shift+F10 instead of right-clicking).
3. That opens the Screen Saver Settings dialog with Ealain selected; set your idle timeout and hit OK. (You can get back to that dialog anytime via Settings → Personalization → Lock screen → Screen saver.)

The first launch after install pauses briefly while the single-file executable unpacks itself to a temp folder; later launches are cached.

If you'd rather run the publish by hand, the script is a thin wrapper around:

```powershell
dotnet publish windows -c Release -r win-x64 --self-contained -p:PublishSingleFile=true -p:IncludeNativeLibrariesForSelfExtract=true
```

Self-contained publish means users don't need .NET installed; the tradeoff is a ~155 MB file. Nobody minds for a screensaver, and it zips down a good deal smaller.

## Distribution notes (for later)

- Zip the `.scr` and share it, same as the macOS zip on S3.
- Unsigned downloaded executables trigger a SmartScreen warning ("Windows protected your PC") until enough people have run them. Users click "More info" → "Run anyway". Making that disappear requires a paid code-signing certificate — probably not worth it for a free screensaver.
- The message system (`messages.json` on S3) works here too, but this port looks up the key `windows-1.0` instead of `1.0`, so you can message Windows and macOS users independently.

## Implementation notes / differences from macOS

- **Images are cached as JPEG, not WebP.** The AI Horde serves WebP, which WPF can't decode without an optional OS codec, so downloads are re-encoded with the ImageSharp library (the only NuGet dependency).
- **One generation loop per orientation, shared across monitors.** On macOS each screen's view polls the horde independently; here two landscape monitors share one loop so we don't submit duplicate requests.
- **The preview thumbnail** in Screen Saver Settings shows a random cached image rather than the live crossfade. Best-effort; harmless if it fails.
- The config dialog stores its one setting (style ID override) in `settings.json` instead of macOS `UserDefaults`.
