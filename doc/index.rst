NRM-Python Documentation
========================

The following is a guide for the NRM Python API and command-line utilities.

If you know about NRM and are just looking to get it to run on your
application or use ``nrm`` and ``nrmd``, please visit the :doc:`quickstart <nrm-home:quickstart>` guide.


.. toctree::
   :maxdepth: 2

   NRM Home <https://nrm.readthedocs.io/en/main/>
   notebooks


Python Library Bindings
-----------------------

The following sections primarily document the user-facing
Python API for interfacing with NRM.

.. automodule:: tooling
   :members: nrmd
   :no-undoc-members: Actuator, Sensor, Action

.. autoclass:: NRMD
   :members:

Internal Modules
----------------
The following sections describe internal Python modules primarily of interest to
NRM developers.

.. automodule:: daemon
   :members:

.. automodule:: messaging
   :members:

.. automodule:: progress
  :members:

.. automodule:: sharedlib
   :members:

Indices and tables
==================

* :ref:`search`
