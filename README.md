# Hardware CI demo

This circuit lets a Raspberry Pi 4 Model B assert the Radxa ROCK 5C
`PWRON_L` signal. It is for the talk, *Developing hardware at the speed of
software*.

![Physical wiring schematic](schematic-v9.png)

[Open the SVG source.](schematic.svg)

## Connections

| 74LS136N pin | Connect to |
| --- | --- |
| 1 (`1A`) | RPi physical pin 11 (`GPIO17`) through 330 Ω (`R2`) |
| 2 (`1B`) | Common ground |
| 3 (`1Y`, open collector) | ROCK 5C J3 pin 3 (`PWRON_L`) |
| 7 (`GND`) | Common ground, RPi physical pin 6, and ROCK 5C J3 pin 2 |
| 14 (`VCC`) | RPi physical pin 2 (`+5 V`) |

Place a 0.1 µF ceramic decoupling capacitor between pins 14 and 7 near U1.
Connect GPIO17 to pin 1 through a 330 Ω series resistor. Connect a 10 kΩ
resistor from the pin 1 side of that resistor to RPi physical pin 1
(`+3.3 V`). The 10 kΩ resistor keeps the power key released while the RPi
starts. The 330 Ω resistor limits current during wiring or configuration
faults. Tie unused inputs 4, 5, 9, 10, 12, and 13 to ground. Leave unused
outputs 6, 8, and 11 unconnected.

If the breadboard has long power leads, add a 1 µF to 10 µF bulk capacitor
across the 74LS136N 5 V and ground rails. Keep the 0.1 µF capacitor even when
you add the bulk capacitor. The ROCK already provides the `PWRON_L` pull-up,
so do not add a pull-up on pin 3.

## Operation

The 74LS136N has open-collector outputs. With `1B` grounded, GPIO17 low
makes `1Y` pull `PWRON_L` low. GPIO17 high releases `1Y`, and the ROCK 5C
pull-up returns `PWRON_L` high. The Raspberry Pi never drives `PWRON_L`
high.

Request GPIO17 as an output with an initial high value in one atomic GPIO
operation. Pulse it low to emulate a power-button press. The ROCK 5C supplies
the pull-up for `PWRON_L`.

## Safety

Power off both boards before wiring them. Connect the common ground before
applying power. The ROCK USB-C input supplies J3 pin 1 through the on-board
`5V_DCIN` rail. Do not connect J3 pin 1 to the RPi or this interface. Do not
connect the RPi 5 V rail to J3 pin 3. Keep the RPi powered whenever the
74LS136N or ROCK is powered. Verify the board revision and J3 pin labels
before use.

## Presentation

The slide deck uses Typst and Touying's Metropolis theme. The Nix development
shell supplies Typst, Fira Sans, and Fira Math.

```console
nix develop
typst watch slides.typ slides.pdf
```

Run `nix build .#slides` for a reproducible PDF in `result`. The flake pins
Touying 0.7.4 and its package dependency. Open the generated PDF in a
presenter after the build completes.

## Project foundation

I reviewed `nix-project-template` and its customization guide. This initial
repository contains only a diagram and has no Nix output yet. The template
would add unused flake, formatting, hook, and CI configuration. It will
inform the later NixOS closure work when the project gains executable Nix
behavior.

## NixOS closures

`flake.nix` defines two headless `aarch64-linux` SD-card images. The RPi
configuration uses only the direct upstream `nixos/nixpkgs` input. The ROCK
5C configuration uses `johnrichardrinehart/rock5c-nixos` with its board
modules and package overlay. It does not use the RPi input. The flake overrides
that input's `nixpkgs` revision with the first upstream revision that exports
`ubootRock5ModelC`; the ROCK module requires that firmware package. It imports
only the base and option modules. It does not import the media, desktop, Wi-Fi,
flash, or session modules. Both configurations disable documentation and ALSA.
They do not configure a desktop or an automatic root login. Both images
include Bash, coreutils, util-linux, systemd tools, and the `en_US.UTF-8`
locale for diagnostics. The RPi also includes `tio` and `libgpiod` tools.

### Serial consoles

The RPi uses the upstream Raspberry Pi 4 kernel. It keeps its Linux console
on GPIO14 and GPIO15 at 115200 baud. The loaded RPi 4 DTB maps those pins to
the mini-UART. The generic 8250 driver registers it as its first runtime port,
`ttyS0`. The image reserves one 8250 runtime slot. It selects earlycon from
the DTB `stdout-path`, so Linux uses the dedicated BCM2835 AUX UART setup. It
fixes the mini-UART core clock at 250 MHz, so its 115200-baud divisor remains
stable across firmware and Linux handoff. It enables `serial-getty@ttyS0`, so
the RPi serial terminal provides a login prompt after userspace starts.
Connect a separate 3.3 V USB-to-TTL adapter to the ROCK 5C console:

| ROCK 5C pin | USB-to-TTL adapter pin |
| --- | --- |
| 6 (`GND`) | `GND` |
| 8 (`TX`) | `RXD` |

Do not connect the adapter power wire. The ROCK console uses 1,500,000 baud,
8N1, with no flow control. On the RPi, run this command after the adapter
appears as `/dev/ttyUSB0`:

```console
tio --baudrate 1500000 /dev/ttyUSB0
```

The adapter isolates ROCK output from RPi `serial0` output. The RPi console
continues to use GPIO14 and GPIO15. The USB adapter records the ROCK console.

Both images enable password SSH for the `demo` user. Its password is `demo`,
and it is in the `wheel` group. Both images include the configured Bash shell,
so SSH provides an interactive session. The image declares the account and
plaintext password on each boot. SSH uses the standard NixOS PAM password path.
Root cannot log in through SSH. After DHCP assigns an address, connect
with this command:

```console
ssh demo@<rpi-address>
```

Use SSH to inspect RPi output with `journalctl -kf` or `dmesg -w`.

### GPIO power-key control

The RPi image includes the `libgpiod` command-line tools. The `demo` user is
in the `gpio` group and can access `/dev/gpiochip*` without `sudo`. It is also
in `dialout` for access to the ROCK USB-to-TTL adapter. List the
GPIO controllers and inspect GPIO17 with these commands:

```console
gpiodetect
gpioinfo --chip gpiochip0 17
```

GPIO17 is RPi physical pin 11. Set it high to release the ROCK power key. The
command owns the line until you stop it with `Ctrl-C`:

```console
gpioset --chip gpiochip0 17=1
```

Pulse the power key low for 500 ms, return it high, and release the line:

```console
gpioset --chip gpiochip0 --toggle 500ms,0 17=0
```

The external 10 kΩ resistor pulls GPIO17 high after `gpioset` exits.

Run the bundled command to force the ROCK off, wait two seconds, and press
the power key for 500 ms:

```console
rock5c-power-cycle
```

This command causes an unclean shutdown. Use it only when a normal reboot is
not available.

Build an image from an `aarch64-linux` builder, or use a configured cross
builder:

```console
nix build .#rpi4-sd-image
nix build .#rock5c-sd-image
```

The RPi image uses the upstream Raspberry Pi 4 firmware and U-Boot SD-image
module. The ROCK image uses the ROCK 5C module's U-Boot and SD-image builder.
Both image files include the boot firmware and root filesystem.

Run the size checks after building the images:

```console
nix build .#checks.x86_64-linux.rpi4-sd-image-under-4GiB
nix build .#checks.x86_64-linux.rock5c-sd-image-under-4GiB
```

Each check fails when its uncompressed image is larger than 4 GiB. The image
builders size the root partition from the actual closure, so no desktop or
preallocated empty root space is included. The initial images will fit on a
4 GiB SD card when their size check succeeds. Use a card with at least
4,294,967,296 bytes. A card sold as 4 GB can be smaller than 4 GiB.
