# Two-country RBC — a *conditionally* analytical steady state

Two symmetric RBC economies linked by perfect risk sharing (Pareto weight
`omega`) and a world resource constraint: 12 equations, two technology
processes, one integrated world core.

It is the example for the case where the steady state does **not** close in
closed form. The technology processes close analytically; the coupled core —
capital, hours, consumption and output of both countries — does not, and
`apply_steady_plan(GenerateHelpers=true)` hands exactly the part that resists
to a generated MATLAB routine. Dynare then computes the steady state without a
global numerical solve: analytic prologue, one small nonlinear system, analytic
epilogue.

Compare [`../sw`](../sw), where the steady state is analytical throughout.

## Run it

```matlab
cd examples/two-country
twocountry
```

Needs MATLAB and this repository; Dynare only to run the produced
`twocountry.mod`. The script prints the plan, writes the `.mod` and its helper,
then re-executes the emitted cascade and checks every model equation at the
recovered point — so a run that prints a residual near machine precision has
verified itself.

Expect roughly 20 seconds: the plan spends its time on symbolic exponent
algebra in the world core.

## What comes out

`steady_plan(Match=true, MaxBlockSize=10)` finds:

- `A_1`, `A_2` — anchor blocks, closed analytically;
- 9 of the 10 core variables — closed **conditional** on the tenth;
- 1 variable left open (`x_1` as things stand — which one it is falls out of
  the elimination's tie-breaks) because the world resource constraint reduces
  to a sum of powers whose composite symbolic exponents defeat the
  recognisers.

The emitted `steady_state_model` block therefore reads: the two anchors, then

```matlab
x_1 = twocountry_ssblock_3(chi, A_1, delta, alpha, beta, phi, sigma, omega, A_2);
```

then the nine conditional closed forms as an analytic epilogue.

## The generated routine

`twocountry_ssblock_3.m` is self-contained — it needs neither modBuilder nor
anything else on the path at run time, because it is called from the `.mod`
file inside a Dynare session. Its Jacobian comes from **complex-step
differentiation**, `f'(x) = imag(f(x + i·h))/h` with `h = 1e-20`: exact to
machine precision, and it spares the file the inlined symbolic derivative. See
`apply_steady_plan`'s `Jacobian` option (`auto`, `complex-step`, `symbolic`)
and, for the details, the note
`~/OrgFiles/20260724T115330--derivation-par-pas-complexe`.

Swap `Solver='newton'` for `Solver='dynare'` (and `SolveAlgo=0` for `fsolve`)
to delegate the block solve to the solvers shipped with Dynare instead of the
damped Newton written into the file.

## Files

- `twocountry.m` — the whole example: model, plan, export, verification.
- generated and ignored: `twocountry.mod`, `twocountry_ssblock_*.m`,
  `+twocountry/`, `twocountry/`, `*.log`.
