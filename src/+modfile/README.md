# modfile

Reads a Dynare `.mod` file into a `modBuilder` object, without Dynare.

## Overview

`modBuilder` could only load an existing model by running Dynare on it first and
handing the resulting `M_` and `oo_` structures, plus the preprocessor's JSON
output, to the constructor. This package removes that dependency by
reimplementing, in MATLAB, the part of the Dynare preprocessor a model
description needs: the declarations, the calibration, the `model` and
`steady_state_model` blocks, `initval`, and the macro language.

The deliverable is a **MATLAB script**. Reading a file translates it into a
readable `modBuilder` script, and running that script is what produces the
object:

```matlab
m = modBuilder('rbc.mod');                 % translate to a temporary script, run it
m = modBuilder('rbc.mod', Script='rbc.m'); % keep the script
```

The script is meant to be kept and edited — it is the natural starting point for
the interactive workflow `modBuilder` is built around, and it uses only the
public API:

```matlab
% modBuilder script generated from rbc.mod.
%
% Edit freely: running this file rebuilds the model.

m = modBuilder();

% Equations
m.add('a', 'a = rho*a(-1)+tau*b(-1) + e');
m.add('y', 'y = exp(a)*(k(-1)^alpha)*(h^(1-alpha))');

% Exogenous variables
m.exogenous('e', NaN, 'declared', true);

% Calibration
alpha = 0.360000;
rho = 0.950000;

% Parameters
m.parameter('alpha', alpha, 'declared', true);
m.parameter('rho', rho, 'declared', true);
```

The calibration keeps the source expressions rather than pre-computed numbers,
so a chain such as `beta = 1/(1+r)` stays readable and can be re-tuned by
editing one line.

## The macro language

Macro directives run before anything else, as in Dynare. `@#define` variables
are carried into the script as MATLAB locals, so the settings a file was written
with stay visible instead of disappearing into the expansion:

```matlab
% Macro variables
Countries = {'US', 'EA'};
OpenEconomy = true;
```

and the control flow becomes MATLAB control flow:

```matlab
% one call per index set
m.add('y_$1', 'y_$1 = alpha + e_$1', {'US', 'EA'});

% or a MATLAB loop when an implicit loop cannot express it
c_values = {'US', 'EA'};
for it = 1:2
    m.add(sprintf('y_%s', c_values{it}), sprintf('y_%s = alpha*e', c_values{it}));
    m.add(sprintf('k_%s', c_values{it}), sprintf('k_%s = y_%s', c_values{it}, c_values{it}));
end

if OpenEconomy
    m.add('nx', 'nx = y_US - y_EA');
end
```

Supported: `@#define` (variables and functions), `@#if` / `@#elseif` / `@#else` /
`@#endif`, `@#ifdef`, `@#ifndef`, `@#for` / `@#endfor` (single index, tuple
destructuring, `when` guard), `@#include`, `@#includepath`, `@#echo`, `@#error`,
and `@{expr}` substitution. `Defines=` is the equivalent of Dynare's `-D`.

The expression engine lives in `src/@macro/` and covers the operators, the type
system (real, boolean, string, tuple, array), the set operations, ranges,
indexing, the casts, the kind predicates and the built-in functions.

Not supported, and reported rather than mis-expanded: comprehensions
(`[x for x in A when cond]`), `@#echomacrovars`, multi-line and nested `@{...}`.

### How the control flow is restored

Every expanded line carries the stack of directive frames it came from, and the
translator groups the generated calls back into those constructs. What it emits
is then chosen per construct, most compact first:

1. **One implicit-loop call**, when a single call per iteration reproduces every
   iteration under a `$N` template, the index values form a full Cartesian
   product, and the placeholders satisfy what `modBuilder` requires of an
   implicit loop.
2. **A MATLAB `for` loop**, otherwise. This covers a body with several calls, a
   non-Cartesian list of tuples, and index values a placeholder cannot carry.
3. **The flat calls**, when no `$N` template reproduces the iterations at all —
   `@{i+1}` for instance, whose output does not contain the index value.

The template is *guessed* from the way the strings vary across iterations and
then **verified** by expanding it again over every iteration. Guessing wrongly
is therefore harmless: a template that does not reproduce the observed calls is
discarded and the next option is used. The model is identical in all three
cases; only the shape of the script differs.

A body with several calls deliberately never uses option 1: an implicit loop
runs one call over every index, so `y_$1` and `k_$1` would come out as
`y_US, y_EA, k_US, k_EA` where the macro produced `y_US, k_US, y_EA, k_EA` —
and that is the order the endogenous variables are declared in.

Nested `@#for` are supported and fold into a single multi-index loop:

```
@#for c in Countries
@#for s in Sectors
[name = 'y_@{c}_@{s}']
y_@{c}_@{s} = alpha*e;
@#endfor
@#endfor
```

becomes `m.add('y_$1_$2', 'y_$1_$2 = alpha*e', {'US','EA'}, {1,2})`. Their
iterations run over the Cartesian product in exactly the order a multi-index
implicit loop expands, so the pair is one loop with two indices. The fold is
applied repeatedly, so a stack of loops collapses in one go; it is refused as
soon as an item sits directly in the outer loop or the inner constructs are not
all the same loop, and each outer iteration is then emitted on its own.

### Conditionals

A `@#if` becomes a MATLAB `if` / `elseif` / `else`, with **every** branch, however
many `@#elseif` there are:

```
@#if Sticky
[name = 'p']
p = alpha*y;
@#else
[name = 'p']
p = y;
@#endif
```
```matlab
Sticky = true;
...
if Sticky
    m.add('p', 'p = alpha*y');
else
    m.add('p', 'p = y');
end
```

Setting `Sticky = false` in the script gives the model the `.mod` file would have
given with that setting. The script is the same whichever branch was taken when
the file was read, so a chain of `@#elseif` comes out once and the flag drives it
from there. The same holds for a conditional that was false at read
time: its branch is emitted inside an `if` that simply does not run, and turning
the flag on brings it in.

This works because the reader does **not** build the script from the expanded
text alone. A branch that is not selected produces no text, so a single pass
cannot see it. `modfile.read` therefore reads the file again, once per branch no
conditional took, with `expand_macros`'s `Force` option pinning that branch —
and hands those descriptions to the translator in `mod.branches`. The model
itself always comes from the unforced read, so nothing in this can change what
was built.

The cost is one extra read per branch, not one per combination: every other
conditional keeps the selection it already had, and the ancestors are forced
only as far as needed to reach the branch in question.

Conditionals **written with the same condition are forced together**. A flag
usually guards several places at once — a declaration and the equation that goes
with it — and flipping one alone would leave a model with an equation for an
undeclared variable, which would not read back. This mirrors the generated
script, where one MATLAB variable drives every `if` written from that condition.

`@#ifdef` and `@#ifndef` render as `exist('X', 'var')`, which agrees with the
model because the `@#define` that binds the variable is itself emitted as that
local. Values seeded through `Defines` are emitted as locals as well, so a file
whose default is guarded by `@#ifndef` — the idiom that makes a setting
overridable from outside — does not leave the script referring to a variable it
never assigns.

Two cases still fall back to the flat calls, under a comment naming the line of
the conditional and saying why:

- **The condition has no MATLAB rendering.** The kind predicates do render —
  `@#if isarray(Regimes)` becomes
  `if (iscell(Regimes) || (isnumeric(Regimes) && ~isscalar(Regimes)))` — but
  `istuple` on a value that is one still has none, since a tuple and an array of
  the same elements are the same MATLAB value. See
  [`src/@macro/README.md`](../@macro/README.md) for the table and for why two of
  the predicate names cannot simply be carried across.
- **A branch does not stand on its own** — reading it raises, typically because
  it declares a variable whose equation lives outside the conditional, so the
  equations cannot be matched. Only the branch that was taken is then emitted.

Nested conditionals are supported, and produce nested MATLAB `if`s:

```matlab
if Open
    if Sticky
        m.add('p', 'p = alpha*y');
    else
        m.add('p', 'p = y');
    end
else
    m.add('p', 'p = 0');
end
```

This holds whichever branch the outer conditional took. A `@#if` inside a branch
that was not selected is invisible to the first pass; it is recovered when that
branch is read, and its own branches when the result is read again. The `Depth`
option of `modfile.read` bounds that recursion, three levels by default, and
each level costs one read per branch.

Constructs are keyed by `modfile.construct_id`, built from the file **and** the
line, not by the line alone. An `@#include`d file starts again at line 1, so a
directive in it sits at the same line as one in the includer; keying on the line
merges the two, emitting them as a single `if` and forcing a branch of one when
the other was meant. The key is a hash of the path rather than a position in the
order the files were met, because forcing a branch can change which files an
`@#include` brings in, and anything counted during the scan would shift under the
keys already handed out.

When a `@#if` decides which endogenous variables are *declared*, the `reorder()`
call that restores the `var` order is not emitted: it takes the whole list and
would fail as soon as the flag changed, in a script whose point is that it can
be. The variables then follow the equations, which differs from the `.mod` file
in the `var` statement only.

A conditional is recorded only if it was **reached**. One sitting inside a
branch that was not taken is not a construct of that reading at all, and
treating it as one used to emit its calls a second time, next to the branch that
already carried them.

## What is read, and what is not

Imported: `var`, `varexo`, `parameters` (with `$tex$` and `(long_name='...')`),
top-level parameter assignments, the `model` block with its equation tags and
its `#` model-local variables, `steady_state_model`, `initval`, and the options
of the `steady` and `check` commands.

Refused, because skipping them would silently build a *different* model:
`predetermined_variables`, `varexo_det`, `trend_var`, deflators, heterogeneity,
`external_function`, the optimal-policy statements, and a second `model` block.

Skipped with a warning: everything computational (`stoch_simul`, `estimation`,
`shocks`, `varobs`, …). `Strict=true` turns those warnings into errors.

Model-local variables (`#name = expr;`) are inlined into the equations that use
them, on the tree rather than textually, so that precedence and lags come out
right: `#z = a*b;` used as `z(-1)` becomes `a(-1)*b(-1)`, with parameters left
at the current period.

## Round-tripping

Every `.mod` file produced by `write()` reads back and writes out byte for byte
identically; this is checked over the committed fixtures by
`tests/read-mod-file/roundtrip_fixtures.m`, including the 580-line Smets-Wouters
model in `examples/sw/`.

Two caveats. A file whose `var` statement lists the endogenous variables in an
order unrelated to its equations round-trips with the list reordered, which is
also what the Dynare-based path does. A file containing `#` model-local
variables has the affected equations re-rendered, so their spacing changes.

`tests/read-mod-file/t10_json_parity.m` checks the stronger property that the
two routes agree: the same model built from `M_`/`oo_`/JSON and from the `.mod`
file has identical parameter, exogenous, equation, tag and symbol tables.

## Functions

| Function | Role |
|---|---|
| `load(filename, ...)` | the whole pipeline: read, translate, run |
| `read(filename, ...)` | parse a file into a neutral description |
| `translate(mod, ...)` | turn that description into a script |
| `build(scriptpath)` | run a generated script and return the model |
| `expand_macros(text, ...)` | run the macro directives |
| `strip_comments(text)` | blank the comments, preserving every offset |
| `split_statements(text)` | cut into top-level statements and blocks |
| `parse_declaration(body, keyword)` | read a `var`/`varexo`/`parameters` list |
| `parse_model_block(body)` | read equations, tags and model-local variables |
| `parse_steady_state_model(body)` | read the analytical steady state |
| `parse_initval(body)` | read the initial guess |
| `inline_model_local_variables(...)` | substitute the `#` definitions away |
| `name_equations(...)` | associate equations with endogenous variables |
| `emit_items(...)` | restore the macro control flow around the generated calls |
| `construct_id(...)` | key a directive construct by its file and line |
| `macro_frame(...)` | build one unit of directive provenance |
| `resolve_include(...)` | locate an `@#include` target |
| `parse_options(text)` | read a command option group |
| `statement_policy(keyword)` | refuse or skip an unimported statement |

## Notes on the implementation

Comment stripping is a state machine, not a regular expression, and it must
stay one. Two `.mod` constructs contain characters that look like comment
markers: quoted attribute values such as `(long_name='Output share (%)')`, and
TeX names such as the `$\delta'$` and `$S'$` of `examples/sw/sw.mod`, which
contain an apostrophe. Tracking quotes but not TeX names makes that apostrophe
open a string and corrupts the rest of the file.

Equations are kept verbatim and never re-rendered through `ast`, because
`ast.string()` normalises spacing and a `write()` of the result would no longer
match the source.

Equation-to-variable association reuses `modBuilder.matchequations`, the same
bipartite matcher the Dynare-based constructor uses, so both entry points agree
including on their diagnostics.
