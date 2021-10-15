==========
Quickstart
==========

.. highlight:: bash

Welcome to the quickstart guide for NRM. This document will guide you to get up
and running with running your computational jobs through the Node Resource
Manager(NRM).

Install
=======

Container piece
---------------

The NRM code now supports mapping slices on both Singularity containers and
NodeOS compute containers.

NodeOS
~~~~~~

For NodeOScontainer usage, you need to install our container piece
on the system. On a production platform, this should be done by a sysadmin. On
a development platform, this can be acheived with::

 git clone https://xgitlab.cels.anl.gov/argo/containers.git
 cd containers
 make install

Singularity
~~~~~~~~~~~

For local singularity installation, refer to the Singularity_ installation
page.

NRM
---

The NRM core components (the `nrmd` daemon and `nrm` client) can be installed
in multiple ways:

using Spack
~~~~~~~~~~~

 spack install nrm

using Nix
~~~~~~~~~

NRM has a Nix package in our local package repository::

 nix-env -f "https://xgitlab.cels.anl.gov/argo/argopkgs/-/archive/master/argopkgs-master.tar.gz" -iA nrm

using Pip
~~~~~~~~~

You should be able to get NRM and its dependencies on any machine with::

 pip install git+https://github.com/anlsys/nrm-python.git

And entering the resulting virtual environment with `pipenv shell`.

Setup: Launching the `nrmd` daemon
==================================

NRM's behavior is controlled by the `nrmd` userspace daemon.  The `nrmd` daemon
should be launched by the application framework in the background and manages
the resource arbitration on the machine.

The daemon is launched via `nrmd` and logs its output to `/tmp/nrm_log` by
default.

`nrm` command-line options
~~~~~~~~~~~~~~~~~~~~~~~~~~

The `nrm` daemon is mainly configured
through its command-line options.::

  usage: nrmd [-h] [-c FILE] [-d] [-v] [--nrm_log NRM_LOG] [--hwloc HWLOC]
              [--argo_nodeos_config ARGO_NODEOS_CONFIG] [--perf PERF]
              [--pmpi_lib PMPI_LIB] [--argo_perf_wrapper ARGO_PERF_WRAPPER]
              [--singularity SINGULARITY]
              [--container-runtime {nodeos,singularity}]

  optional arguments:
    -h, --help            show this help message and exit
    -c FILE, --configuration FILE
                          Specify a config json-formatted config file to
                          override any of the available CLI options. If an
                          option is actually provided on the command-line, it
                          overrides its corresponding value from the
                          configuration file.
    -d, --print_defaults  Print the default configuration file.
    -v, --verbose         increase output verbosity
    --nrm_log NRM_LOG     Main log file. Override default with the NRM_LOG
                          environment variable
    --hwloc HWLOC         Path to the hwloc to use. This path can be relative
                          and makes uses of the $PATH if necessary. Override
                          default with the HWLOC environment variable.
    --argo_nodeos_config ARGO_NODEOS_CONFIG
                          Path to the argo_nodeos_config to use. This path can
                          be relative and makes uses of the $PATH if necessary.
                          Override default with the ARGO_NODEOS_CONFIG
                          environment variable.
    --perf PERF           Path to the linux perf tool to use. This path can be
                          relative and makes uses of the $PATH if necessary.
                          Override default with the PERF environment variable.
    --pmpi_lib PMPI_LIB   Path to the libnrm PMPI library used for the power
                          policy. Override default with the PMPI environment
                          variable.
    --argo_perf_wrapper ARGO_PERF_WRAPPER
                          Path to the linux perf tool to use. This path can be
                          relative and makes uses of the $PATH if necessary.
                          Override default with the PERFWRAPPER environment
                          variable.
    --singularity SINGULARITY
                          Path to the singularity command. Override default with
                          the SINGULARITY environment variable.
    --container-runtime {nodeos,singularity}
                          Choice of container runtime. Override default with the
                          ARGO_CONTAINER_RUNTIME environment variable.

Running jobs using `nrm`
========================

Tasks are configured using a JSON file called a manifest and started using the `nrm`
command-line utility. Here's an example manifest that allocates two CPUS and
enables application progress monitoring with a one second rate limit.::

  name: basic
  version: 0.0.1
  app:
    container:
      cpus: 2
      mems: 1
    perfwrapper: true
    monitoring:
      ratelimit: 1000000000

This manifest can be used in the following way to launch a command::

 $ nrm run /path/to/manifest.yaml echo "foobar"
 foobar
 INFO:nrm:process ended: msg_up_rpc_rep_process_exit(api=u'up_rpc_rep', container_uuid=u'b54f12ed-6418-4b32-b6ab-2dda7503a1c8', status=u'0', type=u'process_exit')
 INFO:nrm:command ended: msg_up_rpc_rep_process_exit(api=u'up_rpc_rep', container_uuid=u'b54f12ed-6418-4b32-b6ab-2dda7503a1c8', status=u'0', type=u'process_exit')

You have run your first nrm-enabled command. See the :doc:`manifest
guide <manifest>` for an in-depth description of the manifest file format.

`nrm` command-line options
~~~~~~~~~~~~~~~~~~~~~~~~~~

The `nrm` command-line client can be used for a number of operations::

  usage: nrm [-h] [-v] {run,kill,list,listen,setpower} ...

  positional arguments:
    {run,kill,list,listen,setpower}

  optional arguments:
    -h, --help            show this help message and exit
    -v, --verbose         verbose logging information

Start containerized tasks, using a container specification we refer to as an application :doc:`manifest <manifest>`::

  usage: nrm run [-h] [-u [UCONTAINERNAME]] manifest command ...

  positional arguments:
    manifest              manifest file to apply
    command               command to execute
    args                  command arguments

  optional arguments:
    -h, --help            show this help message and exit
    -u [UCONTAINERNAME], --ucontainername [UCONTAINERNAME]
                          user-specified name for container used to attach
                          proceses

Listen for performance and power data::

  usage: nrm listen [-h] [-u UUID] [-f FILTER]

  optional arguments:
    -h, --help            show this help message and exit
    -u UUID, --uuid UUID  container uuid to listen for
    -f FILTER, --filter FILTER
                          type of message to filter and prettyprint, in
                          {power,performance}

List running tasks::

  usage: nrm list [-h]

  optional arguments:
    -h, --help  show this help message and exit

Kill tasks::

  usage: nrm kill [-h] uuid

  positional arguments:
    uuid        uuid of the container

  optional arguments:
    -h, --help  show this help message and exit

Set a node power target::

  usage: nrm setpower [-h] [-f] limit

  positional arguments:
    limit         set new power limit

  optional arguments:
    -h, --help    show this help message and exit
    -f, --follow  listen for power changes


 .. _Singularity: https://singularity.lbl.gov/install-request
