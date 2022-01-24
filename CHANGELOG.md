# 0.5.0-pre1

**PRERELEASE WARNING**: Reaticulate is not and has never been forward compatible with future versions. There is a strong *backward* compatibility goal, but not forward compatibility.  So if you're using Reaticulate 0.4.x now and upgrade to 0.5.0-pre1, any projects saved out by this new version will not be able to be reopened using previous Reaticulate versions.

Note: Reaper 5.975 (released on April 30, 2019) or later is now required.

Here are the changes since the last stable release (0.4.7):
## New Features

* MSB/LSB bank values are now entirely assigned and managed by Reaticulate.  Users no longer need to worry about this annoying technical detail, and can simply put `*` as placeholders for both MSB and LSB values in bank definitions. ([#63](https://github.com/jtackaberry/reaticulate/issues/63))
* Pre-created banks (such as those [contributed by other users](https://github.com/jtackaberry/reaticulate/tree/master/userbanks)) can now be much more conveniently imported into Reaticulate, either from clipboard (`[Pencil Icon] | Import Banks from Clipboard`) or by dragging-and-dropping one or more files onto Reaticulate's window. Users no longer need to edit the Reabank file in a text editor just to import existing banks. Nor, thanks to dynamic and automatic MSB/LSB assignment, do users need to worry about adjusting MSB/LSB of third party banks to avoid conflicts.
* Reaticulate now fully supports Retina/Hi-DPI displays with UI scaling and high-DPI graphics. The UI scale automatically respects the system-wide DPI but can be adjusted in Reaticulate's settings.
* Default MIDI channel can be remembered globally, per track, or per item, and is more robustly synced with the MIDI editor ([#83](https://github.com/jtackaberry/reaticulate/issues/83))
* Changes to the default MIDI channel are now fed back to the control surface, if configured. See Reaticulate's Usage documentation for more information.
* Holding alt while clicking an articulation button in any manner that inserts the articulation (i.e. double clicking, long-pressing, or right-clicking) will always insert at the edit cursor, even when notes are selected in the MIDI editor. ([#79](https://github.com/jtackaberry/reaticulate/issues/79))
* Articulation definitions in banks now respect the `m` (message) attribute, which displays the message as a tooltip when hovering over the articulation ([#67](https://github.com/jtackaberry/reaticulate/issues/67))
* Touch scrolling can now be enabled, in addition to smooth scrolling, which significantly improves the experience on touch-capable devices ([#56](https://github.com/jtackaberry/reaticulate/issues/56))
* Default articulation colors are now configurable in Reaticulate's settings page
* A new experimental option has been added to maintain a single floating FX window for instrument FX (such as VSTi) as different tracks are selected
* A default list of CCs for chasing (when not explicitly defined in the bank itself) is now configurable in Reaticulate's settings page ([#146](https://github.com/jtackaberry/reaticulate/issues/146))
* Articulations will now be inserted on all selected Reaticulate-enabled tracks. If the banks are different between tracks, then the first bank on the track that defines an articulation with the same program number is used.
* Inserting articulations on selected tracks will create a new MIDI item under the edit cursor if there isn't currently one
* Two new "tweak" functions have been added to Reaticulate's track configuration page:
  1. Repair tracks where the user manually assigned a custom ReaBank resulting in articulations to appear as numeric values (e.g. 70-2-17).
  2. Clear all articulation assignments for the track in the GUI, to provide a more discoverable solution to the problem of an inadvertently activated articulation on the wrong channel. (You were always able to middle-click articulation buttons in the main screen to reset the assignment, but this wasn't discoverable.)

## Minor Enhancements

* "Track selection follows MIDI editor" is now enabled by default for new installations
* Display a warning when the selected track doesn't match focused item in MIDI editor (a common gotcha)
* Articulations can be inserted into a MIDI item when using the articulation filter either by pressing shift-enter or the insert key.
* Articulation buttons will now layout in multiple columns when space permits
* When an articulation is inserted by clicking on the articulation's button, it will flash to indicate the insertion
* All articulation icons have been redone with vector graphics in order to support high-DPI displays
* The articulation list's scroll position is now retained per track and restored when the track is selected
* All buttons in the GUI got a minor facelift
## Bug Fixes

* Fixed a bug where CCs were not always properly chased when activating articulations between different channels
* Properly refocus the previous window when using the "Focus articulation filter" action after activating an articulation (enter) or clearing the filter (escape).  (Requires js_ReaScriptAPI to be present.)
* Fixed a bug where control surface feedback send would not be setup when the Reaticulate JSFX was initially installed on a track
* Fixed an issue where existing Program Change events would sometimes not be deleted when replacing articulations
* Improved robustness when starting with invalid or malformed saved configuration

# 0.4.7 - March 12, 2021

## Bug Fixes

* Fixed bug where window pinned state was not preserved between restarts


# 0.4.6 - November 7, 2020

## Bug Fixes

* Fixed regression where articulations with multiple note output events would fail to send all note-ons together before sending note-off events.
* Reaticulate JSFX no longer popup when being added to tracks ([#120](https://github.com/jtackaberry/reaticulate/issues/120))
* Improved robustness when loading malformed banks
* Added hidden feature for shift-click on the reload toolbar icon to scrub all MIDI items for misconfiguration that might prevent showing articulation names.
* Fixed problem where autostart setting would not work reliably ([#107](https://github.com/jtackaberry/reaticulate/issues/107))
* Improved reliability of window pinning when Reaticulate is undocked
* Added note number to articulation tooltip ([#96](https://github.com/jtackaberry/reaticulate/issues/96))
* Now respects Reaper's MIDI octave name display offset configuration when displaying articulation tooltips


# 0.4.5 - March 21, 2020

## Bug Fixes

* Fixed bug with note-hold keyswitch retriggering incorrectly on transport start


# 0.4.4 - December 14, 2019

## Bug Fixes

* Fixed a bug where detecting manual articulation activation by output event (manual keyswitch or CC) would fail to take into account current destination channel/bus routing and improperly reflect an articulation change in the GUI


# 0.4.3 - November 17, 2019

## Bug Fixes

* Fixed a crasher on OSX when "Track selection follows FX focus" is enabled
* Fixed bug where duplicating tracks containing the Reaticulate JSFX may not reflect the same bank assignments
* Fixed an issue loading projects or importing track templates saved with older versions of Reaticulate where changes made to banks would not be automatically synced to the track


# 0.4.2 - November 8, 2019

## Bug Fixes

* Fixed inserting articulations when the edit cursor is at the boundary between two MIDI items
* Fixed a regression with the track configuration screen where it failed to properly reflect additions or removals of banks when the Refresh toolbar button was pressed



# 0.4.1 - November 4, 2019

## Bug Fixes

* Fixed a bug with the inline MIDI editor when the option to insert articulations at selected notes was enabled
* Fixed a related bug where articulations would fail to insert at the edit cursor if the active item in the MIDI editor was different than the one under the edit cursor
* When "Track selection follows MIDI editor target item" is enabled, don't vertically scroll the arrange view to show the track as that behavior ends up being particularly obnoxious



# 0.4.0 - November 2, 2019

**Note:** Reaper 5.97 (released on February 21, 2019) or later is now required.


These are the changes since the last stable release (0.3.2):


## New Features

* This release introduces support for multiple MIDI buses.  Anywhere previously involving a destination MIDI channel can now optionally include a MIDI bus number as well.  Among other things, this allows for better integration with Vienna Ensemble Pro. ([#73](https://github.com/jtackaberry/reaticulate/issues/73))
* Articulation insertion now respects selected notes when the MIDI editor is open.  Program changes will be inserted intelligently based on the nature of the selection.
* Articulations can now define transformations to incoming notes after the articulation is activated.  These include transposing the notes, a velocity multiplier, and pitch and velocity range clamping. ([#72](https://github.com/jtackaberry/reaticulate/issues/72))
* Output events can now be routed to destination channels set up by the previous articulation by using `-` as the channel ([#42](https://github.com/jtackaberry/reaticulate/issues/42))
* Output events can now send pitch bend MIDI messages ([#60](https://github.com/jtackaberry/reaticulate/issues/60))
* Double clicking an articulation or invoking any of the "activate articulation" actions twice within 500ms will force-insert the articulation in the MIDI item.  (This is equivalent to right clicking, which behavior still exists.)
   - The old behavior of always inserting when step record is enabled has been removed in favor of this consistent approach.
* Much better support for light themes ([#6](https://github.com/jtackaberry/reaticulate/issues/6))
* Added option for undocked windows to be borderless (requires a fairly recent version of the js_ReaScript_API extension)
* Allow user-configurable background color (in Settings page) ([#78](https://github.com/jtackaberry/reaticulate/issues/78))


## Minor Enhancements

* Added a new 'spacer' articulation attribute which adds visual padding above the articulation when shown in Reaticulate's UI ([#66](https://github.com/jtackaberry/reaticulate/issues/66))
* Bank messages (set with the 'm' attribute in the bank definition) can now be viewed from Reaticulate's main articulation list screen ([#68](https://github.com/jtackaberry/reaticulate/issues/68))
* Improved text entry widget behavior with text selection, copy/paste, etc.
* Errors and other problems with banks or track configuration are now more visible in the articulation list screen
* Linux: preliminary support
* Added tremolo-180-con-sord icon
* Many other small GUI refinements, especially on Mac



## Bug Fixes

* Fixed problem where insertion of articulations could not be undone by Reaper's undo action ([#47](https://github.com/jtackaberry/reaticulate/issues/47))
* Fixed bug where 'art' type output events combined with filter programs could hang Reaper (infinite loop) ([#44](https://github.com/jtackaberry/reaticulate/issues/44))
* Fixed bug where activating an articulation that acts as a filter to another articulation's 'art' output events could activate the wrong child program
* Fixed bug when MIDI controller feedback was enabled where Reaticulate would sometimes install sends to the wrong track when a new project was opened
* Avoid reloading all other track FX when Reaticulate is installed on a track ([#1](https://github.com/jtackaberry/reaticulate/issues/1))
* Mac: use the Reaper theme background color for Reaticulate's window
* Fixed bug when opening the Reabank file editor on Windows when the path contained spaces
* Fixed rare crash when last touch fx becomes invalid
* Factory banks: Fixed trills and tongued legato for the Herring Clarinet
* Do not clear serialized variables in @init per JSFX docs ([#65](https://github.com/jtackaberry/reaticulate/issues/65))




# 0.3.93 - October 29, 2019

These are the changes since the last prerelease (0.3.92):

# Minor Enhancements

* More intelligent articulation insertion logic when notes are selected.  Program changes will now be inserted at gaps in the selection, and the channel of the note will be used for the program change rather than the default channel.
* Delay refocusing the MIDI editor (if open) when double clicking articulations to reduce window focus flicker


## Bug Fixes

* Fix minor text cropping bug when the window is a certain width




# 0.3.92 - October 26, 2019

These are the changes since the last prerelease (0.3.91):

## New Features

* Add option for undocked windows to be borderless (requires a fairly recent version of the js_ReaScript_API extension)
* When the MIDI editor is open and notes are selected, articulations will insert just ahead of the first selected note rather than at the edit cursor
* Much better support for light themes



## Minor Enhancements

* Minor cosmetic enhancements, especially on Mac


## Bug Fixes

* Fix regression from 0.3.90 where output events may not be sent to the proper channel. (The fix for this in 0.3.91 was incomplete.)



# 0.3.91 - October 23, 2019

These are the changes since the last prerelease (0.3.90):

## New Features

* Allow user-configurable background color (in Settings page)


## Minor Enhancements

* Improved text entry widget behavior
* Add bus number to output event description in status bar
* Clean up after deleted/deactivated Reaticulate JSFX instances ([#77](https://github.com/jtackaberry/reaticulate/issues/77))
* Minor robustness improvements

## Bug Fixes

* Fix regression from 0.3.90 where output events' destination channels would be ignored
* Fix unreadable status bar text on light themes



# 0.3.90 - October 14, 2019

## Overview

Although this release contains several new features and fixes, the bulk of the work has been toward a significant internal design overhaul of how the main app communicates with the per-track Reaticulate JSFX instances ([#62](https://github.com/jtackaberry/reaticulate/issues/62)), plus improved flexibility of how articulation and output event options are processed by the JSFX.

These changes pave the way for more sophisticated features than were previously possible (some of which are included in this release), but despite my best efforts in testing, the sheer volume and complexity of these changes means regressions are probable.

Your help testing this pre-release is very much appreciated.  Do **backup your projects first** as those saved with this version will be incompatible with older Reaticulate versions.  (This is generally true of major releases.)

Note: Reaper 5.97 (released on February 21, 2019) or later is now required.


## New Features

* This release introduces support for multiple MIDI buses.  Anywhere previously involving a destination MIDI channel can now optionally include a MIDI bus number as well.  Among other things, this allows for better integration with Vienna Ensemble Pro. ([#73](https://github.com/jtackaberry/reaticulate/issues/73))
* Articulations can now define transformations to incoming notes after the articulation is activated.  These include transposing the notes, a velocity multiplier, and pitch and velocity range clamping. ([#72](https://github.com/jtackaberry/reaticulate/issues/72))
* Output events can now be routed to destination channels set up by the previous articulation by using `-` as the channel ([#42](https://github.com/jtackaberry/reaticulate/issues/42))
* Output events can now send pitch bend MIDI messages ([#60](https://github.com/jtackaberry/reaticulate/issues/60))
* Double clicking an articulation or invoking any of the activate articulation actions twice within 500ms will force insert the articulation in the MIDI item at the edit cursor.  (This is equivalent to right clicking, which behavior still exists.)
   - The old behavior of always inserting when step record is enabled has been removed in favor of this consistent approach.


Documentation on the website (https://reaticulate.com) has been updated to reflect these new features.



## Minor Enhancements

* Bank messages (set with the 'm' attribute in the bank definition) can now be viewed from Reaticulate's main articulation list screen
* Errors and other problems with banks or track configuration are now more visible in the articulation list screen
* Linux: preliminary support
* Added tremolo-180-con-sord icon
* Many other small GUI refinements



## Bug Fixes

* Fixed problem where insertion of articulations could not be undone by Reaper's undo action
* Fixed bug where 'art' type output events combined with filter programs could hang Reaper (infinite loop)
* Fixed bug where activating an articulation that acts as a filter to another articulation's 'art' output events could activate the wrong child program
* Fixed bug when MIDI controller feedback was enabled where Reaticulate would sometimes install sends to the wrong track when a new project was opened
* Mac: use the Reaper theme background color for Reaticulate's window
* Fixed bug when opening the Reabank file editor on Windows when the path contained spaces
* Fixed rare crash when last touch fx becomes invalid
* Factory banks: Fixed trills and tongued legato for the Herring Clarinet
* Do not clear serialized variables in @init per JSFX docs ([#65](https://github.com/jtackaberry/reaticulate/issues/65))



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

