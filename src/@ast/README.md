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

#### `t.canonicalise()`

Return a canonical form of the tree:

- subtraction is rewritten as addition with a unary minus (`a − b → a + (−b)`),
- division is rewritten as multiplication by an inverse (`a / b → a · b^(−1)`),
- chains of `+` and `*` are flattened, the operands sorted by a stable
  key (numbers before symbols before steady-state before negations
  before calls before compound binops), then re-built into a left-
  associated tree.

Two expressions that differ only by operand order (`a + b` vs `b + a`,
`a*b − b*a`, …) become syntactically identical after canonicalisation,
so `ast.ast_equal` then captures their semantic equality. The renderer
recognises canonical patterns and prints `+ uminus(y)` as `… - y` and
`* y^(-1)` as `… / y`, so the rendered output stays readable.

#### `t.simplify()`

Return a simplified version of the tree. Iterates `canonicalise` plus a
bottom-up rule pass to a fixed point. The rule set is local but covers
the everyday cases:

- *constant folding* — `2 + 3 → 5`, `6 / 2 → 3`, …
- *additive identities* — `0 + f → f`, `f − 0 → f`
- *multiplicative identities* — `0 · f → 0`, `1 · f → f`, `f / 1 → f`,
  `f^0 → 1`, `f^1 → f`, `1^f → 1`
- *structural cancellation* — `f − f → 0`, `f / f → 1`,
  `f + (−f) → 0`, `f · f^(−1) → 1`
- *structural merging* — `f + f → 2·f`, `f · f → f^2`
- *coefficient combination in `+` chains* — `2·f + 3·f → 5·f`, and the
  zero-total drop `2·f − 2·f → 0` (a structural generalisation of
  `f + f → 2·f` that handles arbitrary numeric coefficients)
- *exponent combination in `·` chains* — `f^m · f^n → f^(m+n)`, including
  the bare-base case `f · f^n → f^(n+1)` and the inverse-pair case
  `f · f^(−1) → 1`
- *double negation* — `−(−f) → f`, `−num → num(-num)`
- *sign propagation* — `(−1) · f → −f`, `f · (−g) → −(f·g)`,
  `(−f) · g → −(f·g)`

Cancellation is detected up to commutativity (so `a·b − b·a → 0`)
because the operands are sorted by `canonicalise` before comparison.
Pair-cancellation across flattened chains is also handled, so
`a + b − a → b`, `((a+b)·c + d) − (d + c·(b+a)) → 0`, and
`(a·b·c) / (a·c) → b` all reduce.

`simplify` is local: it does *not* apply distributivity
(`a·(b+c) → a·b + a·c`), expand integer powers of sums
(`(a+b)² → a² + 2ab + b²`), or combine over a common denominator
(`a/b + c/b → (a+c)/b`). For those, use `expand` and `factor` below.

The output preserves canonical form. The MVP `check_factor` becomes
substantially tighter when applied to a simplified tree: cases that
previously slipped through (e.g. `w/w − ω`) now correctly report `w`
as absent because `w/w` is folded to `1`.

#### `t.expand()`

Distribute multiplication over addition and apply the multinomial
theorem to integer powers of sums:

- `a · (b + c) → a·b + a·c`
- `(a + b) · (c + d) → a·c + a·d + b·c + b·d`
- `(a₁ + … + a_k)^n` is expanded directly via the multinomial theorem,
  emitting only the distinct terms with their coefficients — no costly
  collect-like-terms pass afterwards. Examples:
    - `(a+b)² → a² + 2·a·b + b²`
    - `(a+b)³ → a³ + 3·a²·b + 3·a·b² + b³`
    - `(a+b+c)² → a² + b² + c² + 2·a·b + 2·a·c + 2·b·c`
    - `(a+b+c)³` produces 10 terms including the `6·a·b·c` mixed term.

Tree size grows: a product of `k` `+` chains of size `m_i` expands to
a sum of `∏ m_i` terms; an `n`-th power of a `k`-term sum expands to
`C(n+k-1, k-1)` distinct terms. Use deliberately on equations where
the expanded form makes pair-cancellation, factoring, or symbolic
differentiation easier to read. Idempotent on already-expanded inputs.

#### `t.factor()`

Extract a common multiplicative factor from a sum:

- `a·b + a·c → a · (b + c)`
- `a/b + c/b → (a + c) / b`
- `2·a·b − 2·a·c → 2·a · (b − c)`

Both structural common factors and numeric GCDs are pulled out:

- `2·a·b + 2·a·c → 2·a · (b + c)`
- `2·a·b − 2·a·c → 2·a · (b − c)`
- `4·a·b + 6·a·c → 2·a · (2·b + 3·c)`
- `6·x + 9·y → 3 · (2·x + 3·y)`

The numeric GCD pass only fires when every decomposed coefficient is
integer-valued; otherwise the coefficient factor stays at 1. The
factor analysis still does not reason about power identities, so
`a² + a³` is not factored to `a² · (1 + a)` — that's a deferred
extension. Tree size shrinks (or stays the same). Idempotent.

#### `t.substitute(target_name, replacement[, parameter_names])`

Return a new tree in which every `sym(target_name)` and every
`tsym(target_name, _)` is replaced by `replacement`. `replacement` can
be an `ast` or a string (auto-parsed). The match is exact (whole symbol
nodes — no substring traps), and precedence is preserved by
construction: substituting `x` by `y+z` in `a*x^2` correctly yields
`a*(y+z)^2`, fixing the precedence bug of the existing `strrep`-based
`subs` in `modBuilder`.

The substitution is lag-aware: a `tsym(target_name, k)` match inlines
the *replacement shifted by `k`*. So substituting `mc` by `w/mpl` into
`pi - beta*mc(-1)` produces `pi - beta*(w(-1)/mpl(-1))`. Pass
`parameter_names` (a cell array of names that are time-invariant) as
the optional fourth argument to keep parameters in the replacement
unshifted: substituting `mc` by `theta*w/mpl` with
`parameter_names = {'theta'}` produces `theta*w(-1)/mpl(-1)` rather
than `theta(-1)*w(-1)/mpl(-1)`. The AST treats `parameter_names` as an
opaque "do not shift" set; it does not need to know what a parameter
is, only which names are time-invariant for this call. `STEADY_STATE`
leaves are time-invariant as well and are never shifted.

#### `t.shift_lag(k[, parameter_names])`

Return a new tree with every time-varying variable's lag shifted by
`k` (positive for a lead, negative for a lag). A `sym(name)` becomes a
`tsym(name, k)`; an existing `tsym(name, lag)` becomes
`tsym(name, lag + k)`; the result collapses back to a `sym` whenever
the total lag reaches 0. Names listed in `parameter_names` are kept
untouched, as are `num` and `ss` leaves. `k = 0` is a no-op.

This is used internally by `substitute` for lag-aware replacement and
is exposed because the same primitive is needed by other passes (e.g.
log-linearisation, generation of static / dynamic equations).

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
