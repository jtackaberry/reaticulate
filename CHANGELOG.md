# 0.3.2 - August 3, 2019

This is release fixes a regression introduced in 0.3.0.

## Bug Fixes

* Fix articulation activations during live recording


# 0.3.1 - June 19, 2019

This is a small bug fix release.

## Bug Fixes

* Fix bug where custom user banks would show up in the Factory submenu instead of the User submenu
* Fix bug where sometimes the GUI would not adjust after resizing its dimensions
* Allow long bank messages to wrap in the Track Settings screen


# 0.3.0 - June 17, 2019

Below is a list of changes since 0.2.0.

## New Features
* Articulations are now fed back to control surface ([#48](https://github.com/jtackaberry/reaticulate/issues/48))
   * CC0/32 bank select indicates bank for articulation
   * Articulations can be expressed either as native program change events or custom CC events
* When the [js_ReaScriptAPI extension](https://forum.cockos.com/showthread.php?t=212174) is installed (**strongly recommended!**):
   * You can now pin the Reaticulate window when floating
   * Some new actions and features become available
   * Much improved focusing behavior
* New action "Focus articulation filter" (which works best when the js_ReaScriptAPI extension is installed)
* New action "Activate articulation slot number by CC on default channel" which can be used to activate articulations based on their position in the bank list ([#58](https://github.com/jtackaberry/reaticulate/issues/58))
* New action "Insert last activated articulation into MIDI item on default channel" to insert the last activated articulation into MIDI item at edit cursor (same behavior as right clicking the articulation)
* New option "Track section follows focused FX window" (with associated toggle action) (requires js_ReaScriptAPI extension)
* New option "Track selection follows MIDI editor target item" (with associated toggle action)
   * This is most conveniently paired with the "Options: MIDI track list/media item lane selection is linked to editability"
* New action "Select last selected track"
* Various new actions to select but not activate articulations, plus an action to activate currently selected articulation ([#59](https://github.com/jtackaberry/reaticulate/issues/59))
  * Running the action to activate currently selected articulation twice in rapid succession will cause it to insert into MIDI item
* On pages that scroll, scrollbars will appear when the mouse hovers toward the right edge


## Minor Enhancements
* Added a new "Behaviors" section on Settings page
* Activating an articulation now scrolls it into view in the GUI ([#50](https://github.com/jtackaberry/reaticulate/issues/50))
* Improved First Run experience (especially for portable Reaper installations) ([#46](https://github.com/jtackaberry/reaticulate/issues/46))
* Minor cosmetic improvements with drag-and-drop to reorder banks on the track configuration page

## Bug Fixes

* Fixed regression in control surface feedback when reopening a project
* Force control surface update on track selection (workaround for https://forum.cockos.com/showthread.php?p=2077098)
* Ensure articulations on same MIDI tick as notes are processed before the notes ([#53](https://github.com/jtackaberry/reaticulate/issues/53))
* Other minor fixes


# 0.2.93 (prerelease) - June 9, 2019

## New Features

+ New action: Track selection follows FX focus
    * When enabled, focusing an FX window will cause the FX's track
      to become selected.
    * This action requires the js_ReaScriptAPI extension
+ New action: Select last selected track
+ Added a "Behavior" section to the Settings page to control certain
  behaviors (mainly related to recently added actions)


# 0.2.92 (prerelease) - June 8, 2019

## New Features

+ New action: Toggle track selection follows MIDI editor target item
    * This action is useful when changing tracks via the MIDI Editor
      track list.  It will select the track in the TCP, which causes
      Reaticulate to show the articulation list for that track.
    * This is most conveniently paired with the "Options: MIDI track
      list/media item lane selection is linked to editability"

## Bug Fixes

- Improved bidirectional sync between the MIDI Editor's default channel
  and Reaticulate's default channel.


# 0.2.91 (prerelease) - March 14, 2019

## New Features

+ When the js_ReaScriptAPI extension is installed (recommended):
    * You can now pin the Reaticulate window when floating
    * Much improved focusing behavior
+ New action "Focus articulation filter" (which works best when the
  js_ReaScriptAP extension is installed)
+ New action "Activate articulation slot number by CC on default channel"
  which can be used to activate articulations based on their position in
  the bank list ([#58](https://github.com/jtackaberry/reaticulate/issues/58))
+ New action to insert the last activated articulation into MIDI item at
  edit cursor (same behavior as right clicking the articulation)
+ Various new actions to select but not activate articulations, plus an
  action to activate currently selected articulation ([#59](https://github.com/jtackaberry/reaticulate/issues/59))
    * Running the action to activate currently selected articulation
      twice in rapid succession will cause it to insert into MIDI item
+ On pages that scroll, scrollbars will appear when the mouse hovers toward
  the right edge


## Bug Fixes

- Fixed regression in control surface feedback when reopening a project
- Force control surface update on track selection (workaround for 
  https://forum.cockos.com/showthread.php?p=2077098)



# 0.2.90 (prerelease) - December 21, 2018

## New Features

+ Activating an articulation now scrolls it into view in the GUI ([#50](https://github.com/jtackaberry/reaticulate/issues/50))
+ Articulations are now fed back to control surface ([#48](https://github.com/jtackaberry/reaticulate/issues/48))
    * CC0/32 bank select indicates bank for articulation
    * Articulations can be expressed either as native program change events or
      custom CC events
+ Improve First Run experience (especially for portable Reaper installations) ([#46](https://github.com/jtackaberry/reaticulate/issues/46))
+ Minor cosmetic improvements with drag-and-drop to reorder banks on the track
  configuration page

## Bug Fixes

- Ensure articulations on same MIDI tick as notes are processed before the notes ([#53](https://github.com/jtackaberry/reaticulate/issues/53))


# 0.2.0 - July 2, 2018
## New Features

- Added support for MIDI CC feedback to a control surface or other controller
- Articulation output events may refer to other articulations in the same bank via new 'art' output type ([#18](https://github.com/jtackaberry/reaticulate/issues/18))
- Articulations can now be inserted from the arrange view (or MIDI editor without step input needing to be enabled) by right clicking the articulation button ([#28](https://github.com/jtackaberry/reaticulate/issues/28))
- Banks can now specify which CCs should be chased.  Factory banks are much more selective about what's chased. ([#33](https://github.com/jtackaberry/reaticulate/issues/33))
- Added support for conditional output events, where output events may now be optionally dependent on the state of articulations in other groups ([#32](https://github.com/jtackaberry/reaticulate/issues/32))
- Output events to specific target MIDI channels can now be optionally configured to not affect future routing ([#30](https://github.com/jtackaberry/reaticulate/issues/30))
- Added Settings UI to configure Reaticulate to autostart when Reaper starts

## Minor Enhancements
- Spacebar in Reaticulate's window will now toggle transport and focus arrange view
- Bank list in track configuration can now be reordered via drag-and-drop ([#37](https://github.com/jtackaberry/reaticulate/issues/37))
- Ctrl-left/right now skips words in the articulation filter text input box ([#9](https://github.com/jtackaberry/reaticulate/issues/9))
- Existing program changes at edit cursor will be removed before inserting a new one ([#35](https://github.com/jtackaberry/reaticulate/issues/35))

## Bug fixes
- Fixed problem where UI may not use correct background color from theme
- Fixed parsing of invalid colors and icons ([#13](https://github.com/jtackaberry/reaticulate/issues/13))
- Fixed "Add Reaticulate FX" button not working after first install ([#15](https://github.com/jtackaberry/reaticulate/issues/15))
- Fixed ultra critical bug where trill-min2 and trill-maj2 icons were swapped ([#16](https://github.com/jtackaberry/reaticulate/issues/16))
- Fixed routing issue when articulation had no output events defined ([#27](https://github.com/jtackaberry/reaticulate/issues/27))
- For articulations with multiple note outputs, all note-ons will now be sent before any note-offs ([#20](https://github.com/jtackaberry/reaticulate/issues/20))
- Articulations with multiple note-hold outputs now works as expected ([#26](https://github.com/jtackaberry/reaticulate/issues/26))
- Fixed embarrasing bug where channel 16 couldn't be used for bank's source channel
- Reduced the likelihood of Reaticulate munging the last touched FX
- Other minor bug fixes

