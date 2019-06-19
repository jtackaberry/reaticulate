# Reaticulate 0.3.1 bugfix release
June 19, 2019

This is a small bug fix release, mostly to fix a nontrivial regression introduced in 0.3.0.

Bug Fixes

* Fix bug where custom user banks would show up in the Factory submenu instead of the User submenu
* Fix bug where sometimes the GUI would not adjust after resizing its dimensions
* Allow long bank messages to wrap in the Track Settings screen



# Reaticulate 0.3.0 Released
June 17, 2019

This release of Reaticulate focuses on general usability improvements and
knocking down those little workflow irritations.  Apart from that, there are
quite a number of internal structural changes that you don't see, but will help
pave the way for future releases.

For those who installed Reaticulate via ReaPack, the updates should come
automatically in time, but you can force the update by accessing `Extensions |
ReaPack | Synchronize packages` from Reaper's menu.

After the update, you should restart Reaper to ensure the latest version of all
Reaticulate scripts are running.

## Full Change Log

These are the changes since 0.2.0.

### New Features
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


### Minor Enhancements
* Added a new "Behaviors" section on Settings page
* Activating an articulation now scrolls it into view in the GUI ([#50](https://github.com/jtackaberry/reaticulate/issues/50])
* Improved First Run experience (especially for portable Reaper installations) ([#46](https://github.com/jtackaberry/reaticulate/issues/46))
* Minor cosmetic improvements with drag-and-drop to reorder banks on the track configuration page

### Bug Fixes

* Fixed regression in control surface feedback when reopening a project
* Force control surface update on track selection (workaround for https://forum.cockos.com/showthread.php?p=2077098)
* Ensure articulations on same MIDI tick as notes are processed before the notes ([#53](https://github.com/jtackaberry/reaticulate/issues/53))
* Other minor fixes



# Reaticulate 0.2.0 Released
July 2, 2018

After a longer-than-expected development cycle, I'm happy to release the next alpha version of
Reaticulate.

I'm hoping the next major release will be beta worthy.  The main release criteria for beta is a GUI
editor for creating and modifying banks.


## Upgrade Instructions
<p class='warning'>
    Important note: this version requires reinstallation with a new ReaPack URL.
</p>

Unfortunately due to significant backward-incompatible changes in the ReaPack structure, upgrading
requires __uninstalling the old version__ and installing the new one.

I did warn you this was alpha software, right? :)

Follow these steps to uninstall the old version:

1. Close current project (if one is open)
1. Menu: `Extensions | ReaPack | Manage Repositories`
1. Right click Reaticulate and click Uninstall
1. Click ok and say yes to the prompt
1. Restart Reaper (necessary to stop existing Reaticulate instance)


And now follow the [installation instructions](download).

Reaticulate itself is fully backward compatible with the previous version, so all your existing
projects will work with the new version.  However, the old version is not _forward compatible_ with
this new version, so projects saved with Reaticulate 0.2.0 will not function properly in Reaticulate
0.1.0.

It's a good idea to save backups of your projects before resaving with Reaticulate 0.2.0
just in case you find yourself needing to downgrade to Reaticulate 0.1.0.

This will be generally true of all releases (i.e. backward compatible but not forward compatible).



## Release Highlights

### MIDI CC Feedback to Control Surface

If you do realtime performance of your MIDI CCs using a control surface that supports incoming
feedback, such as a MIDI Fighter Twister or iCON Platform-M, it's possible to have
Reaticulate-managed tracks sync their current CCs back to the control surface, either on track
select or during playback.

There are some new actions to control this behaviour, including to enable or disable it, or to
do a one-time dump of current CCs to the control surface.

See the [Usage page](usage#cc-feedback-to-control-surface) for more details.


![floating](img/trackcfg-dragndrop.png)
### Usability Enhancements

One of the most requested features was the ability to insert program change events in MIDI items
without the need to open the MIDI editor and enable step input.  This is now possible by __right
clicking__ an articulation in the list.

Banks in the track configuration page can now be reordered via drag and drop (depicted right)
rather than the cumbersome up/down buttons in the previous release.

The Settings Page now has an option to autostart Reaticulate when Reaper starts.  This works by
modifying Reaper's special `__startup.lua` script to invoke the `Reaticulate_Start` action.

There are a few other little odds and ends improving usability.  For example, if the Reaticulate UI
panel has focus and the spacebar is hit, it will toggle transport play/pause and move focus back to
the arrange view (or MIDI editor if it's open).  Unfortunately there's no way to solve this problem
in a general sense (passthrough keystrokes to the arrange window) but play/pause was the single biggest
workflow killer for me, so hopefully you find it helpful too.


### New Articulation Capabilities

All these new features described below are fully documented on the [Bank Files page](reabank).

#### Articulation Chaining
There's a new output event type `art` which allows articulations to be chained.  Consider the
following bank:

```go
//! c=long i=note-whole o=art:3/art:19/art:2
1 all-in-one long

//! c=long i=note-whole o=note:12
3 sustain
//! c=legato i=legato g=2 o=note:22,65
20 legato on
//! c=legato i=note-whole g=2 o=note:22,1
19 legato off
//! c=long-light i=con-sord g=3 o=note:23,65
7 con sordino
//! c=long-light i=note-whole g=3 o=note:23,1
2 senza sordino
```

This bank models a patch that has separate keyswitches for legato on/off and con sord on/off, which
are placed in different groups.  You can activate them independently, but the all-in-one long on
program 1 references the other articulations to provide a convenient, er, all-in-one articulation.

When you activate it, the GUI will automatically update to reflect the legato and sordino states.


#### CC Chasing Improvements

Previously, if Reaticulate observed _any_ CC then it would chase it.  This ended up doing
frustrating things, such as zeroing out CC 7 (volume) at unexpected times.

Now banks can specify which CCs should be chased.  The factory banks have been updated accordingly.
And now by default, unless a bank specifies a CC list, only CCs 1,2,11,64-69 will be chased.


#### Output Events Without Affecting Routing

Sometimes you just want an articulation to fire a MIDI event to a specific channel but not have future
non-articulation events get routed to that channel.

This is now possible by prefixing the output event type with a `-`.  For example:

```go
//! o=-note@13:42/note@10:20
```

The special `-` prefix in the first note output event tells Reaticlate _not_ to setup routing of
future events to channel 13.  Meanwhile, because the second note output event isn't so prefixed,
subsequent events will get sent to channel 10.


#### Conditional Output Events

It's now possible to have output events emit only if another articulation is active.  We call this a
_filter program_ and it requires that the filter program be activated in another group on the same
channel, otherwise the output event will be filtered (i.e. not emitted).

This allows articulations to be contextual based on articulations in other groups.

Filter programs are optional, and are specified by appending `[%program]` to the output event spec.

For example, consider a library such as Berlin Brass with its expansion packs, where trumpet
articulations can be performed unmuted, or with straight mutes, or with harmon mutes.  You _could_
have separate programs for each articulation with each type of mute -- and this is a perfectly
cromulent approach to be sure -- but it's now also possible to have a single program for each
articulation and the type of mute be defined in another group.

```go
//! c=long i=note-whole g=2
120 unmuted
//! c=long-light i=stopped g=2
121 straight mute
//! c=long-light i=stopped g=2
122 harmon mute

//! c=long i=note-whole o=note:24@1%120/note:24@2%121/note:24@3%122
1 long
//! c=short i=staccato o=note:27@1%120/note:27@2%121/note:27@3%122
40 staccato
//! c=short i=marcato-quarter o=note:28@1%120/note:28@2%121/note:28@3%122
52 marcato
```

So here we have the mute types in group 2, and the articulations in group 1.  This example describes
a multi, where the unmuted patch (the one that comes with the base Berlin Brass library) is on
channel 1, the straight mute variant is on channel 2, and the harmon mute variant on channel 3.

Here when activating the long articulation, only one of the output events will be emitted, depending
on the state of group 2.

If one of the mute types in group 2 is changed later, Reaticulate understands that it must retrigger
program 1 and emit the new note output event on the other channel, and redirect future MIDI events
to that channel.

The standard caveat of using multiple groups with Reaticulate applies: Reaper will only chase the
last program on each channel, so if you have a MIDI item with e.g. program 120 followed by program
1, and you manually activate program 121, when you begin playback again, depending on the playhead
position, program 120 may not be refired.

In spite of that limitation, this new ability to filter output events based the state of other
groups provides a lot of interesting capabilities.


### Additional Documentation

There is now the beginnings of a user manual on the [Usage page](usage).  It's a bit
information-dense right now but I intend to polish it up over time.



## Full Change Log
### New Features

- Added support for MIDI CC feedback to a control surface or other controller
- Articulation output events may refer to other articulations in the same bank via new 'art' output type (#18)
- Articulations can now be inserted from the arrange view (or MIDI editor without step input needing to be enabled) by right clicking the articulation button (#28)
- Banks can now specify which CCs should be chased.  Factory banks are much more selective about what's chased. (#33)
- Added support for conditional output events, where output events may now be optionally dependent on the state of articulations in other groups (#32)
- Output events to specific target MIDI channels can now be optionally configured to not affect future routing (#30)
- Added Settings UI to configure Reaticulate to autostart when Reaper starts

### Minor Enhancements
- Spacebar in Reaticulate's window will now toggle transport and focus arrange view
- Bank list in track configuration can now be reordered via drag-and-drop (#37)
- Ctrl-left/right now skips words in the articulation filter text input box (#9)
- Existing program changes at edit cursor will be removed before inserting a new one (#35)

### Bug fixes
- Fixed problem where UI may not use correct background color from theme
- Fixed parsing of invalid colors and icons (#13)
- Fixed "Add Reaticulate FX" button not working after first install (#15)
- Fixed ultra critical bug where trill-min2 and trill-maj2 icons were swapped (#16)
- Fixed routing issue when articulation had no output events defined (#27)
- For articulations with multiple note outputs, all note-ons will now be sent before any note-offs (#20)
- Articulations with multiple note-hold outputs now works as expected (#26)
- Fixed embarrasing bug where channel 16 couldn't be used for bank's source channel
- Reduced the likelihood of Reaticulate munging the last touched FX
- Other minor bug fixes

