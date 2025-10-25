.. modBuilder documentation master file

modBuilder Documentation
========================

Welcome to modBuilder, a MATLAB class for programmatically creating and manipulating Dynare .mod files.

modBuilder enables interactive model development by allowing users to incrementally define parameters,
endogenous/exogenous variables, and equations. The class maintains a symbol table that tracks symbol
usage across equations, facilitates consistency checks, and exports complete Dynare model files.

.. toctree::
   :maxdepth: 2
   :caption: Contents:

   installation
   quickstart
   user_guide
   api
   examples
   architecture

Features
--------

* **Interactive model building**: Add equations incrementally
* **Symbol table management**: Automatic tracking of symbol usage across equations
* **Type safety**: Enforces consistent symbol typing (parameter/endogenous/exogenous)
* **Implicit loops**: Create multiple similar equations efficiently
* **Model operations**: Merge, extract, copy models
* **Dynare integration**: Export directly to .mod files

Quick Example
-------------

.. code-block:: matlab

   % Create a simple RBC model
   m = modBuilder();

   % Add equations
   m.add('c', 'c = w*h');
   m.add('y', 'y = exp(a)*(k(-1)^alpha)*(h^(1-alpha))');
   m.add('k', 'k = (1-delta)*k(-1) + i');

   % Define parameters
   m.parameter('alpha', 0.36);
   m.parameter('delta', 0.025);

   % Declare exogenous variables
   m.exogenous('a', 0);

   % Write to Dynare .mod file
   m.write('rbc_model');

Indices and tables
==================

* :ref:`genindex`
* :ref:`search`
