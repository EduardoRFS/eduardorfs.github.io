---
title: A different level based typer
date: 2021-09-26 19:34:35
tags:
  - ocaml
  - typer
  - theory
---

In this post I will try to propose / share a rank / level based typer which I believe has free generalization, it can be adapted to the core typer present at OCaml(let-ranking) and SML(lambda-ranking) while still following the same mental model.

**warning, no soundness guarantees**

## TLDR

We can make so that the level on a rank / level based typer always only increases and couple the dead region to the generalized region so that generalization is free. That requires an additional pass that can be done together with parsing for a "true" "free" generalization.

## How did I get here

Recently I've been studying how types and typers works, that includes classical like STLC(Simple Typed Lambda Calculus), HM (Damas-Hindley-Milner type system), System F.

And around the way I implemented many typers and start to understand how they work in theory and in practice(value restriction), most of them implemented in OCaml and as a natural thing I started to look more and more in the OCaml typer which I already had some intuitive understanding after so many `type constructor t would escape it's scope`.

But after reading [How OCaml type checker work](http://okmij.org/ftp/ML/generalization.html) by Oleg I had an enlightenment on the topic, but there is a hard feeling on me of "this can be extended even further", so I tried the natural ideas that came to my mind, using negative levels to encode multiple forall levels and short circuit instantiation, which seems promising and I plan to make a post in the following weeks, the other one is levels that always increase which is the topic of this week.

**I HIGHLY RECOMMEND** that you read [How OCaml type checker work](http://okmij.org/ftp/ML/generalization.html) to understand what I'm talking about and find any problem in my approach.

## What is a level based typer?

The idea is that we're using instead of scanning the context during typing we're gonna use a level to know when a type variable is present in the scope then generalize it, this is effectivelly an algorithm of escape analysis. It was invented / discovered by Didier Rémy and it leads to a more efficient implementation of a HM typer.

Note that Didier Rémy and the literature calls levels, ranks, but the OCaml typer calls it levels, and it makes more sense in my head(probably bias), so I will be using levels here.

It is [formalized to be equivalent to the Algorithm W](http://people.cs.uchicago.edu/~gkuan/pubs/ml07-km.pdf) which ensures that it generates the most general type and in a sound manner.

It also exists in two major variations:

- lambda-ranking, every lambda introduces a new level and generalizes
- let-ranking, every let introduces a new level and generalizes.
  Each has it's advantages and the idea showed here can easily work with both, but my implementation will focus more on lambda-ranking as for me it looks that it it can be more easily extended.

## Generalization

One of the properties of this family of typers is that generalization requires you to go over the type after typing some expression to check if it is bigger than the current level and mark it as quantified, as a level bigger than the current level lives in a dead region and never escaped it's region, so it's not present in the context, again escape analysis.

While this is cheap as types are treated as always being really small, it's not free and will do O(n) operations being n the number of nodes in the type tree.

## The dead region

A dead region is a region of code that was already typed and lies "above" the current typing point.

In the current designs all type variables in a dead region are treated as quantified because we know that they never escaped it's scope. And so they need to actually be elevated to a level where all variables are quantified, essentially it's a process where we look on a type and check if it's in a dead region, if so mark it.

Here I will be proposing that the dead region should be the quantified level and that any variable at the dead region.

So any variable outside of the dead region should be treated as a free variable and not duplicated during instantiation, any variable inside the dead region is a quantified variable and should be duplicated during instantiation

## Moving the line in only one direction

Because the dead region moves as typing is done and now the level that marks something to be quantified is the same as the level that delimits the dead region. So my proposal is essentially that the level that marks what is quantified is actually moving.

You can imagine that the level that marks something as generalized is a line where everything below it, is not generalized and everything above it is generalized, currently we're moving every type that is not on the generalized level individually to above the line, here we will be actually moving the line so that all types which did not escape its scope are automatically treated as quantified. This makes so that generalization is now an O(1) operation, and effectivelly incrementing an integer.

## Creating variables in the future

But this means that creating a variable on the current level doesn't work as a free variable for it's inner expressions, a solution to this is creating a variable in the level after the current typing finishes.

This doesn't work with the way that we normally do regions by entering and leaving a region, as the level after typing everything will always be the same level as before typing everything, so instead of entering and leaving, we only enters a region and never leaves it.

But this means that before typing the typer needs to somehow know what will be the region after it finishes it's typing, this means that we need to somehow know the future.

A simple solution is to do a pass annotating every AST node that create a variable, with the level expected after typing its content, this pass can actually happens for "free" by doing it during parsing so that there is no cost of iterating the AST.

In lambda-ranking this means that lambda + application will need to carry an additional level in the AST. In let-ranking only a let is required to carry the additional level.

## Moving the line

So during typing of an expression variables are created on the type after the current expressions finishes and after every expression the level is increased, marking that we leaved the current region.

This also requires that when unifying two types instead of the end type being always the smallest possible type it will be the largest possible type, so that unifying `'a[1] : 'b[2]` will results in `'b[2]`.

## Value Restriction?

Yeah, I don't know. But I believe the easiest way is to tag types with some crazy big level.

## Implementation

The following implementation does lambda-ranking + free generalization as described above, while I'm not so sure the current implementation is sound, I'm hoping the idea described here is.

[a_different_level_based_typer.ml](https://github.com/EduardoRFS/eduardorfs.github.io/blob/gh-pages/code/a_different_level_based_typer.ml)

## References

- http://okmij.org/ftp/ML/generalization.html
- http://people.cs.uchicago.edu/~gkuan/pubs/ml07-km.pdf
