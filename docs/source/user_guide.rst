User Guide
==========

This guide provides detailed information about using modBuilder effectively.

Model Building
--------------

Creating a Model
~~~~~~~~~~~~~~~~

Start by creating a modBuilder object:

.. code-block:: matlab

   m = modBuilder();

The object tracks:
* Parameters
* Endogenous variables
* Exogenous variables
* Equations
* Symbol tables (which symbols appear in which equations)

Adding Equations
~~~~~~~~~~~~~~~~

Use the ``add`` method to add equations:

.. code-block:: matlab

   m.add('y', 'y = alpha*k + epsilon');

This:
1. Creates an endogenous variable ``y``
2. Associates the equation with ``y``
3. Identifies symbols ``alpha``, ``k``, ``epsilon``
4. Adds them to the untyped symbols list

**Equations with Lags and Leads**

.. code-block:: matlab

   m.add('k', 'k = (1-delta)*k(-1) + i');
   m.add('c', '1/beta = (c/c(+1))*(r(+1)+1-delta)');

**Implicit Loops**

Create multiple similar equations efficiently:

.. code-block:: matlab

   % Creates x_1, x_2, x_3 equations
   m.add('x_$1', 'x_$1 = alpha_$1 * y', {1, 2, 3});

   % Creates equations for all combinations
   m.add('z_$1_$2', 'z_$1_$2 = gamma_$1 * beta_$2', {1, 2}, {'a', 'b'});
   % Results in: z_1_a, z_1_b, z_2_a, z_2_b

Typing Symbols
--------------

Parameters
~~~~~~~~~~

Parameters are constants in your model:

.. code-block:: matlab

   % Basic parameter
   m.parameter('alpha', 0.33);

   % Uncalibrated parameter
   m.parameter('beta');  % Value defaults to NaN

   % With metadata
   m.parameter('rho', 0.95, ...
               'long_name', 'Persistence parameter', ...
               'texname', '\rho');

   % Implicit loops for parameters
   m.parameter('gamma_$1', 0.5, {1, 2, 3});

Exogenous Variables
~~~~~~~~~~~~~~~~~~~

Exogenous variables are external to the model (shocks):

.. code-block:: matlab

   % With default value
   m.exogenous('epsilon', 0);

   % Without value
   m.exogenous('u');

   % With metadata
   m.exogenous('e', 0, ...
               'long_name', 'Technology shock', ...
               'texname', '\varepsilon');

Endogenous Variables
~~~~~~~~~~~~~~~~~~~~

Endogenous variables are determined by equations. They're usually created implicitly
when you add equations, but can be declared explicitly:

.. code-block:: matlab

   m.endogenous('c', NaN, ...
                'long_name', 'Consumption', ...
                'texname', 'c_t');

Symbol Table Management
-----------------------

modBuilder maintains symbol tables that track where each symbol appears:

.. code-block:: matlab

   m.updatesymboltables();

This updates:
* ``m.T.params.<name>`` - List of equations using parameter
* ``m.T.varexo.<name>`` - List of equations using exogenous variable
* ``m.T.var.<name>`` - List of equations using endogenous variable
* ``m.T.equations.<eqname>`` - List of symbols in equation

The symbol tables are updated automatically by most methods, but you may need
to call ``updatesymboltables()`` after manual modifications.

Model Modification
------------------

Changing Equations
~~~~~~~~~~~~~~~~~~

Replace an existing equation:

.. code-block:: matlab

   m.change('y', 'y = beta*k^alpha');
   m.parameter('beta', 0.95);

The ``change`` method:
* Validates the new equation syntax
* Updates symbol tables
* Removes symbols that no longer appear anywhere
* Warns about new untyped symbols

Removing Equations
~~~~~~~~~~~~~~~~~~

Remove one equation:

.. code-block:: matlab

   m.remove('y');

Remove multiple equations:

.. code-block:: matlab

   m.rm('y', 'c', 'k');

When removing an equation:
* The endogenous variable is removed
* Parameters/exogenous variables used only in that equation are removed
* If the variable appears in other equations, it becomes exogenous

Renaming Symbols
~~~~~~~~~~~~~~~~

.. code-block:: matlab

   % Rename parameter
   m.rename('alpha', 'gamma');

   % Rename endogenous variable
   m.rename('y', 'output');

Renaming updates:
* The symbol in all relevant data structures
* Equations using the symbol
* Symbol tables
* Equation tags (for endogenous variables)

Flipping Variable Types
~~~~~~~~~~~~~~~~~~~~~~~~

Exchange an endogenous and exogenous variable:

.. code-block:: matlab

   m.flip('y', 'epsilon');

After flipping:
* ``y`` becomes exogenous
* ``epsilon`` becomes endogenous (associated with the equation formerly for ``y``)

This is useful for calibration exercises.

Substitutions
~~~~~~~~~~~~~

Substitute expressions in equations:

.. code-block:: matlab

   % Replace all occurrences of 'alpha' with 'beta'
   m.subs('alpha', 'beta', 'y');

   % Use regular expressions
   m.substitute('k\(-1\)', 'k_lag', 'y');

Model Operations
----------------

Copying Models
~~~~~~~~~~~~~~

Create an independent copy:

.. code-block:: matlab

   m2 = m.copy();
   % Modifications to m2 don't affect m

Extracting Submodels
~~~~~~~~~~~~~~~~~~~~~

Extract a subset of equations:

.. code-block:: matlab

   submodel = m.extract('c', 'y', 'k');

The submodel contains:
* Only the specified equations
* All parameters used by those equations
* All exogenous variables used by those equations

Merging Models
~~~~~~~~~~~~~~

Combine two models:

.. code-block:: matlab

   combined = m1.merge(m2);

Requirements:
* Models cannot share endogenous variables
* Common parameters are allowed (m2's calibration takes precedence)
* Exogenous in one can be endogenous in the other

Model Inspection
----------------

Size Information
~~~~~~~~~~~~~~~~

.. code-block:: matlab

   n_params = m.size('parameters');
   n_endo = m.size('endogenous');
   n_exo = m.size('exogenous');
   n_eqs = m.size('equations');

Type Checking
~~~~~~~~~~~~~

.. code-block:: matlab

   if m.isparameter('alpha')
       % ...
   end

   if m.isendogenous('y')
       % ...
   end

   [type, id] = typeof(m, 'alpha');  % Returns 'parameter'

Finding Symbols
~~~~~~~~~~~~~~~

.. code-block:: matlab

   % Display all equations containing 'alpha'
   m.lookfor('alpha');

Summary and Tables
~~~~~~~~~~~~~~~~~~

.. code-block:: matlab

   % Print summary
   m.summary();

   % Get parameters as table
   param_table = m.table('parameters');
   endo_table = m.table('endogenous');
   exo_table = m.table('exogenous');

Equation Evaluation
~~~~~~~~~~~~~~~~~~~

Evaluate an equation with current calibration:

.. code-block:: matlab

   % Solve equation for a symbol
   m.solve('y', 'k', 1.0);  % Solve for k, starting at 1.0

Export to Dynare
----------------

Writing .mod Files
~~~~~~~~~~~~~~~~~~

.. code-block:: matlab

   m.write('my_model');

This creates ``my_model.mod`` with:
* Variable declarations (``var``, ``varexo``, ``parameters``)
* Parameter calibrations
* Model block with all equations
* Proper Dynare syntax

The file can be used directly with Dynare:

.. code-block:: matlab

   dynare my_model

Best Practices
--------------

1. **Update symbol tables regularly** - Call ``updatesymboltables()`` after manual changes

2. **Type symbols early** - Declare parameters and exogenous variables soon after adding equations

3. **Use meaningful names** - Include long_name and texname for documentation

4. **Validate before export** - Use ``summary()`` and ``table()`` to inspect before writing

5. **Keep backups** - Use ``copy()`` before major modifications

6. **Organize complex models** - Build separate blocks and ``merge()`` them

Common Pitfalls
---------------

**Untyped Symbols**
   If symbols remain in ``m.symbols``, type them before exporting

**Symbol Table Inconsistencies**
   Run ``updatesymboltables()`` if you get "Unrecognized field name" errors

**Merging Models with Common Endogenous**
   This will error - ensure models have distinct endogenous variables

**Reserved Names**
   Avoid using MATLAB/Dynare function names (log, exp, sin, etc.) as symbols
