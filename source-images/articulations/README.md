# Articulation Icons

This directory contains the original images for the articulation icons used in Reaticulate, and a Python
script to process the raw icons into a packed image grid used internally by Reaticulate.

The files in this directory are:
 * `articulations-free.afdesign`: the [Affinity Designer](https://affinity.serif.com/) project containing
   icons licensed under Apache 2.0
 * `articulations-nonfree.afdesign`: the [Affinity Designer](https://affinity.serif.com/) project containing
   non-free icons that cannot be redistributed without permission (see below)
 * `articulations-free*.png`: PNG renders of varying resolutions of `articulations-free.afdesign`
 * `articulations-nonfree*.png`: PNG renders of varying resolutions of `articulations-nonfree.afdesign` that
    cannot be redistributed without permission (see below).
 * `generate.py`: a Python script that reads the above PNG renders and generates a packed image grid and
   and a Lua script excerpt that is used in [../app/articons.lua](../app/articons.lua).
 * `artnames.txt`: an input file for `process.py` that describes the arrangement of the PNG renders and
   the icon names.

## Usage

The `generate.py` Python script requires the NumPy and Pillow (a PIL fork) modules.  These can
be installed via pip:

```bash
pip3 install numpy pillow
```

Also, the `pngcrush` command line utility needs to be installed.  On Debian-based systems, this
can be installed with apt:

```bash
sudo apt install pngcrush
```

The image pack and Lua excerpt can then be generated by running the script:

```bash
python3 generate.py
```

A file `articons.lua` is written in this directory.  This excerpt needs to be added to
the [../../app/articons.lua](../../app/articons.lua) file from Reaticulate's source
directory, replacing the existing definition of

## Free vs Non-Free

The icons are split into two separate groups of files: free icons released under the
Apache 2.0 license, and non-free icons where redistribution is not permitted.

**Non-free articulation icons in Reaticulate are Copyright 2008-2021 Blake Robinson
(http://blake.so) and used by Reaticulate with Blake's permission.  No license within
Reaticulate allows for redistribution of these icons.**

Prior to Reaticulate 0.5, *all* articulation icons were considered non-free because they
were screen-scraped from products where Blake's icons were used.  Blake was gracious
enough to permit distribution by Reaticulate given that it's a non-commercial open source
project, however redistribution by other projects was not allowed.

As of Reaticulate 0.5, all icons have been redone from scratch using vector graphics in
order to better support high DPI displays.  The basis of these icons is the [Leland music
font](https://github.com/MuseScoreFonts/Leland), which is released under the Open Font
License (OFL).

With this change, the following litmus test was used to decide if an icon is considered free
or non-free:
 * Icons that express standard music notation that can be found in public domain works are considered free
 * Icons with unique or novel notation, or a specific arrangement of existing notation (e.g. phrases)
   of Blake's invention, continue to be considered non-free with Blake Robinson as copyright holder.
