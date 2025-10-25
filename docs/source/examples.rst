Examples
========

This page contains examples demonstrating various features of modBuilder.

Basic RBC Model
---------------

A simple Real Business Cycle model:

.. code-block:: matlab

   % Create model
   m = modBuilder();

   % Technology process
   m.add('a', 'a = rho*a(-1) + e');

   % Production
   m.add('y', 'y = exp(a)*(k(-1)^alpha)*(h^(1-alpha))');

   % Capital accumulation
   m.add('k', 'k = (1-delta)*k(-1) + i');

   % Consumption-leisure choice
   m.add('c', 'c + i = y');
   m.add('h', 'c*theta*h^(1+psi) = (1-alpha)*y');

   % Euler equation
   m.add('i', '1/beta = (c/c(+1))*(alpha*y(+1)/k + (1-delta))');

   % Parameters
   m.parameter('alpha', 0.36, 'long_name', 'Capital share');
   m.parameter('beta', 0.99, 'long_name', 'Discount factor');
   m.parameter('delta', 0.025, 'long_name', 'Depreciation rate');
   m.parameter('rho', 0.95, 'long_name', 'Technology persistence');
   m.parameter('psi', 0, 'long_name', 'Labor elasticity');
   m.parameter('theta', 2.95, 'long_name', 'Leisure preference');

   % Exogenous shocks
   m.exogenous('e', 0, 'long_name', 'Technology shock');

   % Check model
   m.summary();

   % Export to Dynare
   m.write('rbc_model');

Multi-Sector Model Using Implicit Loops
----------------------------------------

Create a model with multiple sectors:

.. code-block:: matlab

   m = modBuilder();

   % Production in each sector
   m.add('y_$1', 'y_$1 = alpha_$1 * k_$1(-1)^beta_$1 * h_$1^(1-beta_$1)', ...
         {1, 2, 3});

   % Labor allocation
   m.add('h', 'h = h_1 + h_2 + h_3');

   % Capital accumulation per sector
   m.add('k_$1', 'k_$1 = (1-delta_$1)*k_$1(-1) + i_$1', {1, 2, 3});

   % Parameters for each sector
   m.parameter('alpha_$1', [1.0, 1.1, 0.9], {1, 2, 3});
   m.parameter('beta_$1', 0.33, {1, 2, 3});
   m.parameter('delta_$1', [0.02, 0.03, 0.025], {1, 2, 3});

   m.summary();

Calibration Exercise
--------------------

Use ``flip`` to find the implied shock needed for a target output:

.. code-block:: matlab

   % Build model
   m = modBuilder();
   m.add('y', 'y = alpha*k + epsilon');
   m.parameter('alpha', 0.5);
   m.exogenous('epsilon', 0);

   % Calibrate model to match target
   m_calib = m.copy();

   % Flip y and epsilon
   m_calib.flip('y', 'epsilon');

   % Set target output
   m_calib.var{1, 2} = 10.0;  % Target y = 10

   % Solve for implied epsilon
   m_calib.exogenous('k', 15.0);
   m_calib.updatesymboltables();

   % Extract calibrated shock
   epsilon_calibrated = m_calib.var{strcmp(m_calib.var(:,1), 'epsilon'), 2};

Modular Model Building
-----------------------

Build a model in separate blocks and merge:

.. code-block:: matlab

   %% Household Block
   household = modBuilder();

   % Labor supply
   household.add('h', 'w = theta*c*h^psi');

   % Consumption
   household.add('c', 'c + s = w*h + r*k(-1)');

   % Savings
   household.add('k', 'k = s');

   household.parameter('theta', 2.0);
   household.parameter('psi', 1.0);

   %% Firm Block
   firm = modBuilder();

   % Production
   firm.add('y', 'y = k(-1)^alpha * h^(1-alpha)');

   % Labor demand
   firm.add('w', 'w = (1-alpha)*y/h');

   % Capital demand
   firm.add('r', 'r = alpha*y/k(-1)');

   firm.parameter('alpha', 0.33);

   %% Market Clearing
   market = modBuilder();
   market.add('s', 's = y - w*h - r*k(-1)');

   %% Merge all blocks
   full_model = household.merge(firm);
   full_model = full_model.merge(market);

   full_model.summary();

Model Comparison
----------------

Compare different specifications:

.. code-block:: matlab

   % Baseline: Cobb-Douglas
   baseline = modBuilder();
   baseline.add('y', 'y = k^alpha * h^(1-alpha)');
   baseline.parameter('alpha', 0.33);

   % Alternative: CES production
   ces = baseline.copy();
   ces.change('y', 'y = (gamma*k^rho + (1-gamma)*h^rho)^(1/rho)');
   ces.parameter('gamma', 0.5);
   ces.parameter('rho', -0.5);

   % Compare
   baseline.write('baseline');
   ces.write('ces_alternative');

Extracting Submodels for Testing
---------------------------------

Test components of a large model:

.. code-block:: matlab

   % Build full model
   full = modBuilder();
   full.add('y', 'y = k^alpha * h^(1-alpha)');
   full.add('c', 'c + i = y');
   full.add('k', 'k = (1-delta)*k(-1) + i');
   full.add('h', 'w*h = theta*c');
   full.add('w', 'w = (1-alpha)*y/h');

   full.parameter('alpha', 0.33);
   full.parameter('delta', 0.025);
   full.parameter('theta', 1.0);

   % Extract production block for testing
   production = full.extract('y', 'w');

   % Test with simple calibration
   production.exogenous('h', 0.33);
   production.exogenous('k', 1.0);
   production.updatesymboltables();

   production.write('production_test');

Working with Tags
-----------------

Add tags for equation documentation:

.. code-block:: matlab

   m = modBuilder();

   % Add equations with tags
   m.add('y', 'y = k^alpha * h^(1-alpha)');
   m.tag('y', 'description', 'Cobb-Douglas production function');
   m.tag('y', 'source', 'Romer (2019), p. 45');

   m.add('c', '1/c = beta/c(+1) * (r(+1) + 1-delta)');
   m.tag('c', 'description', 'Euler equation');
   m.tag('c', 'source', 'Standard DSGE formulation');

   % Tags are preserved in the model
   m.parameter('alpha', 0.33);
   m.parameter('beta', 0.99);
   m.parameter('delta', 0.025);

Advanced Substitutions
----------------------

Use regular expressions for complex substitutions:

.. code-block:: matlab

   m = modBuilder();
   m.add('c', 'c = (c(-1)^gamma * c(+1)^(1-gamma))^(1/mu)');
   m.parameter('gamma', 0.5);
   m.parameter('mu', 2.0);

   % Replace all time subscripts
   m.substitute('c\((-?\d+)\)', 'c_ss', 'c');

   % Now equation is: c = c_ss^(1/mu)

Solving for Parameter Values
-----------------------------

Find parameter values that satisfy calibration targets:

.. code-block:: matlab

   m = modBuilder();
   m.add('y', 'y = alpha*k');
   m.add('k', 'k = s*y');

   % Target: y = 100, k = 200, s = 0.2
   m.exogenous('y', 100);
   m.exogenous('s', 0.2);

   % Solve for alpha
   m.parameter('alpha');  % Uncalibrated
   m.solve('k', 'alpha', 0.5);  % Solve k equation for alpha

   % Result: alpha = k/y = 2.0

Checking Model Consistency
---------------------------

Verify model properties before running:

.. code-block:: matlab

   m = modBuilder();
   % ... build model ...

   % Check summary
   m.summary();

   % Verify no untyped symbols
   if ~isempty(m.symbols)
       warning('Model has untyped symbols:');
       disp(m.symbols);
   end

   % Check calibration
   params = m.table('parameters');
   uncalib = params(isnan(params.Value), :);
   if height(uncalib) > 0
       warning('Uncalibrated parameters:');
       disp(uncalib);
   end

   % Verify equation count
   assert(m.size('endogenous') == m.size('equations'), ...
          'Mismatch between endogenous variables and equations');
