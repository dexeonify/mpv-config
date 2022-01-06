# mpv-config

My personal [mpv](https://github.com/mpv-player/mpv) config and user scripts :)

Nothing special, not even any fancy shaders or anything, since I only have an
integrated GPU. This is mainly just for backup and keeping track of changes.

## Fonts

- [Cascadia Code](https://github.com/microsoft/cascadia-code) (OSC)
- [Open Sans](https://fonts.google.com/specimen/Open+Sans) (Title)
- [Manrope](https://github.com/sharanda/manrope) (Subtitles)

⚠️ Note:
Install my custom-made [icon font](https://github.com/dexeonify/mpv-config/blob/main/modernx-osc-icon.ttf)
for the OSC icons.

## User scripts

- [autosave.lua](https://gist.github.com/CyberShadow/2f71a97fb85ed42146f6d9f522bc34ef):
  Periodically saves "watch later" data during playback, rather than only
  saving on quit.

- [copyTime.lua](https://github.com/Arieleg/mpv-copyTime):
  Get the current time of the video and copy it to the clipboard with the
  format HH:MM:SS.MS.

- [crop.lua](https://github.com/occivink/mpv-scripts#croplua):
  Crop the video by defining the target rectangle with the cursor.

- [modernx.lua](https://github.com/dexeonify/mpv-config/blob/main/scripts/modernx.lua):
  Another fork of [mpv-osc-morden-x](https://github.com/cyl0/mpv-osc-morden-x),
  with added support of deus0ww's `Thumbnailer.lua` (see below) and upstream
  fixes ported from from mpv's [osc.lua](https://github.com/mpv-player/mpv/blob/master/player/lua/osc.lua).

  **Note:**
  If you want a version with `mpv_thumbnail_script`, you can check out
  ThomasEricB's fork [MpvNet-HQ-Config](https://github.com/ThomasEricB/MpvNet-HQ-Config).

- [playlistmanager.lua](https://github.com/jonniek/mpv-playlistmanager):
  Create and manage playlists intuitively.

- [seek-to.lua](https://github.com/occivink/mpv-scripts#seek-tolua):
  Seek to an absolute timestamp specified via keyboard input or pasted from clipboard.

- [Thumbnailer.lua](https://github.com/deus0ww/mpv-conf):
  A more streamlined thumbnailer than [mpv_thumbnail_script](https://github.com/TheAMM/mpv_thumbnail_script),
  also comes with additional features.

- [toggle_osc.lua](https://www.reddit.com/r/mpv/comments/ib0bo9/comment/g1v12ku):
  Quickly hide, show or peek the OSC.

## References

- [Kokomins's mpv Configuration Guide for Watching Videos](https://kokomins.wordpress.com/2019/10/14/mpv-config-guide/)
- [I Am Scum's Guide](https://iamscum.wordpress.com/guides/videoplayback-guide/mpv-conf/)
- [Tsubajashi/mpv-settings](https://github.com/Tsubajashi/mpv-settings/)
- [ThomasEricB/MpvNet-HQ-Config](https://github.com/ThomasEricB/MpvNet-HQ-Config)

If you are interested in high quality scaling:

- <https://artoriuz.github.io/blog/mpv_upscaling.html>
- <https://github.com/mpv-player/mpv/wiki/Upscaling>
