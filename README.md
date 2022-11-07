# AVR-GCC

This is where I'll be uploading builds of AVR-GCC for Windows 32 bit, 64 bit and Linux 64 bit, which will also include Binutils, AVR-LibC, AVRDUDE, Make and GDB. I'll be trying to keep the builds up to date with the latest tool releases when I can.

The `avr-gcc-build.sh` script was originally a [gist](https://gist.github.com/ZakKemble/edec6914ba719bf339b1b85c1fa792dc), which I've now turned into a repository so releases can be uploaded to GitHub rather than having them hosted on my [website](https://blog.zakkemble.net/avr-gcc-builds/).

## Upgrading the Arduino IDE

Upgrading the Arduino IDE is pretty easy, though there could be some incompatibilities with certain libraries. Only tested with Arduino 1.8.13.

1. Download and extract the [latest release](https://github.com/ZakKemble/avr-gcc-builds/releases)
2. Navigate to your Arduino IDE folder
3. Go to `hardware/tools`
4. Move the `avr` folder somewhere else, like to your desktop (renaming the folder won't work, Arduino has some auto-detect thing which sometimes gets confused)
5. Move the extracted folder from earlier to the `tools` folder and rename it to `avr`
6. Copy `bin/avrdude.exe` and `builtin_tools_versions.txt` files and `etc` folder from the old `avr` folder to the new one
7. Done! Open up the Arduino IDE, load up the Blink example, upload it to your Arduino and make sure the LED is blinking!

## Docker

`docker compose build`

`docker run --rm -it -v $(pwd)/avr-gcc-build-output:/omgwtfbbq [IMAGE NAME]`

---

Zak Kemble

contact@zakkemble.net
