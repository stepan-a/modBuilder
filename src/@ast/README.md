# ast

Abstract syntax tree for `modBuilder` equations.

## Overview

The `ast` class parses an equation string into a tree of typed nodes that
can be inspected, transformed, and rendered back to a string. It is used
to provide a basis for symbolic operations on equations — static
reduction, substitution, differentiation, LaTeX rendering — that other
modules can layer on top of the same tree. The first concrete consumer
is the static-cancellation check that `modBuilder.matchequations` will
use to decide whether an endogenous variable is a candidate match for an
equation.

`ast` is a value class, so transformations like `staticise` return a new
tree rather than mutating the receiver.

## Node types

A tree is built from seven kinds of nodes. Each node carries a `type`
(char), a `value` whose shape depends on the type, and a `children` cell
array.

| Type     | Purpose                                                                  | `value`              | `children`          |
|----------|--------------------------------------------------------------------------|----------------------|---------------------|
| `num`    | Numeric literal (`0.33`, `1e-5`)                                         | double scalar        | `{}`                |
| `sym`    | Bare symbol at the current period (parameter, endogenous, exogenous)     | char (name)          | `{}`                |
| `tsym`   | Lead or lag of a variable (`Consumption(-1)`, `K(+1)`)                   | `{name, lag}`        | `{}`                |
| `ss`     | Steady-state operator on a symbol (`STEADY_STATE(x)`)                    | char (name)          | `{}`                |
| `call`   | Built-in function call (`exp(x)`, `log(a+b)`, `max(a, b)`)               | char (function name) | `{arg1, arg2, ...}` |
| `binop`  | Binary operator `+ - * / ^` (`^` right-associative, the rest left-)      | char (operator)      | `{left, right}`     |
| `uminus` | Unary minus (`-x`)                                                       | `[]`                 | `{operand}`         |

## Quick start

```matlab
t = ast('alpha * K(-1)^theta * L^(1 - theta)');

t.string()                          % render back to a string

t.staticise().string()              % static version, time subscripts dropped

[has, cancels] = t.staticise().check_factor('K')   % does K factor out?
```

## Public methods

### Constructor

#### `ast()`

Construct an empty node.

#### `ast(string)`

Parse an equation string into a tree.

```matlab
t = ast('beta * R(+1) - 1');
```

#### `ast(type, value, children)`

Construct a single node directly from its `(type, value, children)`
triple. Used internally by the parser; outside callers rarely need it.

### Instance methods

#### `t.string()`

Render the tree back to a string with minimal parentheses. Round-trips:
`ast(t.string())` is structurally equal to `t` for every tree built by
the parser.

#### `t.staticise()`

Return a new tree with every time-subscripted node `x(±k)` replaced by a
plain symbol `x`. Other node types descend through their children but
are otherwise unchanged.

#### `[has, cancels] = t.check_factor(varname)`

Test whether `varname` appears as a common multiplicative factor of the
tree. Returns

- `has` — true iff `varname` appears anywhere in `t`,
- `cancels` — true iff the whole expression equals `varname · f` for
  some `f` that does not depend on `varname` (implies `has`).

`tsym` nodes match by name, so the check works on a non-staticised tree.
For the static reduction context, call `staticise()` first. `ss` nodes
never match: `STEADY_STATE(x)` is a constant w.r.t. the dynamic variable
`x`. The check is purely structural; cases that require algebraic
simplification (e.g. `w/w → 1`) are not detected — see *Limitations*.

#### `disp(t)`

Compact display: print the rendered expression. Implicitly invoked when
a tree is the result of an unsuppressed expression.

### Static methods

These are mostly internal but can be useful for inspection.

- `ast.tokenise(str)` — split an equation string into the flat list of
  tokens consumed by the parser.
- `ast.parse_expr / parse_term / parse_unary / parse_power / parse_atom`
  — recursive-descent parser entry points, one per grammar non-terminal.
- `ast.ast_equal(a, b)` — structural (syntactic) equality of two trees.
- `ast.op_precedence(op)` — operator precedence levels used by the
  renderer.

### Constant

`ast.RESERVED_FNAMES` lists the function names recognised by the parser
as `call` nodes. The list is shared with
`modBuilder.DYNARE_RESERVED_NAMES` via the free function
`dynare_reserved_function_names()`.
