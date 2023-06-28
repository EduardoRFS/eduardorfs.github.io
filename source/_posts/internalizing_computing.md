---
title: Internalizing computing
date: 2023-06-27 22:15:00
tags:
  - typer
  - theory
  - lambda
---

The [Lambda Calculus](https://en.wikipedia.org/wiki/Lambda_calculus) is one of the simplests rewriting systems ever made and while all of its objects are functions it is still a [turing complete](https://en.wikipedia.org/wiki/Church%E2%80%93Turing_thesis) system.

## Church Encoding

One of the most natural things to do in the Lambda Calculus is to describe data such as the booleans, naturals, pairs and list. This is often done through [Church encoding](https://en.wikipedia.org/wiki/Church_encoding), but most people don't seem to be able to mechanically derive those encodings.

## Computing Power

The main insight provided here is that church encodings is just the internalization of the elimination function for some data.

Every data structure seems to come with a function that is capable of doing every fundamental operation on the data itself. This single function provides all the computing power possible for the data. Such as `case` for booleans and `fold` for list.

In fact, it is easy to notice that anything that can describe `case` can be used as a boolean, such as using the empty list as `false` and all non-empty list as `true`.

## Booleans

Let's reinvent church encoding for the booleans step by step, as mentioned above to describe some piece of data, internalizing the elimination rule is enough, for booleans this is the `case` function.

In more concrete terms, the goal is to meet a definition of `true`, `false` and `case` that suffices the following rules:

```rust
true === case true;
false === case false;
case true then else === then;
case false then else === else;
```

A nice property to notice here is that `b === case b`, so a valid definition is that `case === id`, which leads to:

```rust
case = x => x;
(case true) then else === then;
(case false) then else === else;
// implies in
true then else === then;
false then else === else;
```

Well `true` and `false` would need to be functions of the format `then => else => _` to meet the rules, but they need to return different values.

Now we have a set of equations that can be solved, by applying some algebra.

```rust
// assume
true = then => else => ?true;
true then else === then;
// expands
(then => else => ?true) then else === then;
// reduce
?true === then;

// same for false
false = then => else => ?false;
false then else === else;
(then => else => ?false) then else === else;
?false === else;
```

This leads to the canonical representation of the booleans.

```rust
true = then => else => then;
false = then => else => false;
case = x => x;
```

## Finding types

Another interesting property of the internalized version being the same as the elimination function is that the type of `fold n` and `n` will be the same, in fact a good way to find is to start with the type of the elimination function:

```rust
// make Nat equal to the type of fold and remove the first parameter
fold : (n : Nat) -> (A : Type) -> A -> (A -> A) -> A;
Nat = (n : Nat) -> (A : Type) -> A -> (A -> A) -> A;
Nat = (A : Type) -> A -> (A -> A) -> A;

// make Bool equal to the type of case and remove the first parameter
case : (b : Bool) -> (A : Type) -> A -> A -> A;
Bool = (b : Bool) -> (A : Type) -> A -> A -> A;
Bool = (A : Type) -> A -> A -> A;
```

An interesting property is that for most examples of structural recursion, there is no type level recursion.

## References

- https://en.wikipedia.org/wiki/Lambda_calculus
- https://en.wikipedia.org/wiki/Church_encoding
- https://en.wikipedia.org/wiki/System_F
