---
title: Internalizing computing
date: 2023-06-27 22:15:00
tags:
  - typer
  - theory
  - lambda
---

The [Lambda Calculus](https://en.wikipedia.org/wiki/Lambda_calculus) is one of the simplest rewriting systems in existence. Even though all of its constructs are functions, it is still [turing complete](https://en.wikipedia.org/wiki/Church%E2%80%93Turing_thesis).

## Church Encoding

Describing data in the Lambda Calculus – booleans, natural numbers, pairs and list – is very natural. It's often done through [Church encoding](https://en.wikipedia.org/wiki/Church_encoding). But most people have a hard time deriving that encoding mechanically. In this post, I'll teach you how to do it.

## Computing Power

Here's the main insight: we can get the church encoding for some data by internalizing its elimination function.

We postulate that every data structure comes with a function capable of doing every fundamental operation on itself. A single function, providing _all_ computing power possible for the data. Like `case` for booleans, or `fold` for list.

What's more, any piece of data that can describe `case` can be used as a boolean. An empty list can represent `false`, and any non-empty list can convey `true`.

## Booleans

The boolean elimination function is `case` (like `if` in most popular programming languages, but as a function).

Equipped with that knowledge, we can reinvent the church encoding for booleans, step by step. We apply our main insight: internalizing the elimination rule.

More concretely, our goal is to come up with a definition of `true`, `false` and `case` that satisfies the following rules:

```rust
true === case true;
false === case false;
(case true then else) === then;
(case false then else) === else;
```

First, we notice how `b === case b` – the identity function. We can define `case` as such:

```rust
case = x => x;
(case true) then else === then;
(case false) then else === else;
// which implies
true then else === then;
false then else === else;
```

That's not yet sufficient: to meet our rules, `true` and `false` will need to be functions of the format `then => else => _`. And return different values.

We can express the above using a set of equations, and use algebra to solve them:

```rust
// assuming
true = then => else => #true;
// apply the function
true then else === then;
// we expand it to:
(then => else => #true) then else === then;
// and reduce to obtain our result:
#true === then;

// we do the same for `false`
false = then => else => #false;
false then else === else;
(then => else => #false) then else === else;
#false === else;
```

We can write the above in the canonical representation for booleans.

```rust
true = then => else => then;
false = then => else => false;
case = x => x;
```

## Finding types

Another interesting property of our main insight: the type for `fold n` and `n` will be the same. We can understand that if we start with the type of the elimination function:

```rust
// make Nat equal to the type of `fold` and remove the first parameter
fold : (n : Nat) -> (A : Type) -> A -> (A -> A) -> A;
Nat  = (n : Nat) -> (A : Type) -> A -> (A -> A) -> A;
Nat  = (A : Type) -> A -> (A -> A) -> A;

// make Bool equal to the type of `case` and remove the first parameter
case : (b : Bool) -> (A : Type) -> A -> A -> A;
Bool = (b : Bool) -> (A : Type) -> A -> A -> A;
Bool = (A : Type) -> A -> A -> A;
```

It's interesting to notice the property that, for most examples of structural recursion, there is no type level recursion.

## References

- https://en.wikipedia.org/wiki/Lambda_calculus
- https://en.wikipedia.org/wiki/Church_encoding
- https://en.wikipedia.org/wiki/System_F
