# User Submitted Reaticulate Banks

These banks are provided by other Reaticulate users.  They are **uncurated** and **untested** and quality will vary.  At the very least, they can serve as starting points for your own customizations.

If you find problems, please [open an issue](https://github.com/jtackaberry/reaticulate/issues).

And if you have a bank to contribute to this list, please also [open an issue](https://github.com/jtackaberry/reaticulate/issues) or pass it along via [email or one of the forums](https://reaticulate.com/contact.html).

## Installation

1. Find a library you wish to import and click the link
2. Copy the contents of the file to your clipboard
3. In Reaper, click the pencil icon in the Reaticulate's toolbar and click Edit
4. Paste the contents of the clipboard into that file
5. Modify the bank numbering if necessary to ensure no conflicts with other banks in your reabank file (see below)
6. Save the file
7. Click the refresh icon in Reaticulate's toolbar to load the new banks


**You will almost certainly need to modify the Bank numbers to ensure no conflicts with your own!**  For example, the `Bank` declaration line such as:

```
Bank 14 18 EW Alto Flute KS
```

In this example, the combination of `14` (MSB) and `18` (LSB) values must not exist elsewhere in your `Reaticulate.reabank` file.
