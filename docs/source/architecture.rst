Architecture
============

This page describes the internal architecture and design of modBuilder.

Overview
--------

modBuilder is implemented as a MATLAB handle class that maintains:

* **Model data** (parameters, variables, equations)
* **Symbol tables** (tracking which symbols appear in which equations)
* **Metadata** (long names, TeX names, creation date)

Class Structure
---------------

Properties
~~~~~~~~~~

**Public Properties**

* ``params`` - Cell array (n×4) of parameters
* ``varexo`` - Cell array (n×4) of exogenous variables
* ``var`` - Cell array (n×4) of endogenous variables
* ``equations`` - Cell array (n×2) of equations
* ``symbols`` - Cell array of untyped symbols
* ``tags`` - Struct of equation tags
* ``T`` - Symbol table struct

**Immutable Properties**

* ``date`` - Creation timestamp

**Private Constants**

* ``COL_NAME``, ``COL_VALUE``, ``COL_LONG_NAME``, ``COL_TEX_NAME`` - Column indices
* ``EQ_COL_NAME``, ``EQ_COL_EXPR`` - Equation column indices
* ``VALID_TYPES`` - Valid type strings
* ``RESERVED_NAMES`` - Reserved function names

Symbol Tables
-------------

The symbol table (``T`` property) is central to modBuilder's functionality.

Structure
~~~~~~~~~

.. code-block:: matlab

   T.params.<param_name> = {eq1, eq2, ...}
   T.varexo.<varexo_name> = {eq1, eq2, ...}
   T.var.<var_name> = {eq1, eq2, ...}
   T.equations.<eq_name> = {sym1, sym2, ...}

Purpose
~~~~~~~

* Track dependencies between symbols and equations
* Enable efficient removal (know what else to remove)
* Support ``lookfor`` functionality
* Validate model consistency

Update Strategy
~~~~~~~~~~~~~~~

Symbol tables are updated:

1. After adding/removing/changing equations
2. After symbol type conversions
3. Manually via ``updatesymboltables()``

The update process:

1. Clear existing symbol tables
2. For each equation, extract symbols using ``getsymbols()``
3. For each symbol type, map symbols to equations

Symbol Management
-----------------

Symbol Lifecycle
~~~~~~~~~~~~~~~~

1. **Discovery** - Symbol found in equation → added to ``symbols``
2. **Typing** - User calls ``parameter()``/``exogenous()`` → moved to appropriate table
3. **Usage** - Symbol appears in symbol tables
4. **Removal** - Equation deleted and symbol unused → removed

Type Conversion
~~~~~~~~~~~~~~~

Symbols can change types:

* Parameter ↔ Exogenous (via ``parameter()``/``exogenous()`` methods)
* Endogenous → Exogenous (when equation is removed but variable used elsewhere)
* Endogenous ↔ Exogenous (via ``flip()``)

Reserved Names
~~~~~~~~~~~~~~

These function names cannot be used as symbols:

* Mathematical: ``log``, ``exp``, ``sin``, ``cos``, ``sqrt``, etc.
* Statistical: ``normcdf``, ``normpdf``, ``erf``
* Dynare-specific: ``STEADY_STATE``, ``EXPECTATIONS``

Validation happens in ``validate_symbol_name()``.

Equation Handling
-----------------

Equation Storage
~~~~~~~~~~~~~~~~

Equations are stored in a cell array (``equations``) with:

* Column 1: Equation name (endogenous variable name)
* Column 2: Equation expression string

Constraint: One equation per endogenous variable.

Symbol Extraction
~~~~~~~~~~~~~~~~~

The ``getsymbols()`` method:

1. Tokenizes the equation string
2. Removes MATLAB keywords
3. Removes numbers
4. Removes reserved function names
5. Returns unique symbol list

This uses regular expressions to identify valid MATLAB identifiers.

Equation Validation
~~~~~~~~~~~~~~~~~~~

The ``validate_equation_syntax()`` method checks:

* Balanced parentheses
* No ``==`` (should be ``=``)
* No ``++`` or ``--``
* No element-wise operations (``./``, ``.*``)

Implicit Loops
--------------

Implicit loops allow creating multiple similar equations.

Syntax
~~~~~~

Use ``$1``, ``$2``, etc. as placeholders:

.. code-block:: matlab

   m.add('x_$1', 'x_$1 = alpha_$1 * y', {1, 2, 3});

This expands to:

.. code-block:: matlab

   m.add('x_1', 'x_1 = alpha_1 * y');
   m.add('x_2', 'x_2 = alpha_2 * y');
   m.add('x_3', 'x_3 = alpha_3 * y');

Implementation
~~~~~~~~~~~~~~

1. Detect indices in variable/equation names
2. Validate number of index sets matches
3. Compute Cartesian product of index values
4. For each combination, substitute indices and call ``add()``

Support
~~~~~~~

Implicit loops work for:

* ``add()`` - Equations
* ``parameter()`` - Parameters
* ``exogenous()`` - Exogenous variables

Index values can be:

* Integers: ``{1, 2, 3}``
* Strings: ``{'a', 'b', 'c'}``
* Mixed across different indices (but uniform within)

Method Organization
-------------------

Methods are grouped by functionality:

**Construction/Initialization**

* ``modBuilder()`` - Constructor
* ``loadobj()`` - Deserialization

**Model Building**

* ``add()``, ``addeq()`` - Add equations
* ``parameter()``, ``exogenous()``, ``endogenous()`` - Declare symbols

**Model Modification**

* ``change()`` - Replace equations
* ``remove()``, ``rm()`` - Delete equations
* ``rename()`` - Rename symbols
* ``flip()`` - Exchange variable types
* ``subs()``, ``substitute()`` - String/regex replacement
* ``tag()`` - Add metadata

**Model Operations**

* ``copy()`` - Deep copy
* ``extract()`` - Create submodel
* ``merge()`` - Combine models
* ``write()`` - Export to Dynare

**Inspection**

* ``size()`` - Count elements
* ``typeof()`` - Get symbol type
* ``isparameter()``, ``isexogenous()``, ``isendogenous()`` - Type checks
* ``lookfor()`` - Find symbol usage
* ``summary()`` - Display overview
* ``table()`` - Export to MATLAB table

**Utilities**

* ``updatesymboltables()`` - Refresh symbol tables
* ``solve()`` - Numerical solving
* ``evaluate()`` - Equation evaluation
* ``eq()`` - Equality comparison

**Internal/Private**

* ``getsymbols()`` - Extract symbols from string
* ``validate_*()`` - Validation functions
* ``merge_*()`` - Merge helper methods
* ``print*()`` - Output formatting

Optimization Strategies
-----------------------

Symbol Map
~~~~~~~~~~

An optional ``symbol_map`` (containers.Map) provides O(1) symbol lookups:

.. code-block:: matlab

   symbol_map('alpha') → {type: 'parameter', idx: 1}

This is used by ``typeof()`` when available, falling back to O(n) linear search.

Preallocation
~~~~~~~~~~~~~

Cell arrays are preallocated where possible to avoid repeated resizing.

Batch Operations
~~~~~~~~~~~~~~~~

``rm()`` removes multiple equations efficiently rather than calling ``remove()`` repeatedly.

Custom Indexing
---------------

modBuilder overloads ``subsref`` and ``subsasgn`` for natural syntax:

Subsref Examples
~~~~~~~~~~~~~~~~

.. code-block:: matlab

   % Extract equation by name
   submodel = m('consumption');

   % Extract multiple equations
   submodel = m('c', 'y', 'k');

   % Call method
   m.summary();

   % Access property
   params = m.params;

Subsasgn Examples
~~~~~~~~~~~~~~~~~

.. code-block:: matlab

   % Set parameter value
   m('alpha') = 0.33;

   % Change equation
   m('y') = 'y = beta*k^alpha';

File Export
-----------

The ``write()`` method generates proper Dynare syntax:

1. **Variable declarations** - ``var``, ``varexo``, ``parameters``
2. **Parameter calibrations** - Assignment statements
3. **Model block** - Equations with tags
4. **Metadata** - Long names and TeX names (if provided)

Special handling:

* Conditionally includes long_name/tex_name based on presence
* Formats equations for readability
* Preserves equation tags

Testing Strategy
----------------

Tests are organized by feature:

* ``rbc/`` - Real Business Cycle model tests
* ``ad/`` - Automatic differentiation tests
* ``ar/`` - Autoregressive model tests
* ``merge/`` - Model merging tests
* ``implicit-loops/`` - Implicit loop tests
* ``examples/`` - Documentation example tests
* ``validation/`` - Input validation tests

Each test:

1. Builds a model
2. Performs operations
3. Writes to ``.mod`` file
4. Compares with expected output (``modiff()``)
5. Cleans up

Design Principles
-----------------

1. **Handle class** - Modifications affect the same object
2. **Method chaining** - Most methods return ``o`` for chaining
3. **Consistency** - Symbol tables kept consistent automatically
4. **Validation** - Input validation for robustness
5. **Immutability where appropriate** - Creation date is immutable
6. **Clear error messages** - Helpful errors for common mistakes
7. **Backwards compatibility** - Careful with breaking changes

Extension Points
----------------

modBuilder can be extended by:

1. **Adding methods** - Inherit and add new functionality
2. **Custom validation** - Override ``validate_*`` methods
3. **Alternative export** - Write methods for other formats
4. **Symbol table extensions** - Add custom tracking

Future Enhancements
-------------------

Potential improvements:

1. **Symbolic math integration** - Use Symbolic Math Toolbox
2. **Dependency graphs** - Visualize model structure
3. **Linearization** - Automatic linearization
4. **Calibration helpers** - More sophisticated calibration tools
5. **Model comparison** - Diff two models
6. **Import from .mod** - Parse existing Dynare files
