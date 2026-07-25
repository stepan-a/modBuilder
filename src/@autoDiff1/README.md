# autoDiff1

Forward-mode automatic differentiation for scalar functions `f : R → R`.

## Overview

`autoDiff1` is a **dual-number** class. A dual number carries a value and its
first derivative as one object,

```
    a = (x, dx)   modelling   x + dx·ε   with   ε² = 0,
```

and the arithmetic is overloaded so that every operation propagates the
derivative alongside the value by the chain rule. Evaluating an expression on a
dual number therefore returns the value **and** the exact derivative in a single
pass — no finite differences, no symbolic tree.

It is the differentiation engine behind the numerical solvers: `solvers.newton`
seeds the unknown as a dual number and reads the Newton step off the propagated
derivative, and `modBuilder.solve_system` (with the default `Method='ad'`) builds
each Jacobian column the same way. Because it also underlies `ast.eval` under
`Method='ad'`, its function coverage is kept in step with `ast.diff_ast`: the two
must agree on every rule, including the sub-gradient conventions at kinks.

`autoDiff1` is a **value class**: every operation returns a new dual number.

## The seed convention

A dual number is created with the value and, optionally, its derivative:

```matlab
a = autoDiff1(3, 1);     % x = 3, dx = 1
a = autoDiff1(3);        % x = 3, dx = 1   (seed: the derivative w.r.t. itself)
```

The one-argument form seeds `dx = 1`, i.e. *the derivative of the variable with
respect to itself*. To differentiate `g(x)` at `x₀`, evaluate `g(autoDiff1(x₀))`
and read the `.dx` of the result. A **constant** carries `dx = 0`; the promotion
helper `autoDiff1.convert` wraps any plain number that meets a dual number in a
binary operation as `(value, 0)`, so mixed expressions like `2*a + 1` just work.

For a **partial** derivative in a multivariate setting, seed one variable with
`dx = 1` and the others with `dx = 0`; the result's `.dx` is the partial w.r.t.
the seeded variable. This is exactly how `solve_system` fills one Jacobian
column per pass.

```matlab
g  = @(z) z^2 + 3*z;
r  = g(autoDiff1(2));
r.x    % 10   = g(2)
r.dx   % 7    = g'(2) = 2·2 + 3
```

## Scope and caveats

- **Scalar only** (`f : R → R`). The class models one value and one derivative;
  it is not a vector/matrix AD type.
- Only the **scalar** operators `*`, `/`, `^` are overloaded (`mtimes`,
  `mrdivide`, `mpower`) — *not* the element-wise `.*`, `./`, `.^`. Equation
  strings built through `ast` use the scalar operators, so this matches the
  intended use; hand-written expressions must avoid the dotted forms.
- **Domain guards throw.** `log`, `sqrt`, `asin`, `tan`, … validate their
  argument and raise a structured `autoDiff1:<fn>:<reason>` error off the domain
  (e.g. `log` of a non-positive number, `tan` near an asymptote). A base that is
  non-positive under a differentiable exponent (`a^v`, `u^v`) also errors, since
  the derivative would need `log(base)`.
- **Non-finite derivatives are not errors here.** Where the value is defined but
  the derivative diverges (`sqrt` at 0, `asin` at ±1), the method returns an
  `Inf`/`NaN` derivative; the Newton solvers catch a non-finite derivative on the
  next iteration and report it through their `flag`.

## Overloaded operations

**Arithmetic** — `plus` `minus` `mtimes` `mrdivide` `mpower` `uminus` `uplus`.
`mpower` special-cases `x^0 → (1, 0)` (the general rule `p·dx·x^(p-1)` is the
indeterminate `0·Inf` at `x = 0`) and branches on which of base/exponent is
differentiable.

**Comparison** — `lt` `le` `gt` `ge`, comparing the *values* only. They exist so
that expressions containing a branch or a line-search test evaluate on dual
numbers; the boolean they return carries no derivative.

**Elementary functions** — the 24 functions `ast.diff_ast` also differentiates:

| group | functions |
|-------|-----------|
| exp / log | `exp`, `log`, `ln` (alias of `log`), `log10` |
| roots | `sqrt`, `cbrt` |
| trigonometric | `sin`, `cos`, `tan`, `asin`, `acos`, `atan` |
| hyperbolic | `sinh`, `cosh`, `tanh`, `asinh`, `acosh`, `atanh` |
| statistics | `normcdf`, `normpdf`, `erf`, `erfc` |
| non-smooth | `abs`, `sign`, `min`, `max` |

`normcdf`/`normpdf` are computed *through the overloaded arithmetic*
(`0.5·erfc(-z/√2)` and the density formula), so the dual number may sit in any of
the three argument slots — value, mean or standard deviation — and the derivative
is correct in each case.

## Sub-gradients at kinks

`abs`, `sign`, `min`, `max` are non-differentiable at a kink or tie. The class
returns a **finite sub-gradient** there, chosen to agree with Dynare's
`sign(0) = 0` and, crucially, with `ast.diff_ast` — the symbolic and the AD paths
must produce the same number so `Method='auto'` can switch between them freely.

- `sign(x)' = 0` everywhere it is defined, and the sub-gradient `(0, 0)` at the
  jump; `abs(x)' = sign(x)·dx`, so `abs' = 0` at `x = 0`.
- `max(u, v)` and `min(u, v)` follow the identity
  `max(u,v) = (u + v + |u−v|)/2`: away from the tie they pick the active branch's
  derivative; at `u = v` they return the **averaged** sub-gradient
  `(dx_u + dx_v)/2`.

A finite value at the kink also keeps a Newton iterate that lands exactly on it
from aborting the solve.

## Consumers

- **`solvers.newton`** — univariate Newton: seeds `autoDiff1(x0)` and reads the
  step `-r.x / r.dx` off the propagated derivative.
- **`modBuilder.solve_system`** (`Method='ad'`, the default) — builds each
  Jacobian column by seeding one variable with `dx = 1`.
- **`ast.eval`** (`Method='ad'`) — evaluates an equation's residual on dual
  numbers; the fallback when `ast.diff_ast` has no rule for an operator (the Dynare
  time-series operators).

See also `../@ast/README.md` (the `diff_ast` symbolic path this mirrors) and
`../+solvers/README.md` (the Newton solvers that drive it).
