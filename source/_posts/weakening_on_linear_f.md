---
title: A tale of sum types on Linear F
date: 2023-01-08 14:47:30
tags:
  - ocaml
  - typer
  - linear
  - theory
---

The [Linear F](https://github.com/EduardoRFS/linear-f/) is a system similar to [System F◦](https://www.cis.upenn.edu/~stevez/papers/MZZ10.pdf), but where the traditional type kind was removed, so it is a pure linear lambda calculus with first-class polymorphism.

## TLDR

To encode sum types, weakening is required. By carrying the garbage around in a monad you can easily model do weakening on Linear F. As such you can encode sum types on Linear F. Proof [weak.linf](https://github.com/EduardoRFS/linear-f/blob/main/examples/weak.linf#L34)

## Context

I've been playing with linear type systems for a while, currently I hold the opinion that some form of linear calculus is probably the right solution for a modern functional programming language.

As such I've been trying to show that you can do everything in a pure linear calculus. By doing {church,scott}-encoding of every interesting primitive present in real languages, sadly many of the traditional encodings rely on weakening, which is not directly available on a linear calculus due to that, the traditional wisdom is that sum types are not possible in a pure linear calculus.

## Explicit Weakening

My hypothesis is that weakening can always be explicitly encoded in a linear system by carrying everything discard explicitly as a parameter.

The main idea is that any function that relies on weakening can return all the discarded elements together with its output as a multiplicative products aka a pair.

### Naive Weakening Encoding

The simplest encoding possible is to literally just return a pair, so to describe the affine term `x => y => x` would be written as `x => y => (x, y)`, the convention here is that the second element of the pair is just garbage and as such should be ignored.

### Nicer Weakening Encoding

A type encoding is possible for the garbage in the presence of existential types, the garbage bag can have the type of `Garbage === ∃x. x`, which can be encoded in Linear F. This makes so that a function to [collect garbage](https://github.com/EduardoRFS/linear-f/blob/main/examples/weak.linf#L10) can be done.

### An even nicer weakening encoding

A nicer encoding can be done by making a monad for weakening, this makes so that handling garbage is implicit in the monadic context. `Weak A === Garbage -> (A, Garbage)`, so any function doing weakening can have the type `A -> Weak B`.

### The perfect weakening encoding

While monadic weakening is nice enough to actually use it, an even better one would be an encoding based on algebraic effects, such that the function `weak : ∀A. A -[Weak]> ()` can be used to explicit weaken anything, such a function wills simply pack it as `Garbage` and call the effect handler, which can then decide what to do with such piece of data.

This could be combined with first class support of the language as an implicit effect so that it behaves exactly like an affine system.

## Back to Sum Types

Many of the traditional church encodings for data rely on weakening, such as booleans and sum types, ex : `true === x => y => x`. As such those encodings seems to not work in a purely linear setting, but they can be done in an affine setting.

And as shown above, weakening can be done on the Linear System F, which is contrary to some beliefs:

> [MZZ10] - we cannot encode linear sums in System F◦ as presented so far

> [Church encoding of linear types](https://oleg.fi/gists/posts/2019-06-26-linear-church-encodings.html#encoding-of-with) - Unfortunate, but known fact. So, we cannot (at least obviously) simulate A & B using something else.

### Linear F + Either

Either is the canonical sum type, if you can describe it you can describe any other sum type, so showing Either is enough to show all sum types.

Example for Either can be found at [weak.linf](https://github.com/EduardoRFS/linear-f/blob/f95c751f04bf0097c9c7220bb5b9d686a381d1f7/examples/weak.linf#L34).

### Linear F + Bool

But a simpler example that is easier to analyze are booleans,

```rust
// let's assume the weakening monad
type Weak A === Garbage -> Pair A Garbage in
let weak : forall A. A -> Weak Unit === _ in
let map : forall A B. Weak A -> (A -> B) -> Weak B === _ in

// on booleans one of the arguments is always weakened
type Bool === forall A. A -> A -> Weak A in
let true : Bool === fun (type A) x y ->
  map (type Unit) (type A)
    // weakens y
    (weak (type A) y)
    // returns x
    (fun unit -> unit (type A) x) in
let false : Bool === fun (type A) x y ->
  map (type Unit) (type A)
    // weakens x
    (weak (type A) x)
    // returns y
    (fun unit -> unit (type A) y) in

// examples
/* because variables cannot appear twice, closures cannot be used
    so the solution is to pass functions, aka CPSify the matching

  A is the shared context between branches
  K is the return type of the matching */
let match_bool : forall A K. Bool -> (A -> K) -> (A -> K) -> A -> Weak K ===
  fun (type A) (type K) b then_ else_ x ->
    b (type K) then_ else_ x in

// slightly more concrete example, assumes integers
let incr_if_true : Bool -> Int -> Weak Int ===
  fun b x ->
    /* because x cannot appear twice,
       we need to do the case on a function */
    b (type Int)
      (fun (x : Int) -> x + 1)
      (fun (x : Int) -> x)
      // actually apply
      x
```

## References

- https://www.cis.upenn.edu/~stevez/papers/MZZ10.pdf
- https://github.com/EduardoRFS/linear-f
- https://oleg.fi/gists/posts/2019-06-26-linear-church-encodings.html
