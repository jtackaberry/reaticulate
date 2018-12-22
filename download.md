---
title: Download
---

## The Easy Way (ReaPack)

If your DAW is connected to the Internet, you can install Reaticulate as a ReaPack repository.

If you don't already have ReaPack, [head on over to reapack.com and install
it](https://reapack.com/).

Once you have ReaPack installed:
1. Open the menu: `Extensions | ReaPack | Import a Repository`
1. Paste in this URL: `http://reaticulate.com/release.xml`
1. Double click the newly added Reaticulate item in the repository list
1. Click the `Install/update Reaticulate` button and select `Install all packages`
1. Invoke the action `Script: Reaticulate_Main.lua` from the actions list

<p class='warning'>
    Tip: in Reaticulate's Settings page, you can configure it to automatically start
    when Reaper starts.
</p>

Now's a good time to read more about [how to use Reaticulate](usage).

### Updating

Access `Extensions | ReaPack | Synchronize packages` via Reaper's menu to ensure Reaticulate is updated
to the latest version.


### Living on the edge?

Pre-releases are made available from time to time and can give an earlier preview to new functionality
or fixes.  For the pre-release version, instead of the above ReaPack URL, use this one:

```
http://reaticulate.com/prerelease.xml
```

This ReaPack will always contain the latest version, whether a release, or a subsequent pre-release.

<p class='warning'>
    Pre-releases are kept as stable as possible, unfortunately by virtue of having less testing time they are
    more likely to contain bugs.

    Your feedback with pre-releases is very much appreciated.  See the <a href='{% link contact.md %}'>
    contact page</a> for details on how to report issues.
</p>



It's possible to switch between the release and prerelease ReaPacks, but you first need to uninstall
Reaticulate before following the above installation instructions again.  (Don't worry, your custom
banks won't be affected.)

Follow these steps below to uninstall.

### Uninstalling

Follow these steps to uninstall the Reaticulate ReaPack:

1. Close current project (if one is open)
1. Menu: `Extensions | ReaPack | Manage Repositories`
1. Right click Reaticulate and click Uninstall
1. Click ok and say yes to the prompt
1. Restart Reaper (necessary to stop existing Reaticulate instance)


## The Hard Way (Manual)

If your DAW doesn't have Internet connectivity, you can follow these manual installation
instructions:

1. Download the zip file of the latest version [on the releases page](https://github.com/jtackaberry/reaticulate/releases) and copy it to your DAW (via USB thumbdrive or whatever)
1. Extract the `reaticulate-<version>` folder contained within the zip to your REAPER Scripts/ directory
  - On Windows this is `%AppData%\REAPER\Scripts`
1. Rename the `reaticulate-<version>` folder to `Reaticulate`
1. Move all files in the `jsfx` folder up to the `Effects/` directory (which exists on the same level as Scripts/)
  - On Windows this is `%AppData%\REAPER\Effects`
1. In Reaper, open the Actions dialog and click the `Load ...` button in the bottom right
1. Navigate to `Scripts/Reaticulate/actions/` and select all files in that directory, and then click the Open button
1. Invoke the action `Script: Reaticulate_Main.lua` from the actions list