---
title: A journey into Reason Mobile
date: 2020-08-19 05:10:17
tags:
  - ocaml
  - reason
  - native
  - mobile
  - cross-compile
---

This is mostly a report on why simple things aren't simple so no TLDR. And also a bit about Reason Mobile.

## Context

Last year(2019) when I was still employed I was looking at a cool piece of tech, called `Revery` a framework to develop desktop applications using Reason Native, super fast and using JSX, and it's not React, it felt really cool, trying some applications like Oni2 the performance was really impressive.

At this time I was still employed and was working with embedded, on a device with 128mb of memory, running on a armv7hf linux box with a broken userspace running QT and using QML, a screen that could only make full updates 5 times per second, yes 5fps. Then I was really curious would it be possible to use something like Revery to make embedded development? Sure it can run right Revery?

I was correct(I always am)

## But ... OCaml

Normally I would say that a cool feature of Reason is being fully compatible with OCaml, so that you can easily use the tools from the OCaml ecosystem like the compiler, build system's like `Dune` and even packages from `opam` to build native applications aka Reason Native.

This time was a little bit different, see, using the OCaml ecosystem also makes Reason Native suffer from the same problems as the OCaml ecosystem, like missing proper tooling to cross compile and not having a great support for Android and iOS.

Yeah the hardware could easily run it, it's possible to run Revery with less than 64mb of memory and a potato as a CPU, it will not be exactly efficient on battery but yeah that's okay, but the tooling? There was no tooling

To make things worse, we also have a new tool, called `esy` which can consume opam and npm packages and making a really easy to reproduce environment, is a really cool piece of tech, but how does it works? Yeah sandboxing, and that completely break the previous attempts to cross compile from the OCaml ecosystem namely `opam-cross`

## The easy trick

The obvious choice is "caveman cross-compiling" just emulate the entire environment, sure, it did work, took a couple of hours and I got to compile binaries from Linux x86_64 to Linux ARMv7l, there is just a single detail, the reason why it took a couple of hours isn't because the setup of the environment needed any trick, no on that esy "just works", it took a couple hours because emulating an ISA is the slowest thing you can ever do if you're doing it properly and especially emulating a RISC on a CISC like ARMv7l on x86_64.

But the trick that I was doing is called full system emulation, there is also another trick which uses user-space emulation combined with binfmt to run a chroot(like a docker container) from one architecture in the other. That was a lot better, but probably still 5x slower than my desktop.

## Hackish Solution

A couple of months ago, I was not employed anymore and had a lot of spare time, so I tried to properly address that by adding cross compiling support on `esy`, yeah that wasn't so simple, modeling multiple versions of the same package turned out to be really tricky, and I didn't have any proper knowledge on package managers, then I made a hackish solution, like really hackish, I will not even tell you how it works, but trust me it's a hackish solution.

I called it [reason-mobile](https://github.com/EduardoRFS/reason-mobile) a bad name, but the intent was "providing tools to cross compile Reason to mobile aka Android and iOS", on that ... yeah I got it to work.

This entire time I was only looking on Android, because it's what I daily drive ... no iOS wasn't simpler. But well what you need to know now is that it works, in a `future post` the road to iOS can be discussed. Currently it works.

## How to use it?

It's a hackish solution, you clone the repository, **put your project inside the root of the project**, and run some magic, there is a example on the README, but the commented script is the following

```sh
git clone git@github.com:EduardoRFS/reason-mobile.git
cd reason-mobile/hello-reason

## it will install the host dependencies
esy install

## cursed node magic, don't ask
node ../generate/dist/cli.js android.arm64

## builds all the dependencies for host and target
## it's going to take a while, seriously
esy @android.arm64

## enter the patched esy shell
esy @android.arm64 not-esy-setup $SHELL
```

Inside this shell you can run the normal commands, like

```sh
## it will build for Android ARM64
dune build -x android.arm64

## binary located at
ls -lah $cur__target_dir/default.android.arm64/bin/hello.exe
```

## Supported platforms

- android.arm64
- android.x86_64
- ios.arm64
- ios.simulator.x86_64
- linux.musl.x86_64

## Limitations

I tried all supported platforms from Linux and Mac, I have no idea if it works on Windows, my bet is that it will not even on cygwin but feel free to try.

## Future and possibilities

I started talking about Revery, yeah that was also maded and is `another post`

We also need a proper solution, integrated on `esy`, ideally doing a lot of magic.

Maybe Reason React Native Native? You know, RRNN, maybe RNRN, it need's a better name, but it's also something that I'm looking for.