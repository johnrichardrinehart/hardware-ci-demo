#import "@preview/touying:0.7.4": *
#import themes.metropolis: *

#let brand-green = rgb("#2f7d57")
#let brand-orange = rgb("#e8792e")
#let ink = rgb("#20302b")
#let pale-green = rgb("#eaf3ee")

#show: metropolis-theme.with(
  aspect-ratio: "16-9",
  footer: self => [Hardware CI demo],
  config-colors(
    primary: brand-orange,
    primary-light: rgb("#f4d2bc"),
    secondary: brand-green,
    neutral-lightest: rgb("#fbfcfb"),
    neutral-dark: ink,
    neutral-darkest: ink,
  ),
  config-info(
    title: [Developing hardware at the speed of software],
    subtitle: [Reproducible images, remote power control, and observable boots],
    author: [John Rinehart],
    date: [2026],
    institution: [Hardware CI demo],
    contact: [github.com/johnrichardrinehart/hardware-ci-demo],
  ),
)

#set text(font: "Fira Sans", fill: ink)
#show raw: set text(font: "Fira Mono")

#let card(title, body, accent: brand-green) = block(
  width: 100%,
  inset: 0.8em,
  radius: 0.25em,
  fill: pale-green,
  stroke: (left: 0.16em + accent),
  [#text(weight: "bold", fill: accent)[#title]  #body],
)

#let flow-step(number, title, body) = card(
  [#number · #title],
  body,
  accent: brand-orange,
)

#title-slide()

= The problem

== CI stops at the edge of the computer

#grid(
  columns: (1fr, 1fr, 1fr),
  gutter: 1em,
  card([Build], [Produce a known system image.]),
  card([Deploy], [Write it to real removable storage.]),
  card([Observe], [Control power and capture the complete boot.]),
)

#v(1.2em)

Software automation is mature. The last manual steps still hide in cables,
buttons, and removable media.

#speaker-note[
  - Start with the gap between a successful build and a tested device.
  - The goal is not a simulated boot. The goal is evidence from the board.
]

= The system

== A small lab with clear ownership

#grid(
  columns: (1fr, 0.12fr, 1fr, 0.12fr, 1fr),
  align: horizon,
  card([CI runner], [Builds the NixOS closures and selects an image.]),
  align(center)[#text(size: 1.5em, fill: brand-orange)[→]],
  card(
    [Raspberry Pi 4],
    [Flashes storage, controls the power key, and records serial output.],
  ),
  align(center)[#text(size: 1.5em, fill: brand-orange)[→]],
  card([ROCK 5C], [Boots the candidate image on the target hardware.]),
)

#v(1em)

#align(center)[*Two independently powered boards share one signal reference.*]

== Control the key; never drive it high

#figure(
  image("schematic.svg", width: 83%),
  caption: [An open-collector gate emulates the ROCK 5C power button.],
)

#speaker-note[
  - GPIO17 drives one 74LS136N input through 330 ohms.
  - Grounding the second input makes the gate follow GPIO17.
  - The output only pulls PWRON_L low. The ROCK releases it with its own pull-up.
]

== Separate power, common ground

#grid(
  columns: (1fr, 1fr),
  gutter: 1.2em,
  card([Raspberry Pi 4], [Its USB-C supply powers the Pi and the 74LS136N.]),
  card([ROCK 5C], [Its USB-C supply powers the board and J3 `5V_DCIN`.]),
)

#v(1em)

- Connect the grounds before applying power.
- Connect J3 pins 2 and 3 to the interface.
- Leave J3 pin 1 disconnected.
- Keep the 0.1 µF capacitor directly between pins 14 and 7.

= Reproducibility

== Build the exact systems we test

#grid(
  columns: (1fr, 1fr),
  gutter: 1.2em,
  card(
    [RPi controller image],
    [GPIO tools, serial capture, SSH, and a minimal NixOS base.],
  ),
  card(
    [ROCK candidate image],
    [Board firmware, kernel, root filesystem, and the same declared userspace.],
  ),
)

#v(1em)

```console
nix build .#rpi4-sd-image
nix build .#rock5c-sd-image
```

The lock file pins declared flake inputs. Fixed-output hashes verify other fetched sources.

== Make every deliverable an output

#grid(
  columns: (1fr, 1fr, 1fr),
  gutter: 0.9em,
  card(
    [System image],
    [Boot firmware, kernel, device tree, and root filesystem.],
  ),
  card(
    [Hardware BoM],
    [Part numbers, quantities, references, and approved substitutions.],
  ),
  card(
    [Software inventory],
    [Every package in the runtime closure, exported as SPDX or CycloneDX.],
  ),
)

#v(1em)

When inventory data is explicit, one Nix build can emit JSON, procurement CSV,
and release artifacts from one reviewed revision.

#speaker-note[
  - Nix does not replace the schematic or EDA tool.
  - It makes their exports and the physical BoM inputs part of the build graph.
  - A Nix closure is exact inventory. A separate exporter supplies standard SBOM metadata.
]

== Patch the dependency, not the live machine

#grid(
  columns: (1.15fr, 0.85fr),
  gutter: 1em,
  [
    ```nix
    final: prev: {
      ubootRock5ModelC =
        prev.ubootRock5ModelC.overrideAttrs (old: {
          patches = (old.patches or [])
            ++ [ ./enable-usb-ums.patch ];
        });
    }
    ```
  ],
  card(
    [An overlay makes the change],
    [
      - Board-specific
      - Pinned with its inputs
      - Reviewable as source
      - Rebuilt for every consumer
    ],
    accent: brand-orange,
  ),
)

#v(0.7em)

Use the same method for kernels, device trees, firmware, and user-space tools.

#speaker-note[
  - Use a direct override for one output.
  - Use an overlay when the project needs one replacement across a package set.
  - The old closure remains available because the patch produces new derivations.
]

= Delivery and recovery

== Choose the transport for the change

#grid(
  columns: (1fr, 1fr, 1fr),
  gutter: 0.9em,
  card(
    [USB mass storage],
    [Rewrite the complete microSD image, including boot firmware.],
  ),
  card(
    [Netboot / PXE],
    [Fetch a kernel, initrd, and device tree for fast test cycles.],
  ),
  card(
    [NixOS generation],
    [Deploy a new system closure without replacing the complete disk.],
  ),
)

#v(1em)

The artifact remains immutable. Only its delivery path changes.

== Netboot / PXE removes the flash cycle

#grid(
  columns: (1fr, 0.12fr, 1fr, 0.12fr, 1fr),
  align: horizon,
  card(
    [Discover],
    [U-Boot requests network settings and a boot target through DHCP.],
  ),
  align(center)[#text(size: 1.5em, fill: brand-orange)[→]],
  card(
    [Fetch],
    [PXE-compatible U-Boot logic loads the kernel, initrd, and device tree by TFTP or HTTP.],
  ),
  align(center)[#text(size: 1.5em, fill: brand-orange)[→]],
  card(
    [Boot],
    [The initrd selects the immutable Nix closure and runs the test.],
  ),
)

#v(0.9em)

*Keep known boot firmware locally.* Use PXE only where the U-Boot build and
Ethernet driver support it. Netboot also adds DHCP, server, and network dependencies.

#speaker-note[
  - On this ARM board, PXE-like boot is a U-Boot workflow, not PC firmware behavior.
  - Netboot is ideal for kernel and initrd iteration.
  - USB UMS remains the recovery path when local boot content must change.
]

== Rollback needs a health policy

#grid(
  columns: (1fr, 1fr),
  gutter: 1.1em,
  card([Transactional system], [
    - Build the new closure before activation.
    - Keep the previous NixOS generation.
    - Activate the system profile atomically.
  ]),
  card(
    [Hardware-aware rollback],
    [
      - Start a boot deadline.
      - Promote only after health checks pass.
      - Select the last-known-good target after failure.
    ],
    accent: brand-orange,
  ),
)

#v(0.8em)

Generation rollback does not cover the whole device. A/B storage or a recovery image must
also protect boot firmware, partition tables, and mutable data.

= The CI loop

== Turn a commit into hardware evidence

#grid(
  columns: (1fr, 1fr, 1fr),
  gutter: 0.8em,
  flow-step([1], [Build], [Create the target image from the locked flake.]),
  flow-step(
    [2],
    [Deploy],
    [Select a network image or write ROCK storage remotely.],
  ),
  flow-step([3], [Boot], [Pulse `PWRON_L` and start the deadline.]),
)

#v(0.8em)

#grid(
  columns: (1fr, 1fr, 1fr),
  gutter: 0.8em,
  flow-step([4], [Capture], [Record serial output from reset onward.]),
  flow-step([5], [Verify], [Check boot, network, services, and test results.]),
  flow-step([6], [Archive], [Attach logs and image identity to the CI run.]),
)

== Failures become artifacts

#grid(
  columns: (1fr, 1fr),
  gutter: 1.2em,
  card([What CI records], [
    - Image closure and source revision
    - Power-key timing
    - Complete serial transcript
    - Test result and elapsed time
  ]),
  card([What engineers gain], [
    - Reproducible failures
    - Reviewable hardware changes
    - Remote recovery
    - Less manual lab work
  ]),
)

= Demo

#focus-slide[
  #text(size: 1.5em, weight: "bold")[One commit. One image. One real boot.]

  #v(0.8em)
  Build → deploy → power → observe → verify
]

= Takeaway

== Treat the bench as part of the system

#grid(
  columns: (1fr, 1fr, 1fr),
  gutter: 1em,
  card([Declare it], [Images and tools come from versioned configuration.]),
  card([Control it], [Safe interfaces replace manual button presses.]),
  card([Measure it], [Serial logs turn every boot into evidence.]),
)

#v(1.4em)

#align(center)[
  #text(size: 1.25em, weight: "bold", fill: brand-green)[
    Hardware can move at software speed when the whole loop is automated.
  ]
]
