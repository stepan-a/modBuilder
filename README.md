# modBuilder

[![GitLab CI](https://git.dynare.org/Dynare/modBuilder/badges/master/pipeline.svg?key_text=GitLab%20CI&key_width=62)](https://git.dynare.org/Dynare/modBuilder/-/commits/master)
[![MATLAB Tests](https://github.com/stepan-a/modBuilder/actions/workflows/tests.yml/badge.svg)](https://github.com/stepan-a/modBuilder/actions/workflows/tests.yml)
[![coverage](https://raw.githubusercontent.com/stepan-a/modBuilder/coverage-badge/badge.svg)](https://github.com/stepan-a/modBuilder/actions/workflows/tests.yml)
[![Documentation](https://img.shields.io/badge/slides-PDF-blue)](https://git.dynare.org/Dynare/modBuilder/-/jobs/artifacts/master/raw/doc/slides.pdf?job=doc)

A MATLAB class for programmatically creating and manipulating Dynare `.mod` files.

## Overview

`modBuilder` simplifies the interactive and programmatic creation of Dynare model files, the aim is to provide a complete programmatic API for building, inspecting, and manipulating DSGE models. It enables incremental model development by allowing users to define parameters, endogenous/exogenous variables, and equations directly from the MATLAB environment. The class also provides helpers for steady-state computation (`solve`, `evaluate`). Because models are defined as plain MATLAB scripts, an arbitrary number of model variants sharing a common core of equations can be developed side by side in the same script, and the whole workflow is easily versioned with Git.

### Equation–Variable Association

Each equation in a modBuilder model is explicitly associated with one endogenous variable by the user. When calling `add('y', 'y = c + i')`, the first argument names both the endogenous variable and the equation. This association is a modelling choice — it does not affect the `.mod` file that Dynare sees, since Dynare solves the full system simultaneously. However, it gives modBuilder a structure to work with:

- **Targeted modifications**: Operations like `change`, `remove`, `flip`, `rmflip`, and `reassign` refer to equations by their associated variable name, making it easy to identify and manipulate individual equations in large models.
- **Automatic bookkeeping**: When an equation is removed, modBuilder knows which endogenous variable loses its defining equation and can reclassify it (e.g. convert it to exogenous if it still appears elsewhere). This default behaviour can be overridden with `rmflip` or `exogenise`, which let you choose a different variable to exogenise instead.
- **Submodel extraction**: `extract` and `select` pull out subsets of equations together with the correct variable declarations, because the association tells modBuilder which variables are determined by which equations.

### Key Features

- **Interactive Model Building**: Add and modify equations incrementally
- **Symbol Table Management**: Automatic tracking of symbol usage across equations
- **Type System**: Classify symbols as parameters, endogenous, or exogenous variables
- **Consistency Checking**: Validates that each endogenous variable has exactly one equation
- **Regex Support**: Search for symbols using regular expressions
- **Model Operations**: Copy, merge, extract submodels, and more
- **Symbolic Differentiation**: Analytical partial derivatives and Jacobians via an AST engine (`partial`, `symbolic_jacobian`)
- **Optimal-Policy FOCs**: Derive the first-order conditions of a recursive optimisation and grow the model into the (square) planner problem (`lagrangian_foc`, `ramsey_foc`, `augment`); substitute auxiliary variables back out symbolically (`eliminate`)
- **Dynare Export**: Generate syntactically valid `.mod` files ready for simulation
- **LaTeX Export**: Render the model, its steady-state system (flat or as a recursively-ordered block plan), and its log-linearisation as paper-ready LaTeX (`tex_model`, `tex_steady_state_system`, `tex_steady_state_plan`, `tex_linearise`)

## Quick Start

```matlab
% Create a new model
m = modBuilder();

% Add equations (automatically declares 'y' as endogenous)
m.add('y', 'y = c + i + g');
m.add('c', 'c = (1-s)*y');
m.add('i', 'i = s*k(-1)^alpha');

% Declare parameters with calibration values
m.parameter('alpha', 0.33);
m.parameter('s', 0.20);

% Declare exogenous variables
m.exogenous('g', 0);

% Display model summary
m.summary();

% Export to Dynare .mod file
m.write('my_model');
```

## Installation

Requires **MATLAB R2023a** or later (uses `combinations`).

Add the `src` directory to your MATLAB path, then run the setup helper:

```matlab
addpath('/path/to/modBuilder/src');
modBuilder_setup();
```

`modBuilder_setup` is idempotent. It also puts `src/missing/math/` on the
path unconditionally (Dynare-style aliases such as `ln`, which MATLAB does
not ship in any toolbox) and `src/missing/stats/` only when the Statistics
Toolbox is unavailable (so a licensed install keeps using the canonical
`normcdf`/`normpdf`).

For a permanent install, either keep both lines in your `startup.m`, or
use MATLAB's `Set Path` dialog to add `src`, `src/missing/math`, and —
only if you don't have the Statistics Toolbox — `src/missing/stats`.

## Public Methods

### Constructor

#### `modBuilder([datetime_obj | M_, oo_, jsonfile[, tag]])`

Create a new modBuilder object.

**Usage:**

```matlab
% Create empty model
m = modBuilder();

% Create model with specific date
m = modBuilder(datetime('2024-01-15'));

% Load from Dynare structures and JSON file
m = modBuilder(M_, oo_, 'equations.json');

% Load with custom equation tag name
m = modBuilder(M_, oo_, 'equations.json', 'custom_name');
```

**Arguments:**
- No arguments: Creates empty model with current date
- `datetime_obj`: Creates empty model with specified date
- `M_`: Dynare model structure (from previous simulation)
- `oo_`: Dynare output structure
- `jsonfile`: Path to JSON file with equations
- `tag` (optional): Custom equation tag name (default: 'name')

**Returns:**
- New `modBuilder` object

**Equation–variable association at load time:**

Each equation must be associated with a unique endogenous variable. Equations whose tag is missing or does not match an endogenous variable are matched automatically against the still-available endogenous variables using a bipartite-matching algorithm (`matchpairs`, with stable tie-breakers favoring a variable that appears on the LHS of the equation). The constructor only fails when no perfect matching exists, in which case the error spells out the unmatched equations and unmatched variables. When auto-matching fires, a `modBuilder:autoMatch` warning lists the proposed (equation, variable) pairs; suppress it with `warning('off', 'modBuilder:autoMatch')` if needed.

Auto-matching combines a textual occurrence check with a symbolic filter: a candidate variable is admitted as a possible match for an equation only if it appears textually AND does not cancel out of the static reduction of that equation. The cancellation check is delegated to [`ast.check_factor`](src/@ast/README.md), which recognises multiplicative-factor cancellations (e.g. λ in `λ·R·τ − λ·τ`) but is conservative on cases that need algebraic simplification (e.g. `w/w − ω`).

### Model Building

#### `add(varname, equation[, indices])`

Add an equation and declare the variable as endogenous.

**Arguments:**
- `varname` - Name of the endogenous variable
- `equation` - Equation string (can include lags/leads with parentheses)
- `indices` (optional) - Cell array for implicit loops

**Examples:**

```matlab
% Simple equation
m.add('c', 'c = w*h');

% Equation with lags and leads
m.add('k', 'k = (1-delta)*k(-1) + i');
m.add('r', '1/beta = (c/c(+1))*(r(+1)+1-delta)');

% Implicit loops - creates x_1, x_2, x_3
m.add('x_$1', 'x_$1 = alpha_$1 * y', {1, 2, 3});
```

#### `parameter(pname, value[, long_name[, tex_name]])`

Declare a parameter with optional calibration value and labels.

**Examples:**

```matlab
% Simple parameter
m.parameter('alpha', 0.33);

% With long name and LaTeX
m.parameter('beta', 0.99, 'Discount factor', '\beta');

% Multiple parameters with implicit loops
m.parameter('rho_$1', 0.9, '', '', {1, 2, 3});
```

#### `exogenous(xname, value[, long_name[, tex_name]])`

Declare an exogenous variable.

**Examples:**

```matlab
m.exogenous('e', 0);
m.exogenous('epsilon', 0, 'Technology shock', '\epsilon');
```

#### `endogenous(ename, value[, long_name[, tex_name]])`

Explicitly declare an endogenous variable (usually declared via `add()`).

```matlab
m.endogenous('y', [], 'Output', 'Y');
```

#### `steady(varname, expression[, indices])`

Define an analytical steady-state expression for an endogenous variable or parameter. Expressions generate a Dynare `steady_state_model` block in the exported `.mod` file when `write()` is called with `steady_state_model=true`.

**Arguments:**
- `varname` — Name of an endogenous variable or parameter
- `expression` — RHS expression string
- `indices` (optional) — Cell arrays for implicit loops

**Examples:**

```matlab
% Define steady-state expressions
m.steady('k', '(alpha*beta/(1-beta*(1-delta)))^(1/(1-alpha))');
m.steady('y', 'k^alpha');
m.steady('c', 'y - delta*k');

% Parameter computed from steady-state values
m.steady('labor_share', '1 - alpha*y/k');

% Implicit loops
m.steady('Y_$1', 'A_$1*K_$1', {1, 2, 3});

% Replacing an existing expression (preserves row position)
m.steady('y', 'alpha*k');
```

#### `checksteady()`

Validate steady-state expressions and return symbol names in topological (dependency) order. Called automatically by `write()` when `steady_state_model=true`.

**Returns:**
- Cell array of symbol names ordered so that each expression is evaluated after its dependencies

**Errors on:**
- Unknown symbols in expressions
- Circular dependencies between expressions

```matlab
sorted = m.checksteady();
% Returns e.g. {'k', 'y', 'c'} — k first because y and c depend on it
```

### Model Modification

#### `change(varname, equation)`

Replace an existing equation.

**Example:**

```matlab
m.change('c', 'c = 0.8*w*h');  % Replace consumption equation
```

#### `remove(eqname)` / `rm(eqname1, ...)`

Remove one or more equations.

**Examples:**

```matlab
m.remove('old_equation');
m.rm('eq1', 'eq2', 'eq3');  % Remove multiple equations
```

#### `rename(oldsymbol, newsymbol)`

Rename a symbol throughout the model.

**Example:**

```matlab
m.rename('alpha', 'labor_share');
m.rename('k', 'capital');
```

#### `flip(varname, varexoname)`

Swap an endogenous and exogenous variable (useful for calibration).

**Example:**

```matlab
% Flip to solve for parameter given target
m.flip('k_ss', 'delta');  % Make k_ss exogenous, delta endogenous
m.solve('delta', 'delta', 0.025);  % Solve for delta
m.flip('k_ss', 'delta');  % Flip back
```

#### `reassign(v1, v2[, v3, ...])`

Cycle the associations between equations and endogenous variables using cycle notation. With two arguments, swaps the equation associations. With three or more, performs a circular permutation: v1's equation moves to v2, v2's to v3, ..., and the last variable's equation moves to v1.

**Examples:**

```matlab
% Swap two equation associations
m.reassign('y', 'k');  % y gets k's equation, k gets y's equation

% Three-way cycle
m.reassign('a', 'b', 'c');  % a gets c's eq, b gets a's eq, c gets b's eq
```

#### `rmflip(eqname, newexo[, indices])`

Remove an equation and exogenise a different variable instead. Removes equation `eqname`, keeps its associated variable endogenous (by reassigning it to `newexo`'s former equation), and makes `newexo` exogenous.

**Arguments:**
- `eqname` — Name of the equation to remove
- `newexo` — Endogenous variable to make exogenous (must appear in `eqname`'s variable's usage)
- `indices` (optional) — Cell arrays for implicit loops

**Example:**

```matlab
m = modBuilder();
m.add('y', 'y = a*k');
m.add('k', 'k = (1-delta)*k(-1) + i + y');
m.parameter('a', 0.33);
m.parameter('delta', 0.025);
m.exogenous('i', 0);

% Remove y's equation, make k exogenous instead
m.rmflip('y', 'k');
% y stays endogenous (determined by k's former equation), k becomes exogenous
```

#### `exogenise(varname, eqname[, indices])`

Make an endogenous variable exogenous by dropping an equation. Variable-centric interface to `rmflip`: makes `varname` exogenous by removing equation `eqname`.

**Arguments:**
- `varname` — Endogenous variable to make exogenous
- `eqname` — Equation to remove
- `indices` (optional) — Cell arrays for implicit loops

**Example:**

```matlab
% Equivalent to m.rmflip('y', 'k')
m.exogenise('k', 'y');
```

#### `subs(expr1, expr2[, eqname][, idx1, ...])`

Replace `expr1` by `expr2` in one or all equations, using AST-based substitution. Both `expr1` and `expr2` are arbitrary expressions; either can reduce to a single symbol. Built on the [`ast`](src/@ast/README.md) class, so the substitution is exact (whole nodes, no substring traps) and precedence-safe by construction.

The matching mode is chosen by the structure of `expr1`:

- *expr1 is a single symbol* (`a`, `beta`, `mc`, …) — the lag-aware `ast.substitute` primitive is used: every occurrence (at any lead/lag) is matched, and the replacement is shifted accordingly. Names declared as parameters in the model are kept time-invariant during the shift.
- *expr1 is any other expression* (`alpha + beta`, `x*y`, `mc(-1)`, `STEADY_STATE(K)`, …) — the structural `ast.replace_subtree` primitive is used: the parsed `expr1` is matched as a whole subtree, after canonicalisation so commutative reorderings (`a*b` vs `b*a`, `a+b` vs `b+a`) still match. The replacement `expr2` is inlined as written — no lag-shift.

Parameters and exogenous variables that no longer appear anywhere after the substitution are removed automatically. Indexed substitutions are expressed via `$` placeholders in `expr1`, `expr2`, and (optionally) `eqname`, with index value arrays passed after them. Regular-expression matching on the equation text is *not* supported here — use [`substitute`](#substituteexpr1-expr2-eqname) when a true text-level regex is needed.

**Examples:**

```matlab
% Replace a parameter by its calibration value across all equations
m.subs('alpha', '0.33');

% Replace a defining variable: pi = beta*mc(-1) with mc = w/mpl becomes
%   pi = beta*(w(-1)/mpl(-1))
% (then drop the now-tautological defining equation if desired)
m.subs('mc', 'w/mpl');
m.remove('mc');

% Replace only into a specific equation
m.subs('alpha', '0.33', 'y');

% Replace an expression by another expression
m.subs('alpha + beta', 'sigma');
m.subs('a*b + c*d', 'rho');

% Implicit loop: replace alpha_i by 0.33 for i in {1, 2, 3}
m.subs('alpha_$1', '0.33', {1, 2, 3});

% Implicit loop with shared index between expr1, expr2 and eqname
m.subs('alpha_$1', 'beta_$1', 'Y_$1', {1, 2, 3});

% Disjoint indices: replace a global mc into per-sector equations Y_1, Y_2
m.subs('mc', 'w/mpl', 'Y_$1', {1, 2});

% Two-index expansion (Cartesian product over the index value arrays)
m.subs('alpha_$1_$2', 'beta_$1_$2', {'FR', 'DE'}, {1, 2});
```

#### `substitute(expr1, expr2[, eqname])`

Substitute an expression in equations using regular expression pattern matching (via `regexprep` on the equation text). Same interface as `subs()`, but `expr1` is interpreted as a regex pattern rather than a parsed expression. When `expr1` is a single symbol identifier, a `modBuilder:preferSubs` warning is emitted recommending the AST-based `subs` (precedence-safe, lag-aware). Suppress with `warning('off', 'modBuilder:preferSubs')` if needed.

**Examples:**

```matlab
% Replace any coefficient followed by *y with z
m.substitute('[\w]+\*y', 'z', 'consumption_eq');

% With implicit loops
m.substitute('x_$1', 'y_$1 + z_$1', 'equation_$1', {1, 2, 3});
```

#### `eliminate(varname)`

Eliminate an endogenous variable: solve its own equation for it (with the AST's symbolic `isolate`), substitute the result into every equation (lag-aware, so a lead/lag picks up the shifted expression), and remove the now-redundant defining equation and the variable, keeping the model square. Only an **endogenous** variable can be eliminated — a parameter, exogenous variable, or unknown symbol raises `modBuilder:eliminate:notEndogenous`; a variable that `isolate` cannot solve in closed form raises `modBuilder:eliminate:notClosedForm` (fall back to `subs` by hand). This packages the `isolate → subs → remove` composition; a common use is substituting an `augment` multiplier back out to recover a textbook condition.

**Example:**

```matlab
r = m.lagrangian_foc('W', {'k'}, {'c', 'k'});
m.augment(r);
m.eliminate('mult_1');   % isolate mult_1 = 1/c, substitute throughout, drop the equation
```

#### `tag(eqname, tagname, value)`

Add metadata tags to equations.

**Example:**

```matlab
m.tag('consumption', 'name', 'Euler equation');
m.tag('consumption', 'mcp', 'c > 0');  % Mixed complementarity
```

### Model Inspection

#### `typeof(name)`

Get the type and index of a symbol.

**Example:**

```matlab
[type, id] = m.typeof('alpha');
% Returns: type = 'parameter', id = 1
```

#### `isparameter(name)` / `isexogenous(name)` / `isendogenous(name)`

Check symbol type.

**Examples:**

```matlab
if m.isparameter('alpha')
    fprintf('alpha is a parameter\n');
end
```

#### `issymbol(name)`

Check if a name is a known symbol (parameter, endogenous, or exogenous variable).

**Example:**

```matlab
if m.issymbol('alpha')
    fprintf('alpha is a known symbol\n');
end
```

#### `lookfor(name)`

Display all equations containing a symbol. Supports regular expressions.

**Examples:**

```matlab
% Exact match
m.lookfor('alpha');

% Regex patterns (auto-detected)
m.lookfor('beta_.*');      % All symbols starting with beta_
m.lookfor('theta_\d+');    % theta_1, theta_2, etc.
m.lookfor('^rho');         % Symbols starting with rho
m.lookfor('_shock$');      % Symbols ending with _shock
```

#### `evaluate(eqname[, printflag])`

Evaluate an equation with current calibration values.

**Example:**

```matlab
% Evaluate and display
result = m.evaluate('consumption', true);

% Evaluate silently
result = m.evaluate('consumption');
```

#### `summary()`

Display a formatted summary of the model.

**Example:**

```matlab
m.summary();
% Output:
%   Model Summary
%   =============
%   Parameters:     7
%   Endogenous:    10
%   Exogenous:      2
%   Equations:     10
```

#### `table(type)`

Get a formatted table of symbols.

**Examples:**

```matlab
% Get parameter table
param_table = m.table('parameters');
disp(param_table);

% Get variable tables
var_table = m.table('endogenous');
varexo_table = m.table('exogenous');
```

#### `equationmap()`

Display or return the mapping between endogenous variables and equations as a two-column table (`Endogenous`, `Equation`). When called without an output argument the table is printed to the console; when called with an output argument the table is returned silently.

**Examples:**

```matlab
% Print the mapping
m.equationmap();

% Get the mapping as a MATLAB table
t = m.equationmap();
disp(t);
```

#### `size(type)`

Get the number of symbols of a given type.

**Example:**

```matlab
n_params = m.size('parameters');
n_vars = m.size('endogenous');
n_eqs = m.size('equations');
```

#### `getallsymbols()`

Return a cell array of all symbols appearing in the model equations.

**Example:**

```matlab
symbols = m.getallsymbols();
% Returns {'alpha', 'c', 'e', 'k', 'y', ...}
```

#### `listeqbytag(tagname, tagvalue, ...)`

Return a list of equation names matching tag criteria. Tag values are interpreted as regular expressions (anchored with `^` and `$`). When multiple name-value pairs are given, all criteria must be satisfied (AND logic).

**Examples:**

```matlab
% Tag some equations
m.tag('Y_m', 'sector', 'manufacturing');
m.tag('Y_s', 'sector', 'services');
m.tag('Y_m', 'type', 'production');
m.tag('Y_s', 'type', 'production');

% Exact match
eqs = m.listeqbytag('sector', 'manufacturing');
% Returns {'Y_m'}

% Regex match
eqs = m.listeqbytag('sector', 'manuf.*');
% Returns {'Y_m'}

% Multiple criteria (AND)
eqs = m.listeqbytag('sector', 'manufacturing', 'type', 'production');
% Returns {'Y_m'}

% Match several values with alternation
eqs = m.listeqbytag('type', 'production|accumulation');
```

### Model Operations

#### `write(filename[, options])`

Export model to a Dynare `.mod` file.

**Arguments:**
- `filename` — Output file name (with or without `.mod` extension)

**Options (name-value):**
- `initval` — Include an `initval` block with initial values for endogenous variables (default: `false`)
- `steady` — Call `steady` after the initval block (default: `false`). A warning is issued if `initval` is `false` and `steady_state_model` is `false`.
- `steady_state_model` — Include a `steady_state_model` block with analytical expressions defined via the `steady()` method (default: `false`). Expressions are automatically sorted in dependency order.
- `steady_options` — Options for the `steady` command as a cell array of key-value pairs and flags, e.g. `{'maxit', 100, 'nocheck'}` (default: `{}`)
- `check` — Call `check` after `steady` (default: `false`). An error is thrown if `steady` is `false`.
- `precision` — Number of significant digits for numerical values (default: 6 decimal places)

**Examples:**

```matlab
% Basic export
m.write('my_model.mod');

% Without extension (automatically appends .mod)
m.write('my_model');

% With higher precision (15 significant digits)
m.write('my_model.mod', precision=15);

% With initval block
m.write('my_model.mod', initval=true);

% With initval, steady, and check
m.write('my_model.mod', initval=true, steady=true, check=true);

% With steady options
m.write('my_model.mod', initval=true, steady=true, steady_options={'maxit', 100, 'nocheck'});

% With steady_state_model block
m.write('my_model.mod', steady_state_model=true);

% Combine options
m.write('my_model.mod', initval=true, precision=10);
```

#### `copy()`

Create a deep copy of the model.

**Example:**

```matlab
m2 = m.copy();
m2.change('c', 'c = new_equation');  % Doesn't affect m
```

#### `eq(other_model)` (overloads `==`)

Test equality of two modBuilder objects. Compares names, values, equations, tags, and symbol tables. The order of elements does not matter. Note that `long_name` and `tex_name` attributes are not compared: two models differing only in these metadata are considered equal.

**Example:**

```matlab
m2 = m.copy();
m == m2        % Returns true

m2.parameter('alpha', 0.5);
m == m2        % Returns false
```

#### `extract(eqname1, ...)`

Create a submodel with specified equations.

**Example:**

```matlab
% Extract consumption and investment blocks
submodel = m.extract('c', 'i', 'k');
```

#### `select(tagname, tagvalue, ...)`

Extract a submodel by selecting equations based on tag values. Combines `listeqbytag` and `extract`. Tag values are interpreted as regular expressions. Can also be called via curly brace indexing with a `bytag` selector (see [Indexing and Access](#indexing-and-access)).

**Examples:**

```matlab
% Select all manufacturing equations
sub = m.select('sector', 'manufacturing');

% Equivalent using bytag indexing
sub = m{bytag('sector', 'manufacturing')};

% Multiple criteria
sub = m.select('sector', 'manufacturing', 'type', 'production');
```

#### `merge(other_model)`

Merge another model into this one.

**Example:**

```matlab
% Create two separate blocks
production = modBuilder();
production.add('y', 'y = a*k^alpha*h^(1-alpha)');

consumption = modBuilder();
consumption.add('c', 'c = (1-s)*y');

% Merge them
full_model = production.copy();
full_model.merge(consumption);
```

#### `solve(eqname, sname, sinit[, tol, maxit])`

Numerically solve a single equation for one symbol using Newton's method with automatic differentiation.

**Arguments:**
- `eqname` — Name of the equation to solve
- `sname` — Symbol to solve for (parameter, endogenous, or exogenous)
- `sinit` — Initial guess
- `tol` (optional) — Convergence tolerance (default: `1e-10`)
- `maxit` (optional) — Maximum iterations (default: `100`)

**Example:**

```matlab
% Solve for steady state capital
m.solve('k_ss_eq', 'k_ss', 10);  % Initial guess = 10

% With a looser tolerance
m.solve('k_ss_eq', 'k_ss', 10, 1e-6);
```

#### `solve_system(eqnames, snames[, tol, maxit])`

Numerically solve a system of equations for multiple symbols simultaneously using Newton's method. The Jacobian is computed via automatic differentiation, exploiting the known sparsity pattern from the symbol table.

**Arguments:**
- `eqnames` — Cell array of equation names
- `snames` — Cell array of symbol names to solve for (can be any mix of parameters, endogenous, and exogenous variables)
- `tol` (optional) — Convergence tolerance (default: `1e-6`)
- `maxit` (optional) — Maximum iterations (default: `100`)

**Remarks:**
- The system must be square (same number of equations and unknowns).
- Current symbol values are used as the initial guess; all symbols being solved for must have a numeric value set beforehand.

**Examples:**

```matlab
% Solve for the RBC steady state
m = modBuilder();
m.add('k', '1/beta = alpha*y/k + (1-delta)');
m.add('y', 'y = k^alpha');
m.add('c', 'c = y - delta*k');
m.parameter('alpha', 0.36);
m.parameter('beta', 0.99);
m.parameter('delta', 0.025);
m.endogenous('k', 5);
m.endogenous('y', 1.5);
m.endogenous('c', 1);
m.solve_system({'k', 'y', 'c'}, {'k', 'y', 'c'});

% Solve for a parameter and an endogenous variable jointly
m.solve_system({'y', 'c'}, {'alpha', 'c'});

% With custom tolerance
m.solve_system({'k', 'y', 'c'}, {'k', 'y', 'c'}, 'tol', 1e-12);
```

### Symbolic Differentiation

Built on the AST engine's [`ast.diff_ast`](src/@ast/README.md).

#### `partial(eqname, varname[, Lag])`

Return the symbolic partial derivative of an equation's residual (LHS − RHS) with respect to a symbol, as a simplified `ast`.

**Arguments:**
- `eqname` — equation name
- `varname` — symbol to differentiate with respect to
- `Lag` (optional name-value) — period of the target. Omitted gives the **static** partial: the residual is staticised first, so all leads/lags of the variable aggregate (the same semantics as the AD Jacobian). `Lag = k` gives the **dynamic**, period-specific block (`Lag = 0` contemporaneous, `Lag = -1` the one-lag block, ...).

**Example:**

```matlab
m.partial('y', 'k')            % static: d(residual_y)/dk, all lags aggregated
m.partial('y', 'k', Lag=-1)    % dynamic: d(residual_y)/dk(-1)
```

#### `symbolic_jacobian(eqnames, varnames[, Lag])`

Return the matrix of symbolic partials as an `m×n` cell of `ast` objects. The matrix is sparse: structural-zero entries are stored as `[]`, so `isempty(J{i,j})` tests whether `varnames{j}` is absent from equation `i`. Same static/dynamic `Lag` semantics as `partial` (a multi-period dynamic Jacobian is one call per lag).

**Example:**

```matlab
J = m.symbolic_jacobian({'y', 'c'}, {'y', 'k', 'c'});   % static Jacobian
isempty(J{2, 2})    % structural zero?
```

### Optimal-Policy First-Order Conditions

Derive the first-order conditions Dynare does not derive on its own. The problem is written over **two periods** (a Bellman/recursive formulation), not as an infinite-sum Lagrangian.

#### `lagrangian_foc(value_eqname, constraint_eqnames, control_vars[, MultiplierPrefix, MultiplierNames])`

Derive the FOCs of a recursive optimisation. `value_eqname` is the recursive value equation (`W = u + beta*W(+1)`), `constraint_eqnames` the constraints (each gets a fresh Lagrange multiplier), and `control_vars` the variables to take FOCs with respect to. Returns a struct with fields `.multipliers`, `.controls`, `.foc` (the FOC strings `"<expr> = 0"`), `.constraints` and `.value_eqname`. Multipliers are named `mult_1, mult_2, …` by default; override with the `MultiplierPrefix` (default `'mult'`) or `MultiplierNames` name-values.

Unlike `ramsey_foc` (which treats *every* model equation as a constraint), `lagrangian_foc` lets you name exactly the constraints and controls, so `augment` adds a **targeted, smaller** set of equations — useful for a sub-problem such as a single household's optimisation or a bargaining condition. For the optimal-growth model, naming the resource constraint and the controls `c`, `k` adds one multiplier and the two FOCs (marginal utility `1/c = mult_1` and the consumption Euler):

```matlab
m.add('W', 'W = log(c) + beta*W(+1)');                     % objective
m.add('k', 'A*k(-1)^alpha + (1-delta)*k(-1) = c + k');     % resource constraint
% ... parameters beta, A, alpha, delta ...
r = m.lagrangian_foc('W', {'k'}, {'c', 'k'});   % constraints and controls chosen explicitly
% r is a struct describing the derivation (the FOCs are canonical "<expr> = 0" strings):
%   r.multipliers  = {'mult_1'}                  one multiplier (one constraint)
%   r.controls     = {'c', 'k'}
%   r.foc          = { '-mult_1 + c ^ -1 = 0', ...                         % 1/c = mult_1
%                      '-mult_1 + beta * mult_1(1) * (1 - delta + A * alpha * k ^ (-1 + alpha)) = 0' }  % Euler
%   r.constraints  = {'k'}
%   r.value_eqname = 'W'
m.augment(r);                                   % adds mult_1 and the two FOC equations
```

The multiplier is mechanical: its own equation defines `mult_1 = 1/c`, so it can be substituted out with [`eliminate`](#eliminatevarname) to recover the textbook consumption Euler:

```matlab
m.eliminate('mult_1');   % the c equation becomes 1/c = beta*(1/c(+1))*(1 - delta + A*alpha*k^(alpha-1))
% the model is now the square system in (W, k, c) — the standard optimal-growth form
```

#### `ramsey_foc(value_eqname, instrument_vars[, MultiplierPrefix, MultiplierNames])`

Ramsey (optimal-policy) specialisation of `lagrangian_foc`: every equation other than the value equation and the instruments' own rules is a constraint, and the planner optimises over the endogenous variables and the policy instruments. Same return struct.

#### `augment(result[, MultiplierTexnames])`

Grow the model **in place** into the square optimal-policy problem from a `lagrangian_foc` / `ramsey_foc` result: add the multipliers as endogenous variables (with a `\mu_{i}` texname) and the FOCs as equations, dropping an instrument's own rule and promoting the instrument so the planner sets it. Errors if a multiplier name is already taken (`modBuilder:augment:multiplierExists` — pass `MultiplierPrefix`/`MultiplierNames` to the FOC builder) or if the FOC count does not match the number of variables to determine.

**Example:**

```matlab
m.add('pi', 'pi = beta*pi(+1) + kappa*y');                 % NKPC
m.add('y',  'y = y(+1) - sigma*(i - pi(+1))');             % IS
m.add('W',  'W = -(pi^2 + lambda*y^2)/2 + beta*W(+1)');    % welfare
% ... parameters ...; m.exogenous('i', 0);                 % instrument
r = m.ramsey_foc('W', {'i'});   % derive the FOCs + multipliers
% r has the same fields; here every equation but the value equation is a constraint:
%   r.multipliers  = {'mult_1', 'mult_2'}        one per constraint (NKPC, IS)
%   r.controls     = {'pi', 'y', 'i'}            endogenous + instrument - W
%   r.foc          = { 'mult_1 - pi + (-(beta * mult_1(-1)) - mult_2(-1) * sigma) / beta = 0', ...
%                      'mult_2 - kappa * mult_1 - lambda * y - mult_2(-1) / beta = 0', ...
%                      'mult_2 * sigma = 0' }     % FOC(i): the instrument pins mult_2 = 0
%   r.constraints  = {'pi', 'y'}
%   r.value_eqname = 'W'
m.augment(r);                   % grow the model into the planner problem
```

To keep the nonlinear model untouched (e.g. let Dynare handle the optimisation natively) while still reporting the derivation, augment a copy: `m.copy().ramsey_foc(...)` then `augment` + `tex_model`.

### LaTeX Export

#### `tex_model([filename])`

Render the model equations as a LaTeX `align` block — one aligned `LHS &= RHS` row per equation, in declaration order — using each symbol's declared `tex_name` (see [`ast.to_latex`](src/@ast/README.md)). Endogenous and exogenous variables are dated, so a current-period use gets a `_t` subscript (`y` → `y_t`) and a lead/lag its period (`k(-1)` → `k_{t-1}`), while parameters stay bare. Returns the LaTeX string and, when a filename is given, writes it to that file.

**Example:**

```matlab
tex = m.tex_model();              % return the LaTeX string
m.tex_model('paper/model.tex');   % write it to a file
```

#### `tex_steady_state_system([filename])`

Render the steady-state system as a LaTeX `align` block: each equation's static residual (LHS − RHS, all leads/lags collapsed) is simplified and set to zero, exposing the cancellations (e.g. `c(-1)/c → 1`). Rows are **left-aligned** (the align column sits at the left of each equation, not on the equals sign). Endogenous variables carry the steady-state superscript (`k → k^{\star}`); exogenous variables and parameters stay bare.

```matlab
tex = m.tex_steady_state_system();
m.tex_steady_state_system('paper/steady.tex');
```

#### `tex_steady_state_plan([filename])`

Like `tex_steady_state_system`, but the equations are ordered by `steady_plan`'s block decomposition (recursive/topological order) instead of declaration order, and each block renders according to whether it is solvable in closed form. A block solved analytically prints the **solutions** one per row (`<var>^{\star} = <expr>`); a block that needs a numerical solver prints the **residual system** (`<residual> = 0`). A model then reads as a recursive cascade: an analytic prologue solved from the parameters and exogenous variables, the simultaneous blocks a solver must close, then an analytic epilogue whose solutions are written in terms of the just-solved unknowns. The two forms are self-identifying (`= <expr>` vs `= 0`), so no block headers are emitted.

```matlab
tex = m.tex_steady_state_plan();
m.tex_steady_state_plan('paper/steady_plan.tex');
```

#### `tex_linearise([varlist, LevelVars, Evaluate, filename])`

Render the log-linearised model as a LaTeX `align` block, each equation normalized on its keyed variable so a row reads `x_hat = ` a sum of elasticities (e.g. `y_hat = (c*/y*) c_hat + (i*/y*) i_hat`). `varlist` is the time-varying variables to linearise (default: all endogenous; the others are held at the steady state). Options:

- `LevelVars` — variables that enter as a **level** deviation `(x_t - x^{\star})` rather than a log deviation `\hat{x}_t`. Use for variables with a zero or negative steady state (rates, Lagrange multipliers). The choice is per **variable**, so the resulting linear system stays consistent. Default `{}` (all log).
- `Evaluate` — `false` (default) keeps the coefficients symbolic as steady-state expressions (`k^{\star}` etc.); `true` substitutes the numeric steady state (which must already be solved/set).

```matlab
tex = m.tex_linearise();                                   % all endogenous, symbolic
tex = m.tex_linearise({'y','c','k'}, 'Evaluate', true);    % subset, numeric coefficients
tex = m.tex_linearise({'y','pi','i'}, 'LevelVars', {'pi','i'});
```

### Indexing and Access

modBuilder supports custom indexing:

```matlab
% Extract submodel by equation names
sub = m{'consumption', 'investment'};  % Returns modBuilder submodel

% Select submodel by tag criteria
sub = m{bytag('sector', 'manufacturing')};  % Returns modBuilder submodel

% Access symbol value
alpha_val = m.alpha;    % Returns parameter value

% Set symbol value
m.beta = 0.95;
```

## Complete Example: RBC Model

```matlab
% Create Real Business Cycle model
model = modBuilder();

% Technology and preference shocks
model.add('a', 'a = rho*a(-1) + tau*b(-1) + e');
model.add('b', 'b = tau*a(-1) + rho*b(-1) + u');

% Production function
model.add('y', 'y = exp(a)*(k(-1)^alpha)*(h^(1-alpha))');

% Capital accumulation
model.add('c', 'k = exp(b)*(y-c) + (1-delta)*k(-1)');

% Labor supply
model.add('h', 'c*theta*h^(1+psi) = (1-alpha)*y');

% Euler equation
model.add('k', '1/beta = ((exp(b)*c)/(exp(b(+1))*c(+1)))*(exp(b(+1))*alpha*y(+1)/k+(1-delta))');

% Calibrate parameters
model.parameter('alpha', 0.36);
model.parameter('rho', 0.95);
model.parameter('tau', 0.025);
model.parameter('beta', 0.99);
model.parameter('delta', 0.025);
model.parameter('psi', 0);
model.parameter('theta', 2.95);

% Declare shocks
model.exogenous('e', 0);
model.exogenous('u', 0);

% Display model info
model.summary();

% Export to Dynare
model.write('rbc.mod');
```

## Test Suite

### Setup

Configure the test system with your MATLAB path:

```bash
meson setup -Dmatlab_path=/path/to/matlab/bin/matlab build
```

The `meson setup` step also generates `tests/testlist.txt`, a plain-text list of all test names. This file is the single source of truth shared between Meson (for `meson test`) and MATLAB (for the `AllTests` coverage wrapper). When adding or removing tests, edit the `listoftests` array in `tests/meson.build` and re-run `meson setup`.

### Running Tests

```bash
# Run all tests
meson test -C build

# Run specific test category
meson test -C build "rbc/*"
meson test -C build "examples/*"

# Run individual test
meson test -C build "rbc/rbc1.m"
meson test -C build "examples/lookfor.m"

# Run with verbose output
meson test -C build --verbose
```

### Test Organization

Tests are located in the `tests/` directory:

```
tests/
├── rbc/            - Real Business Cycle model tests
├── ad/             - Automatic differentiation tests
├── ast/            - AST engine tests (parse, simplify, diff_ast, to_latex)
├── ar/             - Autoregressive model tests
├── solvers/        - Numerical solver tests
├── partial/        - Symbolic partial / Jacobian tests
├── tex-model/      - LaTeX model-export tests
├── implicit-loops/ - Implicit loop functionality tests
├── load-mod-file/  - Mod file loading tests
├── flip/           - Flip method tests
├── reassign/       - Reassign method tests
├── rmflip/         - Rmflip and exogenise method tests
├── rm/             - Remove method tests
├── rename/         - Rename method tests
├── subs/           - Subs method tests
├── substitute/     - Substitute method tests
├── subsref/        - Custom indexing tests
├── merge/              - Merge method tests
├── tag/                - Tag method tests
├── steady-state-model/ - Steady-state expression tests
├── examples/           - Method examples from documentation
└── utils/              - Test utilities
```

### Running Tests from MATLAB

```matlab
% Change to tests directory
cd tests

% Run a specific test
runtest('rbc/rbc1')
runtest('examples/add')

% Run test with output
runtest('examples/lookfor_regex')
```

## Contributing

When adding new features:

1. Add comprehensive documentation to method docstrings
2. Include examples in the method documentation
3. Create test files in `tests/examples/`
4. Add tests to the `listoftests` array in `tests/meson.build` and re-run `meson setup` to regenerate `tests/testlist.txt`
5. Run full test suite before committing
