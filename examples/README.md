# Examples

Two worked models, chosen to sit at the two ends of what modBuilder does with a
steady state.

| | model | steady state | run time |
|---|---|---|---|
| [`sw/`](sw) | Smets-Wouters, 78 equations, 17 shocks | **analytical throughout** — every variable in closed form, written by the modeller *or* derived by `steady_plan` | ~1 s to build, ~4 s to derive |
| [`two-country/`](two-country) | two RBC economies with perfect risk sharing, 12 equations | **conditionally analytical** — the coupled world core resists, and the one variable that stays open is handed to a generated routine | ~20 s |

Both need only MATLAB and this repository. Dynare is required to *run* the
`.mod` files they produce, not to build them.

## Which to read first

Start with **`two-country/`** if you want the shortest complete picture: one
self-contained script builds the model, plans the steady state, exports a
`.mod` whose `steady_state_model` block mixes analytic assignments with a call
to a generated solver, and then verifies the result by re-executing the emitted
cascade and checking every equation.

Read **`sw/`** for what a realistic model looks like written this way — 78
equations that stay readable because each is named after the variable it pins,
shock processes generated rather than typed, and a fully analytical steady
state. Its companion `sw_from_anchors.m` is the interesting one: it throws the
hand-written steady state away and lets `steady_plan` *derive* 54 of the 78
expressions from seven declared anchors — each one a normalisation, a markup or
a calibration constant — identifying the 17 shock levels on its own, gauge
backout included, and checking every equation at the point it recovers.

## The two routes to a steady state

The examples exist to contrast them:

- **write it** — `m.steady('Variable', 'expression')` for each variable, as
  `sw.m` does. You know the algebra; modBuilder just carries it into the
  `steady_state_model` block.
- **derive it** — `steady_plan` pairs equations to variables, decomposes the
  dependency graph, and closes what the recognisers can close, leaving a
  residual system if anything resists. `sw_from_anchors.m` derives everything;
  `twocountry.m` derives all but one variable and generates a solver for the
  rest.

Each example's README covers its own specifics.

## Conventions

Generated artefacts are ignored, never committed: `.mod` files, Dynare's `+model/`
and `model/` trees, run logs, generated `*_ssblock_*.m` helpers, built PDFs.
Running an example regenerates all of them.

Steady-state levels are written `x^{\star}` in LaTeX output and in the
`texname` metadata, an overbar being reserved for variables whose name carries
one (installed capital, the inflation target).
