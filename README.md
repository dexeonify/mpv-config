# mpv-config

My personal [mpv](https://github.com/mpv-player/mpv/) config and user scripts :)

Nothing special, not even any fancy shaders or anything,
since I only have an integrated GPU.
This is mainly just for backup and keeping track of changes.

## Fonts

- [Cascadia Code](https://github.com/microsoft/cascadia-code) (OSC)
- [Manrope](https://github.com/sharanda/manrope) (Subtitles)

## User scripts

- [autosave.lua](https://gist.github.com/Hakkin/5489e511bd6c8068a0fc09304c9c5a82):
  Periodically saves "watch later" data during playback,
  rather than only saving on quit.

- [copyTime.lua](https://github.com/Arieleg/mpv-copyTime):
  Get the current time of the video and
  copy it to the clipboard with the format HH:MM:SS.MS.

  **Note:** I've added a feature to also copy the current frame count.

- [crop.lua](https://github.com/occivink/mpv-scripts#croplua):
  Crop the video by defining the target rectangle with the cursor.

- [toggle_osc.lua](https://www.reddit.com/r/mpv/comments/ib0bo9/comment/g1v12ku):
  Cycle the OSC between the three states: `auto`, `always` and `never`.

- [seek-to.lua](https://github.com/occivink/mpv-scripts#seek-tolua):
  Seek to an absolute timestamp specified via keyboard input.

  **Note:**
  I've modified [line 95](https://github.com/occivink/mpv-scripts/blob/master/scripts/seek-to.lua#L95)
  of this script to prevent the script from crashing
  if you backspace at the last position.
  Though it's more of a workaround, as I do not know Lua.
  As a result, you can't delete the last number using backspace,
  it has to be overwritten by pressing '0' manually.

- [Thumbnailer.lua](https://github.com/deus0ww/mpv-conf):
  A more streamlined thumbnailer than [mpv_thumbnail_script](https://github.com/TheAMM/mpv_thumbnail_script),
  also comes with additional features.

## References

- [Kokomins's mpv Configuration Guide for Watching Videos](https://kokomins.wordpress.com/2019/10/14/mpv-config-guide/)
- [Tsubajashi/mpv-settings](https://github.com/Tsubajashi/mpv-settings/)

If you are interested in high quality scaling:

- <https://artoriuz.github.io/blog/mpv_upscaling.html>
- <https://github.com/mpv-player/mpv/wiki/Upscaling>
