# ast

Abstract syntax tree for `modBuilder` equations.

## Overview

The `ast` class parses an equation string into a tree of typed nodes that
can be inspected, transformed, and rendered back to a string. It is used
to provide a basis for symbolic operations on equations — static
reduction, substitution, renaming, numeric evaluation, differentiation,
LaTeX rendering — that other modules can layer on top of the same tree.
Concrete consumers in `modBuilder` include `matchequations` (uses
`staticise().simplify().check_factor` as the static-cancellation
filter), `subs` (dispatches to `substitute` for symbol targets and
`replace_subtree` for expression targets), `rename` (uses `rename` to
swap symbol names preserving lag and steady-state wrapping), and
`evaluate` (uses `eval` to compute residuals from current
calibrations).

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

#### `t.replace_subtree(target, replacement)`

Return a new tree with every subtree structurally equal to `target`
replaced by `replacement`. Both `target` and the host tree are
canonicalised at entry, so commutative reorderings (`a*b` vs `b*a`,
`a+b` vs `b+a`) match. Replacement is literal — no lag-shift, no
parameter set — so this is the right primitive when the target is an
arbitrary expression rather than a single symbol.

This is the structural counterpart of `substitute`: use `substitute`
when the target is a symbol you want to rewrite at every lead/lag
(with the replacement shifted accordingly), and `replace_subtree` when
the target is a specific expression you want to recognise wherever it
appears, exactly as written. Used by `modBuilder.subs` for
expression targets.

The MVP does not perform sub-multiset matching, so a target `a + c`
is *not* found inside `a + b + c` (whose canonical left-associated tree
exposes `(a+b)` and `c`, not `(a+c)`). When that's needed, the
`simplify` or `factor` passes can sometimes reshape the equation to
make the desired subtree appear.

#### `t.rename(oldname, newname)`

Return a new tree with every reference to `oldname` renamed to
`newname`. Matches `sym(oldname) → sym(newname)`, `tsym(oldname, k) →
tsym(newname, k)` (lag preserved) and `ss(oldname) → ss(newname)`
(steady-state wrapping preserved). Function-call names (e.g. `exp`,
`log`) are not touched.

This is distinct from `substitute`: `substitute` replaces the whole
symbol node with an arbitrary subtree (and lag-shifts the replacement);
`rename` only swaps a name. `rename` is the right tool when the user
wants to relabel a variable everywhere it appears. Used by
`modBuilder.rename`.

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

#### `t.eval(values)`

Evaluate the tree numerically. `values` is a struct with one field per
symbol; `values.(name)` is the scalar substituted for any `sym`,
`tsym` or `ss` node carrying that name. Returns a `double`.

- `tsym(name, k)` resolves to `values.(name)` — the lag is ignored.
  Caller is responsible for staticising first if a different
  semantics is wanted.
- `ss(name)` also resolves to `values.(name)`: `STEADY_STATE(x)` and
  the static value of `x` are identical when `values` carries
  steady-state calibrations.
- `call` nodes dispatch via `feval`; the function name has already
  been validated by the parser against `ast.RESERVED_FNAMES`.
- A symbol with no entry in `values` raises `ast:eval` with a clear
  message — distinct from MATLAB's generic "undefined variable" from
  the legacy `eval`-based path.

Used by `modBuilder.evaluate` to compute LHS, RHS and residual of a
static equation under the current calibration.

#### `t.diff_ast(target_name)`

Symbolic derivative of the tree with respect to a symbol, returned as a
simplified `ast`:

```matlab
ast('alpha*K^alpha').diff_ast('K')   % alpha^2 * K^(alpha-1)
```

- Differentiation is **period-specific**: only bare `sym` nodes whose
  name equals `target_name` carry a non-zero derivative. A `tsym`
  lead/lag such as `K(-1)` is an independent variable, so
  `ast('K(-1)').diff_ast('K')` is `0`. Call `staticise()` first for
  steady-state (all-periods) semantics.
- `ss` nodes (`STEADY_STATE(x)`) are constants and differentiate to `0`.
- The result is passed through `simplify()` before returning. Higher-order
  and mixed partials chain: `t.diff_ast('x').diff_ast('y')`.
- The `^` rule branches on which of base/exponent depends on the target
  (`u^n`, `a^v`, general `u^v`). Functions are handled by the chain rule.
- 24 functions have rules: `log`/`ln`, `log10`, `exp`, `sqrt`, `cbrt`,
  the six trig and six hyperbolic functions and their inverses,
  `normcdf`, `normpdf`, `erf`, plus `abs`, `sign`, `min` and `max`
  following the `autoDiff1` sub-gradient conventions: `abs(u)' =
  sign(u)·u'`, `sign(u)' = 0`, and `min`/`max` via the identity
  `max(u,v) = (u+v+|u−v|)/2` (so `max(u,v)' = (u'+v')/2 +
  sign(u−v)·(u'−v')/2`, averaged sub-gradient at the tie `u=v`). Only the
  Dynare time-series operators `diff`, `adl` and `EXPECTATIONS` lack a
  pointwise derivative and raise `ast:diff_ast:noRule` — the signal for a
  `Method='auto'` solver path to fall back to automatic differentiation
  (`autoDiff1`).

Tested in `tests/ast/t24` (structural cases plus an `autoDiff1`
cross-check at several points for every rule) and `tests/ast/t25`
(the `noRule` path).

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
