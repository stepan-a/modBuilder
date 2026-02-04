# modBuilder

[![Pipeline Status](https://git.dynare.org/Dynare/modBuilder/badges/master/pipeline.svg)](https://git.dynare.org/Dynare/modBuilder/-/commits/master)
[![MATLAB Tests](https://github.com/stepan-a/modBuilder/actions/workflows/tests.yml/badge.svg)](https://github.com/stepan-a/modBuilder/actions/workflows/tests.yml)
[![codecov](https://codecov.io/gh/stepan-a/modBuilder/graph/badge.svg)](https://codecov.io/gh/stepan-a/modBuilder)
[![Documentation](https://img.shields.io/badge/slides-PDF-blue)](https://git.dynare.org/Dynare/modBuilder/-/jobs/artifacts/master/raw/doc/slides.pdf?job=doc)

A MATLAB class for programmatically creating and manipulating Dynare `.mod` files.

## Overview

`modBuilder` simplifies the interactive and programmatic creation of Dynare model files. It enables incremental model development by allowing users to define parameters, endogenous/exogenous variables, and equations directly from the MATLAB environment.

### Key Features

- **Interactive Model Building**: Add and modify equations incrementally
- **Symbol Table Management**: Automatic tracking of symbol usage across equations
- **Type System**: Classify symbols as parameters, endogenous, or exogenous variables
- **Consistency Checking**: Validates that each endogenous variable has exactly one equation
- **Regex Support**: Search for symbols using regular expressions
- **Model Operations**: Copy, merge, extract submodels, and more
- **Dynare Export**: Generate syntactically valid `.mod` files ready for simulation

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

Add the `src` directory to your MATLAB path:

```matlab
addpath('/path/to/modBuilder/src');
```

Or use MATLAB's `Set Path` dialog to add it permanently.

## Public Methods

### Constructor

#### `modBuilder([datetime_obj | M_, oo_, jsonfile, [tag]])`

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

### Model Building

#### `add(varname, equation, [indices])`

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

#### `parameter(pname, value, [long_name], [tex_name])`

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

#### `exogenous(xname, value, [long_name], [tex_name])`

Declare an exogenous variable.

**Examples:**

```matlab
m.exogenous('e', 0);
m.exogenous('epsilon', 0, 'Technology shock', '\epsilon');
```

#### `endogenous(ename, value, [long_name], [tex_name])`

Explicitly declare an endogenous variable (usually declared via `add()`).

```matlab
m.endogenous('y', [], 'Output', 'Y');
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

#### `subs(expr1, expr2, [eqname])`

Substitute an expression in equations (literal string replacement via `strrep`).

**Examples:**

```matlab
% Substitute in all equations
m.subs('w*h', 'labor_income');

% Substitute in specific equation
m.subs('old_expr', 'new_expr', 'consumption_eq');

% With implicit loops
m.subs('x_$1', 'y_$1 + z_$1', 'equation_$1', {1, 2, 3});
```

#### `substitute(expr1, expr2, [eqname])`

Substitute an expression in equations using regular expression pattern matching (via `regexprep`). Same interface as `subs()`, but `expr1` is interpreted as a regex pattern rather than a literal string.

**Examples:**

```matlab
% Replace any coefficient followed by *y with z
m.substitute('[\w]+\*y', 'z', 'consumption_eq');

% With implicit loops
m.substitute('x_$1', 'y_$1 + z_$1', 'equation_$1', {1, 2, 3});
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

#### `evaluate(eqname, [printflag])`

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

#### `write(filename, [options])`

Export model to a Dynare `.mod` file.

**Arguments:**
- `filename` — Output file name (with or without `.mod` extension)

**Options (name-value):**
- `initval` — Include an `initval` block with initial values for endogenous variables (default: `false`)
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

Test equality of two modBuilder objects. Compares all properties (parameters, variables, equations, tags, and symbol tables). The order of elements does not matter.

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

#### `solve(eqname, sname, sinit)`

Numerically solve an equation for a symbol.

**Example:**

```matlab
% Solve for steady state capital
m.solve('k_ss_eq', 'k_ss', 10);  % Initial guess = 10
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
├── rbc/           - Real Business Cycle model tests
├── ad/            - Automatic differentiation tests
├── ar/            - Autoregressive model tests
├── solvers/       - Numerical solver tests
├── implicit-loops/ - Implicit loop functionality tests
├── load-mod-file/ - Mod file loading tests
├── examples/      - Method examples from documentation
└── utils/         - Test utilities
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
4. Add tests to `tests/meson.build`
5. Run full test suite before committing
