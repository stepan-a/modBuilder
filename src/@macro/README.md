# macro

Abstract syntax tree for the expressions of the Dynare macro language.

## Overview

The `macro` class parses a macro expression into a tree that can be evaluated
against an environment, or rendered as MATLAB source. It is what
[`modfile`](../+modfile/README.md) uses to resolve `@#define` values, `@#if`
conditions, `@#for` index sets and `@{...}` substitutions when reading a `.mod`
file.

It is deliberately separate from [`ast`](../@ast/README.md), which covers the
*model* language. The two languages have little in common: `macro` has a type
system `ast` has no use for (strings, booleans, tuples, arrays), operators `ast`
does not know (`|` and `&` as set operations, `in`, ranges), and no notion of a
lead or a lag. The structure is the same all the same — a character-level
tokeniser followed by one static method per level of the grammar — so anyone who
has read `ast.m` can read this.

```matlab
env = macro.environment(struct('Countries', {{'US', 'EA'}}, 'N', 3));

macro.tostring(macro('length(Countries)').eval(env))    % '2'
macro.tostring(macro('"y_" + Countries[1]').eval(env))  % 'y_US'
macro('N > 2').to_matlab(env)                           % '(N > 2)'
```

## Values

Values are tagged structs, `struct('kind', k, 'data', d)`:

| `kind` | `data` | notes |
|---|---|---|
| `real` | double scalar | |
| `bool` | logical scalar | renders as `true`/`false`, not `1`/`0` |
| `string` | char row | renders bare, so `@{c}` works inside `y_@{c}` |
| `array` | cell of values | ordered, `[...]` |
| `tuple` | cell of values | ordered, `(a, b)`, destructured by `@#for` |

Bare MATLAB values cannot carry the distinctions the language makes —
`isboolean` against `isreal`, and `istuple` against `isarray` — which is why the
tag is explicit. These are the *evaluator's* values, and they stay structs: a
class here would put value dispatch in the inner loop of a recursive evaluator
for no gain. The *rendered* MATLAB is a separate question, and does use classes;
see "How arrays and tuples render" below.

## Grammar

Precedence follows `preprocessor/src/macro/Parser.yy`, lowest first:

```
expr    ::= and_expr ('||' and_expr)*
and     ::= equality ('&&' equality)*
equality::= relational (('=='|'!=') relational)*
relational ::= in_expr (('<'|'>'|'<='|'>=') in_expr)*
in      ::= colon ['in' colon]                     (non-associative)
colon   ::= union [':' union [':' union]]
union   ::= intersection ('|' intersection)*
intersection ::= additive ('&' additive)*
additive::= multiplicative (('+'|'-') multiplicative)*
multiplicative ::= unary (('*'|'/') unary)*
unary   ::= ('-'|'+'|'!') unary | power
power   ::= postfix ['^' unary]                    (right-associative)
postfix ::= atom ('[' expr ']')*
atom    ::= NUMBER | STRING | 'true' | 'false' | IDENT | IDENT '(' args ')'
          | '(' expr (',' expr)* ')' | '[' [expr (',' expr)*] ']'
```

Node types: `num`, `str`, `bool`, `sym`, `arr`, `tup`, `binop`, `unop`, `call`,
`index`, `range`.

## Operators on arrays

Following `preprocessor/src/macro/Expressions.cc`:

| Expression | Result |
|---|---|
| `["US","EA"] + ["JP"]` | `[US, EA, JP]` — concatenation |
| `["US","EA"] - ["EA"]` | `[US]` — set difference |
| `["US","EA"] \| ["EA","JP"]` | `[US, EA, JP]` — union |
| `["US","EA"] & ["EA","JP"]` | `[EA]` — intersection |
| `[1,2] * ["a","b"]` | `[(1, a), (1, b), (2, a), (2, b)]` — Cartesian product |
| `"EA" in Countries` | `true` |

## Methods

### `macro(str)`

Parse an expression. `macro(type, value, children)` builds a single node.

### `t.eval(env)`

Evaluate against an environment, returning a tagged value. `env` is a struct
with two `dictionary` fields, `vars` and `funcs`; build one with
`macro.environment(defines)`.

Function macros are **dynamically scoped**, matching Dynare: the body sees the
caller's variables with the formals bound on top.

### `[str, ok] = t.to_matlab(env)`

Render as MATLAB source. Best effort: `ok` is false when some node has no
faithful rendering, and the caller then emits the evaluated literal instead.

The environment is needed, not merely helpful, because several operators mean
different things depending on the kinds of their operands. `+` is addition on
reals but concatenation on strings and arrays, and MATLAB's `+` on two char
arrays adds their code points — which would be silently wrong. Anything whose
kind cannot be established is declined rather than guessed.

The kind predicates need care, because MATLAB spells two of them the same way
and means something else by them:

| macro | MATLAB rendering | why not the same name |
|---|---|---|
| `isreal(x)` | `(isnumeric(x) && isscalar(x))` | MATLAB's `isreal` asks whether a number has no imaginary part, and is **true** of a char array |
| `isstring(x)` | `ischar(x)` | MATLAB's `isstring` is about the string class, and is **false** of the char array a macro string renders to |
| `isboolean(x)` | `(islogical(x) && isscalar(x))` | |
| `isarray(x)` | `isa(x, 'macroarray')` | the kind is carried by the type, see below |
| `istuple(x)` | `isa(x, 'macrotuple')` | idem |
| `isempty(x)` | `isempty(x)` | |
| `defined(X)` | `exist('X', 'var') == 1` | settled before the argument is rendered, since rendering an unbound variable fails |

### How arrays and tuples render

Through two classes, [`macroarray`](../@macroarray/macroarray.m) and
[`macrotuple`](../@macrotuple/macrotuple.m), which share
[`macrolist`](../@macrolist/macrolist.m):

```matlab
[1, 2, 3]            ->  macroarray(1, 2, 3)
["a", "b"]           ->  macroarray('a', 'b')
[7]                  ->  macroarray(7)
(1, "a")             ->  macrotuple(1, 'a')
[(1, "a"), (2, "b")] ->  macroarray(macrotuple(1, 'a'), macrotuple(2, 'b'))
```

MATLAB natives cannot keep the kinds apart, and the difference is not academic:
an array of one real is the *same double* as the real, and a tuple is the *same
cell* as an array holding the same elements. Carrying the kind in the type is
what lets a generated script answer `isreal`, `isarray` and `istuple` the way
the macro language does — they become plain `isa` tests.

`macroarray` overloads every operator the macro language defines on arrays, so
the rendered MATLAB computes what the macro engine computes:

| macro | MATLAB | meaning |
|---|---|---|
| `A + B` | `(A + B)` | concatenation |
| `A - B` | `(A - B)` | set difference |
| `A \| B` | `(A \| B)` | union, order of first appearance |
| `A & B` | `(A & B)` | intersection, left operand's order |
| `A * B` | `(A * B)` | Cartesian product, elements are tuples |
| `x in A` | `ismember(x, A)` | |
| `A[i]` | `A{i}` | an element |
| `A[i:j]` | `A(i:j)` | a sub-list |
| `length(A)` | `length(A)` | |
| `sum(A)` | `sum(A)` | |
| `A == B` | `(A == B)` | structural, and by kind |

Both take their elements one argument each, so a rendered array is barely
longer than the cell it replaces: `macroarray('US', 'EA')`. To build one from a
cell array, expand it — `macroarray(items{:})` — which is what the class methods
themselves do.

`disp` prints them in the macro language's own notation, `[US, EA]` and
`(1, a)`, so a script stays readable when inspected.

Declined outright: the `array()` and `tuple()` casts, and indexing a literal,
which MATLAB does not allow.

### `macro.tostring(v)`

Render a value the way `@{...}` substitutes it into surrounding text. Strings
render without their quotes; that is what makes `y_@{c}` usable as an
identifier.

### `macro.environment(defines)`

Build an environment, optionally seeded from a struct — the equivalent of
Dynare's `-D` switch. Note that a `@#define` in the file overwrites a seeded
value, as in Dynare; a setting meant to be overridable is normally guarded with
`@#ifndef`.

### `macro.fromnative(x)`

Convert a MATLAB double, logical, char or cell into a macro value.

## Deferred

Comprehensions (`[x for x in A when cond]`) raise
`macro:parse:unexpectedToken` rather than expanding wrongly. String escapes
beyond `\\` and `\"` are not recognised.
