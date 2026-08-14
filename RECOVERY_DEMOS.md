# ROCK 5C recovery demonstrations

The `broken` branch contains two configurations that fail at different deployment
stages. Use them only on the ROCK 5C test board. Keep the RPi controller and the
USB-to-TTL adapter available during both demonstrations.

Connect the adapter TX pin to ROCK pin 10 (`UART2_RX`). This connection is
required to select an older U-Boot menu entry. Keep these existing connections:

| ROCK 5C header | USB-to-TTL adapter |
| --- | --- |
| Pin 6 (`GND`) | `GND` |
| Pin 8 (`UART2_TX`) | `RXD` |
| Pin 10 (`UART2_RX`) | `TXD` |

On the RPi, open the ROCK console before each demonstration:

```console
tio --baudrate 1500000 /dev/ttyUSB0
```

## Runtime activation failure

`rock5c-runtime-broken` fails a pre-switch check only when the action is
`switch`. The build completes, but `nixos-rebuild switch` returns a failure.
NixOS does not install a boot entry or activate the new userspace.

Record the current system profile. Then attempt the broken deployment:

```console
readlink /nix/var/nix/profiles/system
readlink /run/current-system
sudo nixos-rebuild switch --flake .#rock5c-runtime-broken
```

The command prints this intentional error and returns a nonzero status:

```text
Intentional demo failure: refusing runtime activation.
```

Roll the system profile back and reactivate the previous generation:

```console
sudo nixos-rebuild switch --rollback
```

Verify that `/run/current-system` identifies the restored generation:

```console
readlink /run/current-system
```

## Boot failure

`rock5c-boot-broken` combines the AArch64 userspace with an x86_64 kernel. The
new userspace can activate on the running board. U-Boot cannot start its kernel
after the next reboot. The configuration extends the U-Boot menu timeout to 15
seconds. The extlinux menu retains 20 generations.

Before deployment, record the known-good generation number:

```console
sudo nixos-rebuild list-generations
readlink /nix/var/nix/profiles/system
```

Activate the broken generation while the ROCK is still running:

```console
sudo nixos-rebuild switch --flake .#rock5c-boot-broken
```

Keep `tio` open on the RPi. Reboot the ROCK only after the serial input connection
works:

```console
sudo reboot
```

When the extlinux menu appears, use the arrow keys to select the recorded
known-good generation. Do not select `NixOS - Default` or the newest generation.
Press Enter to boot the selected entry.

If U-Boot already rejected the bad kernel, enter `boot` at the U-Boot prompt.
Select the known-good generation when the menu appears again. A forced ROCK
power cycle also returns to the menu.

After the known-good generation boots, make it the default again:

```console
sudo nixos-rebuild switch --rollback
```

If the immediately previous profile is not the recorded generation, select it
explicitly. Replace `NUMBER` with the known-good generation number:

```console
sudo nix-env --profile /nix/var/nix/profiles/system --switch-generation NUMBER
sudo /nix/var/nix/profiles/system/bin/switch-to-configuration switch
```

Confirm the restored profile before the next reboot:

```console
readlink /nix/var/nix/profiles/system
readlink /run/current-system
```
