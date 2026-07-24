# Smets-Wouters, built with modBuilder

The nonlinear Smets-Wouters model — 78 equations, 78 endogenous variables,
17 shock processes — written programmatically and exported to a `.mod` file
whose `steady_state_model` block is fully analytical, so Dynare never runs a
numerical steady-state solve.

It is the large-model counterpart of [`../two-country`](../two-country): there
the steady state is only *conditionally* analytical (a small numerical core
survives and is handed to a generated routine), here every variable closes in
closed form.

## What to run

| script | what it does | needs Dynare |
|---|---|---|
| `sw.m` | builds the model and writes `sw.mod` (equations, calibration, shocks, analytical steady state) | no — only to *run* the produced `sw.mod` |
| `sw_from_anchors.m` | rebuilds the model, then lets `steady_plan` **derive** 54 of the 78 steady-state expressions from 7 declared anchors, instead of reading the hand-written steady state (the remaining 17 are the shock levels, identified without being told) | no |

Start with `sw.m` to see the model itself, then `sw_from_anchors.m` for what
`steady_plan(Match=true, Anchors=..., PropagateKnown=true)` can do on a model
of this size — including the gauge backout that recovers the level of the
scale-free Calvo price and wage recursions from a consistency equation.

The seven anchors are the table at the top of that script. One of them is worth
a look: capacity utilisation is anchored, not the capital return rate a hand
derivation would write down, because the utilisation FOC pins it only through an
exponential times a linear factor. Its script header explains why that has no
closed form, and why the anchor belongs on the variable the modeller normalised.

```matlab
cd examples/sw
sw                % writes sw.mod
sw_from_anchors   % derives the same steady state structurally
```

## Reading the model

Every equation is added with a comment of the form

```matlab
% Eq 4: Household Investment FOC → TobinQ
m.add('TobinQ', '...');
```

where the number is the equation number used in `tex/swmodel.tex`, so the code
and the written model can be read side by side. The variable after the arrow is
the one the equation pins.

Equation groups: households 1–11, prices 12–23, wages 24–34, policy and
government 35–37, market clearing 38–42, shock processes 43–59, efficient
economy 60–78.

## Files

- `sw.m` — the model. Sections: calibration, equations, declarations
  (`long_name` / `texname` metadata), analytical steady state, export.
- `sw_from_anchors.m` — the structural steady-state derivation.
- `matlab/` — ARMA helpers. `declare_arma_shock` writes a shock process of any
  order as a multiplicative log form and declares its parameters and
  innovation in one call; `arma_random` draws coefficients matching a target
  autocorrelation and variance; `arma_autocov` computes the autocovariances.
- `tex/` — the model written out in LaTeX (`make` builds the PDF with
  [rubber](https://gitlab.com/latex-rubber/rubber)), using the same equation
  numbers as the comments in `sw.m`.

Setting `WITH_EFFICIENT_BLOCK = false` at the top of `sw.m` drops the efficient
economy (equations 60–78) and defines the output gap against a constant.

Setting `SW_BUILD_ONLY = true` before running `sw.m` returns the model without
the analytical steady state and without exporting — that is how
`sw_from_anchors.m` gets a bare model to work on.
