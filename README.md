# mpv-config

My personal [mpv](https://github.com/mpv-player/mpv) config and user scripts :)

This config is tailored to my workflow, rather than serving as another
reference in a sea of *high-quality* configs. Also, this repo is mostly for
backup and keeping track of changes.

> [!NOTE]
> This is the branch that I'm currently using (and developing) locally,
> utilizing the superb uosc! As a result, the development on my fork of ModernX
> will grind to a halt. I *may* try to sync some minor changes and bug fixes
> from upstream every now and then.

## Fonts

- [Manrope](https://github.com/sharanda/manrope) (OSC, Subtitle, Stats)
  - A modified version of Manrope (with Tabular Number enabled) is used for the
    OSC and Stats window, which can be downloaded [here](https://github.com/dexeonify/mpv-config/tree/uosc/fonts).
- [Cascadia Code](https://github.com/microsoft/cascadia-code) (Console)

## User scripts

- **[uosc.lua](https://github.com/tomasklaen/uosc):**
  A feature-rich minimalist proximity-based UI for mpv. Complete with fully
  customisable controls bar and menu, UI for file browser and playlist,
  as well as scripts integration that acts as extensions to the UI.

- **[thumbfast.lua](https://github.com/po5/thumbfast):**
  A high-performance and state-of-the-art thumbnailer engine for mpv, rivalling
  both [mpv_thumbnail_script](https://github.com/marzzzello/mpv_thumbnail_script)
  and [Thumbnailer](https://github.com/deus0ww/mpv-conf/blob/master/scripts/Thumbnailer.lua).

- **[skipsilence.lua](https://github.com/ferreum/mpv-skipsilence):**
  Increase playback speed during quiet parts of a file.
  Similar to the "Fast-forward during silence" feature of the NewPipe app.

- **[file-browser.lua](https://github.com/CogentRedTester/mpv-file-browser):**
  Navigate through the file system entirely from within mpv, as well as
  opening and appending files & folders.

- **[playlistmanager.lua](https://github.com/jonniek/mpv-playlistmanager):**
  Create and manage playlists intuitively. Use [playlistmanager-save-interactive.lua](https://github.com/jonniek/mpv-playlistmanager/blob/master/playlistmanager-save-interactive.lua)
  to manually name playlists on save.

- **[SmartCopyPaste.lua](https://github.com/Eisa01/mpv-scripts#smartcopypaste):**
  Add the capability to copy and paste while being smart and customizable.

- **[quality-menu.lua](https://github.com/christoph-heinrich/mpv-quality-menu):**
  Add a menu for changing the streamed video and audio quality on the fly.

- **[memo.lua](https://github.com/po5/memo):**
  A recent files menu for mpv. Saves your watch history and displays it
  in a nice menu.

- **[crop.lua](https://github.com/occivink/mpv-scripts#croplua):**
  Crop the video by defining the target rectangle with the cursor.

- **[seek-to.lua](https://github.com/occivink/mpv-scripts#seek-tolua):**
  Seek to an absolute timestamp specified via keyboard input or
  pasted from clipboard.

> [!IMPORTANT]
> Some of the scripts have been modified to suit my needs. You can see the
> exact changes by viewing the commit history of each individual script.

## References

- [mpv Wiki](https://github.com/mpv-player/mpv/wiki)
- [mpv Manual](https://mpv.io/manual/master)
- [Kokomins' mpv Configuration Guide for Watching Videos](https://kokomins.wordpress.com/2019/10/14/mpv-config-guide)
- [I Am Scum's Guide](https://iamscum.wordpress.com/guides/videoplayback-guide/mpv-conf)
- [Mathematically Evaluating mpv's Upscaling Algorithms](https://artoriuz.github.io/blog/mpv_upscaling.html)
