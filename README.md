_NOTE: This fork of the original repository incorporates about 70 user-submitted reabank files in the userbank folder hierarchy that were in the Issues section._


# Reaticulate

Reaticulate provides a system for managing virtual instrument articulations in REAPER.

[Learn more on the website](http://reaticulate.com/), which includes installation instructions for users.

# Development

If you're a developer interested in contributing to Reaticulate, or an advanced user who
wants to run untested bleeding edge code (which you should never use for projects that
matter), you can check code out directly from git.

Note that Reaticulate depends upon the [REAPER Toolkit](https://reapertoolkit.dev/), which
is included as a submodule of this project.

You can clone Reaticulate like so, which will take care of fetching submodules:

```bash
git clone --recursive https://github.com/jtackaberry/reaticulate.git
```

Or, afterward, pulling to include submodule updates:

```bash
git pull --recurse-submodules
```

You can always explicitly fetch submodules after-the-fact:

```bash
git submodule update --recursive
```

Next, configure REAPER to point to the source files in the cloned directory:
1. Load all actions under `actions/*`
2. Create a symbolic link for each file in `jsfx/` in REAPER's `Effects/` directory.
   (Windows instructions [here](https://blogs.windows.com/windowsdeveloper/2016/12/02/symlinks-windows-10/) --
   or use the very convenient [shell extension](https://schinagl.priv.at/nt/hardlinkshellext/linkshellextension.html).)
3. Start the `Reaticulate_Main.lua` action as usual.


# Legal Stuff

Reaticulate source code is released under the Apache License.

Some articulation icons are provided by Blake Robinson, and redistribution is not
permitted. More information about those icons can be found [here](source-images/articulations).

See LICENSE file for more details.
