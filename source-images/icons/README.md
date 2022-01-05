# Application Icons

Reaticulate's non-articulation icons are sourced from the
[Material Design Icons website](https://materialdesignicons.com/), released under the
Apache 2.0 license.

Articulation icons are treated separately and have a more complicated license.  See the
[articulation icons directory](../articulations/) for more details.

## Usage

The [download.sh](download.sh) script reads [icon-list](icon-list) as an input file and retrieves
all DPI variants of all icons as separate PNG files.  Those PNG files are maintained in this
directory, so executing `download.sh` should generally not be necessary except to fetch new
icons.

[generate.sh](generate.sh) is used to combine the individual PNG files into an image pack used
by Reaticulate.  The resulting file is written at [../../img/icons.png](../../img/icons.png) and optimized
with pngcrush.

Both ImageMagic and pngcrush is needed to execute.  On Debian-based systems, these can be
installed with apt:

```bash
sudo apt install pngcrush imagemagick
```
