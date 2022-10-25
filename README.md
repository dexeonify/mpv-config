# mpv-config

My personal [mpv](https://github.com/mpv-player/mpv) config and user scripts :)

Nothing special, not even any fancy shaders or anything, since I only have an
integrated GPU. This is mainly just for backup and keeping track of changes.

> **Note** \
> This branch is the one I'm locally using (and developing moving forward),
> taking advantage of the superb uosc! However, I will still continue to
> maintain modernx (in the [main](https://github.com/dexeonify/mpv-config/tree/main)
> branch) - in terms of upstream fixes.

## Fonts

- [Open Sans](https://fonts.google.com/specimen/Open+Sans) (OSC)
- [Manrope](https://github.com/sharanda/manrope) (Subtitles)
- [Cascadia Code](https://github.com/microsoft/cascadia-code) (Console)

## User scripts

- **[uosc.lua](https://github.com/tomasklaen/uosc):**
  A feature-rich minimalist proximity-based UI for mpv. Completed with fully
  customizable controls bar and menu, UI for file browser and playlist,
  as well as integration with various scripts.

- **[thumbfast.lua](https://github.com/po5/thumbfast):**
  High-performance on-the-fly thumbnailer for mpv. The latest and greatest
  thumbnail engine rivalling both [mpv_thumbnail_script](https://github.com/marzzzello/mpv_thumbnail_script)
  and [Thumbnailer](https://github.com/deus0ww/mpv-conf/blob/master/scripts/Thumbnailer.lua).

- **[file-browser.lua](https://github.com/CogentRedTester/mpv-file-browser):**
  Navigate through the file system entirely from within mpv and open/append
  files & folders.

- **[playlistmanager.lua](https://github.com/jonniek/mpv-playlistmanager):**
  Create and manage playlists intuitively. Use [playlistmanager-save-interactive.lua](https://github.com/jonniek/mpv-playlistmanager/blob/master/playlistmanager-save-interactive.lua)
  to manually name playlists on save.

- **[SmartCopyPaste.lua](https://github.com/Eisa01/mpv-scripts#smartcopypaste):**
  Add the capability to copy and paste while being smart and customizable.

- **[quality-menu.lua](https://github.com/christoph-heinrich/mpv-quality-menu):**
  Add a menu for changing the streamed video and audio quality on the fly.

- **[crop.lua](https://github.com/occivink/mpv-scripts#croplua):**
  Crop the video by defining the target rectangle with the cursor.

- **[seek-to.lua](https://github.com/occivink/mpv-scripts#seek-tolua):**
  Seek to an absolute timestamp specified via keyboard input or
  pasted from clipboard.

> **Note** \
> Some of the scripts have been modified to suit my needs. You can see the
> exact changes by looking at the commit history for each individual script.

## References

- [mpv Wiki](https://github.com/mpv-player/mpv/wiki)
- [mpv Manual](https://mpv.io/manual/master)
- [Kokomins' mpv Configuration Guide for Watching Videos](https://kokomins.wordpress.com/2019/10/14/mpv-config-guide)
- [I Am Scum's Guide](https://iamscum.wordpress.com/guides/videoplayback-guide/mpv-conf)
- [Mathematically Evaluating mpv's Upscaling Algorithms](https://artoriuz.github.io/blog/mpv_upscaling.html)
