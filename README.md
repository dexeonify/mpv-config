# mpv-config

My personal [mpv](https://github.com/mpv-player/mpv) config and user scripts :)

Nothing special, not even any fancy shaders or anything, since I only have an
integrated GPU. This is mainly just for backup and keeping track of changes.

## Fonts

- [Open Sans](https://fonts.google.com/specimen/Open+Sans) (OSC)
- [Manrope](https://github.com/sharanda/manrope) (Subtitles)
- [Cascadia Code](https://github.com/microsoft/cascadia-code) (Console)

> **Warning** \
> Install my custom-made icon font [modernx-osc-icon.ttf](https://github.com/dexeonify/mpv-config/raw/main/fonts/modernx-osc-icon.ttf)
> for the OSC icons.

## User scripts

- **[auto-save-state.lua](https://github.com/AN3223/dotfiles/blob/master/.config/mpv/scripts/auto-save-state.lua):**
  Periodically saves "watch later" data during playback, rather than only
  saving on quit.

- **[crop.lua](https://github.com/occivink/mpv-scripts#croplua):**
  Crop the video by defining the target rectangle with the cursor.

- **[file-browser.lua](https://github.com/CogentRedTester/mpv-file-browser):**
  Navigate through the file system entirely from within mpv and open/append
  files & folders.

- **[modernx.lua](https://github.com/dexeonify/mpv-config/blob/main/scripts/modernx.lua):**
  My own spin on [MordenX](https://github.com/cyl0/ModernX), with added support
  of po5's thumbfast.lua (see below) and upstream fixes ported from from mpv's
  [osc.lua](https://github.com/mpv-player/mpv/blob/master/player/lua/osc.lua).
  You can view the differences between the upstream/forks [here](#difference-between-upstream-modernx).

- **[playlistmanager.lua](https://github.com/jonniek/mpv-playlistmanager):**
  Create and manage playlists intuitively. Uses [playlistmanager-save-interactive.lua](https://github.com/jonniek/mpv-playlistmanager/blob/master/playlistmanager-save-interactive.lua)
  to manually name playlists on save.

- **[reload.lua](https://github.com/4e6/mpv-reload):**
  Provides automatic reloading of videos that didn't have buffering progress
  for some time, keeping the current time position.

- **[seek-to.lua](https://github.com/occivink/mpv-scripts#seek-tolua):**
  Seek to an absolute timestamp specified via keyboard input or
  pasted from clipboard.

- **[SmartCopyPaste.lua](https://github.com/Eisa01/mpv-scripts#smartcopypaste):**
  Add the capability to copy and paste while being smart and customizable.

- **[thumbfast.lua](https://github.com/po5/thumbfast):**
  High-performance on-the-fly thumbnailer for mpv.

> **Note** \
> Some of the scripts have been modified to suit my needs. You can see the
> exact changes by looking at the commit history for each individual script.

## Difference between upstream ModernX

<details>
<summary>Expand</summary>

### New

- Add `movesub` feature
- Move console when OSC is visible
- Add script-opts to show OSC on `file-loaded` and `seek`
- Add logarithmic volume control (`processvolume` in [modern])
- Add replay button at the end of playback ([modern#21])
- Add hover effect to icons
- Add `blur_intensity`, `osc_color`, `seekbarfg_color`, `seekbarbg_color` and
  `titlefont` script-opts to customize OSC

### Changes

- Use Feather icons (outlined, rounded corners) instead of Material Icons
  (solid, sharp corners)
- Use osc.lua's windows control bar
- Change default font size for title, tooltip & timecode
- No translations
- No support for directional keyboard ([ModernX#4])

### Improvements

- More frequent syncing from upstream osc.lua
- Smarter OSC elements show/hide logic
- Right-click seeks chapter closer to the clicked position
- Window controls respect Fitts's law ([mpv#9791])
- Volume bar follow `seekbar*_color`

### Bug fix

- Working deadzone implementation
- Fix timecode hitbox when milleseconds are shown (fixed in [583faf0])

</details>

[modern]: https://github.com/maoiscat/mpv-osc-modern
[modern#21]: https://github.com/maoiscat/mpv-osc-modern/issues/21
[ModernX#4]: https://github.com/cyl0/ModernX/pull/4
[mpv#9791]: https://github.com/mpv-player/mpv/issues/9791
[583faf0]: https://github.com/dexeonify/mpv-config/commit/583faf0

## References

- [mpv Wiki](https://github.com/mpv-player/mpv/wiki)
- [mpv Manual](https://mpv.io/manual/master)
- [Kokomins' mpv Configuration Guide for Watching Videos](https://kokomins.wordpress.com/2019/10/14/mpv-config-guide)
- [I Am Scum's Guide](https://iamscum.wordpress.com/guides/videoplayback-guide/mpv-conf)
- [Mathematically Evaluating mpv's Upscaling Algorithms](https://artoriuz.github.io/blog/mpv_upscaling.html)
