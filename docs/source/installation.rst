Installation
============

Requirements
------------

* MATLAB R2024b or later (may work with earlier versions)
* Meson build system (for running tests)

Setup
-----

Add to MATLAB Path
~~~~~~~~~~~~~~~~~~

To use modBuilder, add the ``src`` directory to your MATLAB path:

.. code-block:: matlab

   addpath('/path/to/modBuilder/src');

Or for a permanent installation, add this line to your ``startup.m`` file.

Running Tests
-------------

modBuilder uses the Meson build system for running tests.

Initial Setup
~~~~~~~~~~~~~

.. code-block:: bash

   meson setup -Dmatlab_path=/path/to/matlab/bin/matlab build

Run All Tests
~~~~~~~~~~~~~

.. code-block:: bash

   meson test -C build

Run Specific Test
~~~~~~~~~~~~~~~~~

.. code-block:: bash

   meson test -C build rbc/rbc1

Or run directly from MATLAB:

.. code-block:: matlab

   cd tests
   runtest('rbc/rbc1')

Verifying Installation
----------------------

Try this simple example to verify modBuilder is working:

.. code-block:: matlab

   % Create a simple model
   m = modBuilder();
   m.add('y', 'y = alpha*k');
   m.parameter('alpha', 0.33);

   % Display summary
   m.summary();

   % Expected output:
   % Model Summary
   % =============
   % Created: ...
   % Parameters: 1 (1 calibrated, 0 uncalibrated)
   % Endogenous: 1
   % Exogenous: 0
   % Equations: 1

If this works without errors, your installation is successful!
