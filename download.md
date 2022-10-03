---
title: Download | reaticulate
layout: default
permalink: /download/
---
# Prerequisites

* The [SWS extension](https://www.sws-extension.org/) is required to run Reaticulate
* It is *highly* recommended that you install the [js_ReaScriptAPI extension](https://forum.cockos.com/showthread.php?t=212174), which enables much improved focusing behavior and unlocks several of Reaticulate's features
  * If you have ReaPack installed, this extension can be installed via `Extensions | ReaPack | Browse Packages` and searching for `reascriptapi`

Be sure to restart Reaper after installing any extensions.

# Installation

## The Easy Way (ReaPack)

If your DAW is connected to the Internet, you can install Reaticulate as a ReaPack repository.

If you don't already have ReaPack, [head on over to reapack.com and install
it](https://reapack.com/).

Once you have ReaPack installed:
1. Open the menu: `Extensions | ReaPack | Import a Repository`
1. Paste in this URL: `https://reaticulate.com/index.xml`
1. Double click the newly added Reaticulate item in the repository list
1. Click the `Install/update Reaticulate` button and select `Install all packages`

Here's a screen capture that depicts the above steps:

![inline](../img/install.gif)

Now's a good time to read more about [how to launch and use Reaticulate](/usage).


### Living on the edge?

Pre-releases are made available from time to time and can give an earlier preview to new functionality
or fixes.  You can opt into the pre-release track by following these steps:
 1. From the menu, select `Extensions | ReaPack | Browse Packages`
 2. In the *Filter* box, search for `Reaticulate`
 3. Right-click on Reaticulate in the packages list and select `Enable pre-releases (bleeding edge)`

(This option requres ReaPack v1.2.4 or later.  ReaPack v1.2.4 was released on April 2, 2022.)

Your feedback with pre-releases is very much appreciated.  See the [contact page](/contact) for details on how to report issues.

<p class='warning'>
    Pre-releases are kept as stable as possible, unfortunately by virtue of having less testing time they are
    more likely to contain bugs.<br/><br/>
    You can always opt out of the pre-release track by repeating the above steps.  However be
    aware that downgrading major or minor versions is not supported, only patch-level versions
    may be downgraded.  For example, downgrading from 0.<b>6</b>.0-pre1 to 0.<b>5</b>.9 is not a
    supported downgrade path, while moving from 0.5.9-pre1 to 0.5.6, say, <i>is</i> supported.
</p>


## The Hard Way (Manual)

If your DAW doesn't have Internet connectivity, you can follow these manual installation
instructions:

1. Download the `Reaticulate-<version>.zip` file from [the latest release of Reaticulate](https://github.com/jtackaberry/reaticulate/releases/latest) and copy it to your DAW (via USB thumbdrive or whatever)
1. Open your REAPER resources directory by executing the REAPER action "Show REAPER resource path in Explorer/Finder"
   - On Windows, the default path is `%AppData%\REAPER\`
1. Extract the `Reaticulate` folder contained within the zip file to the `Scripts/` directory, so that `Scripts/Reaticulate/` is a folder.
   - If `Scripts/Reaticulate/` exists from a previous installation you can delete it (or move it out of the way)
1. Move the folder `Scripts/Reaticulate/jsfx` into the `Effects/` directory (which exists on the same level as `Scripts/`) and rename `jsfx` to `Reaticulate`.  Now you should have a `Effects/Reaticulate` folder that contains the `*.jsfx` files.
1. In Reaper, open the Actions dialog and click the `Load ...` button in the bottom right
1. Navigate to `Scripts/Reaticulate/actions/` and select all files in that directory, and then click the Open button
1. Invoke the action `Script: Reaticulate_Main.lua` from the actions list

# Updating

Access `Extensions | ReaPack | Synchronize packages` via Reaper's menu to ensure Reaticulate is updated
to the latest version.

If Reaticulate does update, you should restart Reaper to ensure the latest version of all
Reaticulate scripts are running.


# Download Bank Files

We're currently lacking a good way of sharing bank files, but for now, various user-contributed banks [have been curated on this GitHub page](https://github.com/jtackaberry/reaticulate/tree/master/userbanks).

Scroll down [that page](https://github.com/jtackaberry/reaticulate/tree/master/userbanks#user-submitted-reaticulate-banks) for installation instructions.

If you've made banks of your own that you'd like to contribute, please either [create an account on GitHub](https://github.com/join) and then [open a new issue](https://github.com/jtackaberry/reaticulate/issues) and attach (or paste) the bank, or, if you prefer, you can [email it to me](/contact).

# Uninstalling

Follow these steps to uninstall the Reaticulate ReaPack:

1. Close current project (if one is open)
1. Menu: `Extensions | ReaPack | Manage Repositories`
1. Right click Reaticulate and click Uninstall
1. Click ok and say yes to the prompt
1. Restart Reaper (necessary to stop existing Reaticulate instance)

