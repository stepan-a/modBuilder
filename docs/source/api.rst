API Reference
=============

This page contains the complete API reference for modBuilder.

Constructor
-----------

.. function:: modBuilder()

   Create a new modBuilder object.

   **Returns:**
      A new modBuilder object with empty model

   **Example:**

   .. code-block:: matlab

      m = modBuilder();

Model Building Methods
----------------------

add
~~~

.. function:: add(o, varname, equation, varargin)

   Add an equation to the model and associate an endogenous variable.

   **Parameters:**
      * **varname** (*char*) - Name of the endogenous variable
      * **equation** (*char*) - Equation expression
      * **varargin** (*cell*) - Index values for implicit loops (optional)

   **Returns:**
      Updated modBuilder object

   **Examples:**

   .. code-block:: matlab

      % Simple equation
      m.add('c', 'c = w*h');

      % Equation with lags and leads
      m.add('k', 'k = (1-delta)*k(-1) + i');

      % With implicit loops
      m.add('x_$1', 'x_$1 = alpha_$1 * y', {1, 2, 3});

parameter
~~~~~~~~~

.. function:: parameter(o, pname, varargin)

   Declare or calibrate a parameter.

   **Parameters:**
      * **pname** (*char*) - Parameter name
      * **pvalue** (*double*, optional) - Parameter value (default: NaN)
      * **long_name** (*char*, optional) - Long description
      * **texname** (*char*, optional) - TeX representation

   **Returns:**
      Updated modBuilder object

   **Examples:**

   .. code-block:: matlab

      % Calibrate a parameter
      m.parameter('alpha', 0.33);

      % Uncalibrated parameter
      m.parameter('beta');

      % With metadata
      m.parameter('rho', 0.95, 'long_name', 'Persistence', 'texname', '\rho');

      % Implicit loops
      m.parameter('gamma_$1', 0.5, {1, 2, 3});

exogenous
~~~~~~~~~

.. function:: exogenous(o, xname, varargin)

   Declare or set default value for an exogenous variable.

   **Parameters:**
      * **xname** (*char*) - Exogenous variable name
      * **xvalue** (*double*, optional) - Default value (default: NaN)
      * **long_name** (*char*, optional) - Long description
      * **texname** (*char*, optional) - TeX representation

   **Returns:**
      Updated modBuilder object

   **Examples:**

   .. code-block:: matlab

      % With default value
      m.exogenous('epsilon', 0);

      % Without value
      m.exogenous('u');

      % With metadata
      m.exogenous('e', 0, 'long_name', 'Technology shock', 'texname', '\varepsilon');

endogenous
~~~~~~~~~~

.. function:: endogenous(o, ename, evalue, varargin)

   Declare or set default value for an endogenous variable.

   **Parameters:**
      * **ename** (*char*) - Endogenous variable name
      * **evalue** (*double*, optional) - Steady state value (default: NaN)
      * **long_name** (*char*, optional) - Long description
      * **texname** (*char*, optional) - TeX representation

   **Returns:**
      Updated modBuilder object

   **Note:**
      Endogenous variables are usually created automatically when adding equations.

Model Modification Methods
---------------------------

change
~~~~~~

.. function:: change(o, varname, equation)

   Replace an existing equation in the model.

   **Parameters:**
      * **varname** (*char*) - Name of the endogenous variable (equation name)
      * **equation** (*char*) - New equation expression

   **Returns:**
      Updated modBuilder object

   **Example:**

   .. code-block:: matlab

      m.change('c', 'c = alpha*k + w*h');

remove
~~~~~~

.. function:: remove(o, eqname)

   Remove an equation from the model.

   **Parameters:**
      * **eqname** (*char*) - Name of the equation to remove

   **Returns:**
      Updated modBuilder object

   **Note:**
      Also removes the associated endogenous variable and any parameters/exogenous
      variables that don't appear elsewhere.

   **Example:**

   .. code-block:: matlab

      m.remove('c');

rm
~~

.. function:: rm(o, varargin)

   Remove multiple equations from the model.

   **Parameters:**
      * **varargin** (*char*) - Names of equations to remove

   **Returns:**
      Updated modBuilder object

   **Example:**

   .. code-block:: matlab

      m.rm('c', 'y', 'k');

rename
~~~~~~

.. function:: rename(o, oldsymbol, newsymbol)

   Rename a symbol throughout the model.

   **Parameters:**
      * **oldsymbol** (*char*) - Current symbol name
      * **newsymbol** (*char*) - New symbol name

   **Returns:**
      Updated modBuilder object

   **Example:**

   .. code-block:: matlab

      m.rename('alpha', 'beta');
      m.rename('c', 'consumption');

flip
~~~~

.. function:: flip(o, varname, varexoname)

   Exchange an endogenous and exogenous variable.

   **Parameters:**
      * **varname** (*char*) - Endogenous variable name
      * **varexoname** (*char*) - Exogenous variable name

   **Returns:**
      Updated modBuilder object

   **Example:**

   .. code-block:: matlab

      m.flip('y', 'epsilon');

subs
~~~~

.. function:: subs(o, expr1, expr2, eqname)

   Substitute expression in an equation using string replacement.

   **Parameters:**
      * **expr1** (*char*) - Expression to find
      * **expr2** (*char*) - Expression to replace with
      * **eqname** (*char*, optional) - Equation name (if omitted, applies to all)

   **Returns:**
      Updated modBuilder object

substitute
~~~~~~~~~~

.. function:: substitute(o, expr1, expr2, eqname)

   Substitute expression in an equation using regular expressions.

   **Parameters:**
      * **expr1** (*char*) - Regular expression pattern to find
      * **expr2** (*char*) - Replacement expression
      * **eqname** (*char*, optional) - Equation name (if omitted, applies to all)

   **Returns:**
      Updated modBuilder object

tag
~~~

.. function:: tag(o, eqname, tagname, value)

   Add a tag to an equation.

   **Parameters:**
      * **eqname** (*char*) - Equation name
      * **tagname** (*char*) - Tag name
      * **value** (*char*) - Tag value

   **Returns:**
      Updated modBuilder object

   **Note:**
      Cannot change the 'name' tag. Use ``rename`` instead.

Model Operations
----------------

copy
~~~~

.. function:: copy(o)

   Create a deep copy of the modBuilder object.

   **Returns:**
      Independent copy with same content

   **Example:**

   .. code-block:: matlab

      m2 = m.copy();
      m2.change('c', 'c = beta*k');  % m is unchanged

extract
~~~~~~~

.. function:: extract(o, varargin)

   Extract a subset of equations to create a new submodel.

   **Parameters:**
      * **varargin** (*char*) - Equation names to extract

   **Returns:**
      New modBuilder object containing only specified equations

   **Example:**

   .. code-block:: matlab

      submodel = m.extract('c', 'y');

merge
~~~~~

.. function:: merge(o, p)

   Merge two models into a single larger model.

   **Parameters:**
      * **p** (*modBuilder*) - Second model to merge

   **Returns:**
      New merged modBuilder object

   **Note:**
      Models cannot share endogenous variables.

   **Example:**

   .. code-block:: matlab

      full_model = m1.merge(m2);

write
~~~~~

.. function:: write(o, basename)

   Write model to a Dynare .mod file.

   **Parameters:**
      * **basename** (*char*) - File name without extension

   **Example:**

   .. code-block:: matlab

      m.write('my_model');  % Creates my_model.mod

solve
~~~~~

.. function:: solve(o, eqname, sname, sinit)

   Solve an equation for a specific symbol.

   **Parameters:**
      * **eqname** (*char*) - Equation name
      * **sname** (*char*) - Symbol to solve for
      * **sinit** (*double*) - Initial guess

   **Returns:**
      Updated modBuilder object with solved value

evaluate
~~~~~~~~

.. function:: evaluate(o, eqname, printflag)

   Evaluate an equation using current calibration.

   **Parameters:**
      * **eqname** (*char*) - Equation name
      * **printflag** (*logical*, optional) - Whether to print result (default: true)

   **Returns:**
      Evaluated equation result

Inspection Methods
------------------

size
~~~~

.. function:: size(o, type)

   Return the number of elements of a specific type.

   **Parameters:**
      * **type** (*char*) - One of 'parameters', 'exogenous', 'endogenous', 'equations'

   **Returns:**
      Integer count

   **Example:**

   .. code-block:: matlab

      n = m.size('parameters');

typeof
~~~~~~

.. function:: typeof(o, name)

   Return the type of a symbol.

   **Parameters:**
      * **name** (*char*) - Symbol name

   **Returns:**
      * **type** (*char*) - 'parameter', 'exogenous', or 'endogenous'
      * **id** (*logical*) - Position in respective array

   **Example:**

   .. code-block:: matlab

      [type, id] = typeof(m, 'alpha');

isparameter
~~~~~~~~~~~

.. function:: isparameter(o, name)

   Check if a symbol is a parameter.

   **Parameters:**
      * **name** (*char*) - Symbol name

   **Returns:**
      Logical true/false

isexogenous
~~~~~~~~~~~

.. function:: isexogenous(o, name)

   Check if a symbol is an exogenous variable.

   **Parameters:**
      * **name** (*char*) - Symbol name

   **Returns:**
      Logical true/false

isendogenous
~~~~~~~~~~~~

.. function:: isendogenous(o, name)

   Check if a symbol is an endogenous variable.

   **Parameters:**
      * **name** (*char*) - Symbol name

   **Returns:**
      Logical true/false

issymbol
~~~~~~~~

.. function:: issymbol(o, name)

   Check if a name is any type of symbol.

   **Parameters:**
      * **name** (*char*) - Symbol name

   **Returns:**
      Logical true/false

lookfor
~~~~~~~

.. function:: lookfor(o, name)

   Print all equations where a symbol appears.

   **Parameters:**
      * **name** (*char*) - Symbol name

   **Example:**

   .. code-block:: matlab

      m.lookfor('alpha');

summary
~~~~~~~

.. function:: summary(o)

   Display a formatted summary of the model.

   **Returns:**
      Updated modBuilder object

   **Example:**

   .. code-block:: matlab

      m.summary();

table
~~~~~

.. function:: table(o, type)

   Convert params/varexo/var to MATLAB table for easier viewing.

   **Parameters:**
      * **type** (*char*) - 'parameters', 'exogenous', or 'endogenous'

   **Returns:**
      MATLAB table with columns: Name, Value, LongName, TeXName

   **Example:**

   .. code-block:: matlab

      param_table = m.table('parameters');
      disp(param_table);

Utility Methods
---------------

updatesymboltables
~~~~~~~~~~~~~~~~~~

.. function:: updatesymboltables(o)

   Update all symbol table mappings.

   **Returns:**
      Updated modBuilder object

   **Note:**
      Called automatically by most methods, but may need manual call after
      direct property modifications.

getallsymbols
~~~~~~~~~~~~~

.. function:: getallsymbols(o)

   Get list of all symbols in the model.

   **Returns:**
      Cell array of symbol names

Comparison
----------

eq
~~

.. function:: eq(o, p)

   Compare two modBuilder objects for equality.

   **Parameters:**
      * **p** (*modBuilder*) - Object to compare with

   **Returns:**
      Logical true if equal, false otherwise

Properties
----------

params
~~~~~~

Cell array (n×4) of parameters:

* Column 1: parameter name (*char*)
* Column 2: calibration value (*double* or NaN)
* Column 3: long_name (*char* or empty)
* Column 4: tex_name (*char* or empty)

varexo
~~~~~~

Cell array (n×4) of exogenous variables (same structure as params).

var
~~~

Cell array (n×4) of endogenous variables (same structure as params).

equations
~~~~~~~~~

Cell array (n×2) of equations:

* Column 1: equation name (endogenous variable name)
* Column 2: equation expression

symbols
~~~~~~~

Cell array of untyped symbols that haven't been classified yet.

tags
~~~~

Struct of equation tags. Each field corresponds to an equation.

T
~

Symbol table struct with fields:

* ``T.params.<NAME>`` - Cell array of equations using parameter NAME
* ``T.varexo.<NAME>`` - Cell array of equations using exogenous variable NAME
* ``T.var.<NAME>`` - Cell array of equations using endogenous variable NAME
* ``T.equations.<EQNAME>`` - Cell array of symbols in equation EQNAME

date
~~~~

Creation timestamp (immutable).

Constants
---------

COL_NAME, COL_VALUE, COL_LONG_NAME, COL_TEX_NAME
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

Column indices for params/varexo/var tables (private).

EQ_COL_NAME, EQ_COL_EXPR
~~~~~~~~~~~~~~~~~~~~~~~~~

Column indices for equations table (private).

VALID_TYPES
~~~~~~~~~~~

Valid symbol/component types: ``{'parameters', 'exogenous', 'endogenous', 'equations'}``

RESERVED_NAMES
~~~~~~~~~~~~~~

Reserved function names that cannot be used as symbols (private).
