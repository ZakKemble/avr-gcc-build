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

The script can be ran by itself or within a Docker container.

### Build Image

```
docker build -t avrgccbuild .
```

### Run Container

```
docker run --rm -it -v "$(pwd)"/output:/output avrgccbuild
```

On Windows replace `$(pwd)` with `%cd%`:

```
docker run --rm -it -v "%cd%"/output:/output avrgccbuild
```

You will find the built toolchains in the `output` directory of your current working directory.

The build script automatically merges the `avr-libc` directory with each of the toolchain folders, so you can delete it when it's all done.

### Environment Variables

|Variable|Default|Description|
|---|---|---|
|`JOBCOUNT`|Number of CPU cores your system has|More jobs require more RAM, so if you get errors like `collect2: fatal error: ld terminated with signal 9 [Killed]` then you may need to reduce the job count|
|`VER_GCC`|`12.1.0`|GCC version|
|`VER_BINUTILS`|`2.38`|Binutils version|
|`VER_GDB`|`12.1`|GDB version|
|`FOR_LINUX`|`1`|Build for Linux. A Linux AVR-GCC toolchain is required to build a Windows toolchain. If the Linux toolchain has already been built then you can set this to `0`. **This is a bit broken at the moment and should stay as `1`**|
|`FOR_WINX86`|`1`|Build for 32 bit Windows|
|`FOR_WINX64`|`1`|Build for 64 bit Windows|
|`BUILD_BINUTILS`|`1`|Build Binutils for selected OSs|
|`BUILD_GCC`|`1`|Build GCC for selected OSs (requires AVR-Binutils)|
|`BUILD_GDB`|`1`|Build GDB for selected OSs|
|`BUILD_LIBC`|`1`|Build AVR-LibC (requires AVR-GCC)|

Change environment variables by passing the `-e` option when running the Docker container:

```
docker run --rm -it -v "$(pwd)"/output:/output -e VER_GCC="10.1.0" -e BUILD_GDB=0 avrgccbuild
```

## FAQs

### avr-size does not show percent used / is missing the `-C` or `--mcu` option

Use `avr-objdump -Pmem-usage <yourfirmware>.elf` instead. See https://github.com/ZakKemble/avr-gcc-build/issues/3
