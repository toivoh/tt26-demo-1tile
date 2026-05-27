<!---

This file is used to generate your project datasheet. Please fill in the information below and delete any unused
sections.

You can also include images in this folder and reference them in the markdown. Each image must be less than
512 kb in size, and the combined size of all images must be less than 1 MB.
-->

## Intro

Curly / Medieval presents **Underflow Uncubed**,
my contribution to the single tile category of the TTSKY26a demo competition.
Code, graphics, and music by Curly (Toivo Henningsson) of Medieval.

The demo can be seen at https://youtu.be/JkifIYlgSE0 (captured from a Verilator simulation).

The demo contains the same music as my four tile demo [Underflow Cubed](https://github.com/toivoh/tt26-demo-4tile), but the 3d graphics did not fit in the single tile format.
I was able to add a music visualizer, though.

## How it works

The synth works in a quite similar way to the one described in https://github.com/toivoh/tt10-demo/blob/main/docs/info.md.
Many of those ideas are described further in https://github.com/toivoh/ttsky25a-pwl-synth/blob/main/docs/info.md, but that synth uses a phase accumulator per voice, instead of calculating voice phases from a shared oscillator.

The synth computes a new sample every 800 cycles; twice per scan line.
One sample every scan line is used for sound output, and the other is used for visualization.
The difference between these samples is which value is used for the shared oscillator phase. For the sound output, it is free-running, while it is based on the current y position for the visualization.
The result is that the synth is sampled at 31.5 kHz. The ouput resolution is almost 10 bits (PWM output from 0 to 800), with delta-sigma modulation to add 4 additional bits of resolution.

The synth has 24 voices, which are evaluated in turn to calculate each sample. One voice is evaluated in 32 cycles.
Each voice is displayed on screen starting from when it has just been computed until when the next voice has been computed, 16 pixels in total (2 cycles/pixel).
To support the greater number of voices (Orion Iron Ion supported 12), a faster multiplication algorithm is used to calculate the phase from the global oscillator using a radix 4 Booth multiplier.
Most notes use 4 voices with slightly different detuning (and two different octaves for the organ patch), with 2 voices per note for the chords.

The palette changes use a simplified version of the corresponding code in the four tile version.

The sequencer puts together the note material from a few different sources:

- the main melody,
- the current chord for the main melody (root note, sus4 or not, fourth note: nothing / 7 chord / double the root on octave up)
- patterns for the bass and accompaniment based on the current chord

All notes except the melody are derived from the curent chord.

Notes are expressed a scale of 7 notes per octave. These are translated to actual pitches using the current key, which can switch between

- A harmonic minor
- C harmonic minor
- C minor
- C dorian
- C mixolydian
- C major

When modulating at the end of many sections, the melody note is initially kept in the current key, while the rest of the notes go to the new key.

## How to test

Plug in a [TinyVGA](https://github.com/mole99/tiny-vga) compatible Pmod on the demo board's out Pmod.
Plug in a Pmod compatible with [Mike's audio Pmod](https://github.com/MichaelBell/tt-audio-pmod) on the TT08 demo board's bidir Pmod.
Set all inputs to zero to get the default behavior.
The demo starts directly after reset.

## External hardware

This project needs
-  a [TinyVGA](https://github.com/mole99/tiny-vga) VGA Pmod.
- [Mike's audio Pmod](https://github.com/MichaelBell/tt-audio-pmod).
