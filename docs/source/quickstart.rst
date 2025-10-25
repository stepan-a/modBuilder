Quickstart Guide
================

This guide will walk you through creating your first model with modBuilder.

Basic Workflow
--------------

1. **Create** a modBuilder object
2. **Add** equations
3. **Define** parameters and exogenous variables
4. **Write** to a Dynare .mod file

Simple Example: Production Function
------------------------------------

Let's create a simple production function model:

.. code-block:: matlab

   % Step 1: Create modBuilder object
   m = modBuilder();

   % Step 2: Add equations
   m.add('y', 'y = exp(a)*(k^alpha)*(h^(1-alpha))');
   m.add('c', 'c = w*h');
   m.add('k', 'k = (1-delta)*k(-1) + i');

   % Step 3: Define parameters
   m.parameter('alpha', 0.36, 'long_name', 'Capital share');
   m.parameter('delta', 0.025, 'long_name', 'Depreciation rate');
   m.parameter('w', 1.5, 'long_name', 'Wage rate');

   % Step 4: Declare exogenous variables
   m.exogenous('a', 0, 'long_name', 'Technology shock');

   % Step 5: Write to file
   m.write('production_model');

Understanding Symbol Types
---------------------------

modBuilder automatically tracks symbols and requires you to type them:

**Parameters**
   Constants in your model (e.g., ``alpha``, ``beta``)

**Endogenous Variables**
   Variables determined by equations (e.g., ``y``, ``c``, ``k``)

**Exogenous Variables**
   External variables/shocks (e.g., ``epsilon``, ``u``)

.. code-block:: matlab

   m = modBuilder();
   m.add('y', 'y = alpha*k + epsilon');

   % At this point, symbols is {'alpha', 'k', 'epsilon'}
   % You must type them:
   m.parameter('alpha', 0.33);
   m.exogenous('epsilon', 0);
   % k is endogenous (not explicitly declared, inferred from context)

Inspecting Your Model
----------------------

Use these methods to inspect your model:

.. code-block:: matlab

   % Display a summary
   m.summary();

   % View parameters as a table
   param_table = m.table('parameters');
   disp(param_table);

   % Check symbol types
   [type, id] = typeof(m, 'alpha');  % Returns 'parameter'

   % Find where a symbol appears
   m.lookfor('alpha');

Modifying Models
----------------

You can modify models after creation:

.. code-block:: matlab

   % Change an equation
   m.change('y', 'y = beta*k^alpha');
   m.parameter('beta', 0.95);

   % Rename a symbol
   m.rename('alpha', 'gamma');

   % Remove an equation
   m.remove('c');

Working with Multiple Models
-----------------------------

Extract Submodels
~~~~~~~~~~~~~~~~~

.. code-block:: matlab

   full_model = modBuilder();
   % ... add many equations ...

   % Extract just the consumption block
   consumption_block = full_model.extract('c', 'h', 'w');

Merge Models
~~~~~~~~~~~~

.. code-block:: matlab

   % Create separate model blocks
   production = modBuilder();
   production.add('y', 'y = alpha*k');
   production.parameter('alpha', 0.33);

   consumption = modBuilder();
   consumption.add('c', 'c = beta*y');
   consumption.parameter('beta', 0.8);

   % Merge them
   full_model = production.merge(consumption);

Copy for Experiments
~~~~~~~~~~~~~~~~~~~~

.. code-block:: matlab

   baseline = modBuilder();
   % ... build model ...

   % Try alternative specification
   alternative = baseline.copy();
   alternative.change('y', 'y = gamma*k^alpha');
   alternative.parameter('gamma', 1.2);

Next Steps
----------

* Read the :doc:`user_guide` for detailed explanations
* Explore the :doc:`api` for all available methods
* Check :doc:`examples` for more complex use cases
