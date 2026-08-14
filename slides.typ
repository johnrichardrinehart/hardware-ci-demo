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

The flake locks every source revision used by both images.

= The CI loop

== Turn a commit into hardware evidence

#grid(
  columns: (1fr, 1fr, 1fr),
  gutter: 0.8em,
  flow-step([1], [Build], [Create the target image from the locked flake.]),
  flow-step([2], [Flash], [Switch or write the ROCK 5C storage remotely.]),
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
  Build → flash → power → observe → verify
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
