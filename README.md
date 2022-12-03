# mpv-config

My personal [mpv](https://github.com/mpv-player/mpv) config and user scripts :)

Nothing special, not even any fancy shaders or anything, since I only have an
integrated GPU. This is mainly just for backup and keeping track of changes.

## Fonts

- [Open Sans](https://fonts.google.com/specimen/Open+Sans) (OSC)
- [Manrope](https://github.com/sharanda/manrope) (Subtitles)
- [Cascadia Code](https://github.com/microsoft/cascadia-code) (Console)

⚠️ **Important:**
Install my custom-made icon font [modernx-osc-icon.ttf](https://github.com/dexeonify/mpv-config/raw/main/fonts/modernx-osc-icon.ttf)
for the OSC icons.

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
  of deus0ww's Thumbnailer.lua (see below) and upstream fixes ported from from
  mpv's [osc.lua](https://github.com/mpv-player/mpv/blob/master/player/lua/osc.lua).

  **Note:** For a version that supports mpv_thumbnail_script, you can check out
  ThomasEricB's fork [Mpv.Net-HQ-Config](https://github.com/ThomasEricB/Mpv.Net-HQ-Config).

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

**Note:** Some of the scripts have been modified to suit my needs. You can see
the exact changes by looking at the commit history for each individual script.

## References

- [mpv Wiki](https://github.com/mpv-player/mpv/wiki)
- [mpv Manual](https://mpv.io/manual/master)
- [Kokomins' mpv Configuration Guide for Watching Videos](https://kokomins.wordpress.com/2019/10/14/mpv-config-guide)
- [I Am Scum's Guide](https://iamscum.wordpress.com/guides/videoplayback-guide/mpv-conf)
- [Mathematically Evaluating mpv's Upscaling Algorithms](https://artoriuz.github.io/blog/mpv_upscaling.html)
