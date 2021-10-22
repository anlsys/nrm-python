###############################################################################
# Copyright 2019 UChicago Argonne, LLC.
# (c.f. AUTHORS, LICENSE)
#
# This file is part of the NRM project.
# For more info, see https://github.com/anlsys/nrm-python
#
# SPDX-License-Identifier: BSD-3-Clause
###############################################################################

import nrm.sharedlib
import signal
import os
import yaml
import json
import subprocess
import shutil
from contextlib import contextmanager
import nrm.messaging
from multiprocessing import Process
from typing import NamedTuple, List, NewType


ActuatorID = NewType("ActuatorID", str)
SensorID = NewType("SensorID", str)
ActuatorValue = NewType("ActuatorValue", float)


class Actuator(NamedTuple):
    actuatorID: ActuatorID
    admissibleActions: List[ActuatorValue]


class Sensor(NamedTuple):
    sensorID: SensorID
    maxFrequency: float
    lowerbound: float
    upperbound: float


class Action(NamedTuple):
    actuatorID: ActuatorID
    actuatorValue: ActuatorValue


try:
    lib = nrm.sharedlib.UnsafeLib(os.environ.get("PYNRMSO"))
except AttributeError:
    if os.environ.get("NRM_GEN_DOCS"):
        pass
    else:
        raise


class CPD:
    def __init__(self, cpd: str):
        self.cpd = cpd

    def __str__(self):
        return lib.showCpd(self.cpd)

    def __iter__(self):
        yield from json.loads(lib.jsonCpd(self.cpd)).items()

    def actuators(self) -> List[Actuator]:
        return [
            Actuator(actuatorID=a[0], admissibleActions=a[1]["actions"])
            for a in json.loads(lib.jsonCpd(self.cpd))["actuators"]
        ]

    def sensors(self) -> List[Sensor]:
        return [
            Sensor(
                sensorID=a[0],
                maxFrequency=a[1]["maxFrequency"],
                lowerbound=a[1]["range"]["i"][0],
                upperbound=a[1]["range"]["i"][1],
            )
            for a in json.loads(lib.jsonCpd(self.cpd))["sensors"]
        ]


class NRMState:
    def __init__(self, cpd):
        self.state = cpd

    def __str__(self):
        return lib.showState(self.state)

    def __iter__(self):
        yield from json.loads(lib.jsonState(self.state)).items()


@contextmanager
def nrmd(configuration):
    """
    The nrmd context manager is the proper way to initialize the NRM daemon
    via this module.
    SIGTERM will be sent to the process that performed the resource acquisition
    if the daemon terminates illegally.

    Example:
        with nrmd({}) as d:
            cpd = d.get_cpd()
            print(cpd.actuators())
            print(cpd.sensors())
            print(d.upstream_recv())
            print("done.")

    """

    def daemon():
        subprocess.run(["pkill", "-f", "nrmd"])
        subprocess.run(["pkill", "nrmd"])
        completed = subprocess.run(
            [shutil.which("nrmd"), "-y", json.dumps(configuration), ]
        )
        if completed.returncode != 0:
            print("NRM daemon exited with exit code %d" % completed.returncode)
            os.kill(os.getppid(), signal.SIGTERM)

    p = Process(target=daemon)
    p.start()
    try:
        yield NRMD(p)
    finally:
        p.kill()
        subprocess.run(["pkill", "-f", "nrmd"])
        subprocess.run(["pkill", "nrmd"])


class NRMD:
    def __init__(self, daemon):
        self.daemon = daemon
        self.commonOpts = lib.defaultCommonOpts()
        self.upstreampub = nrm.messaging.UpstreamPubClient(
            lib.pubAddress(self.commonOpts)
        )
        self.upstreampub.connect(wait=False)

    def run(self, cmd: str, args: List[str], manifest: dict, sliceID: str):
        """ Upstream request: Run an application via NRM.

        Args:
            cmd (str):
                The name of the binary (absolute or found in PATH)

            args (List[str]):
                The list of arguments

            manifest (dict):
                A dictionary containing the manifest, in the format defined
                by hnrm/hsnrm/hsnrm/dhall/types/manifest.dhall. Examples are a
                vailable in the examples/manifests folder.

            sliceID (str):
                An identifier for the sliceID to run the application into.
        """
        lib.run(
            self.commonOpts,
            lib.mkSimpleRun(
                cmd,
                args,
                list(dict(os.environ).items()),
                json.dumps(manifest),
                sliceID,
            ),
        )

    def actuate(self, actionList: List[Action]) -> None:
        """ Upstream request: Run a list of actions

        Args:
            actionList (List[Action]): A list of actions to run.
        """
        if not lib.action(self.commonOpts, actionList):
            raise (Exception("Could not actuate."))

    def req_cpd(self) -> CPD:
        """ Upstream request: Obtain the current Control Problem Description.
        This is a blocking call.

        Returns:
            CPD: The description of the current Control Problem Description.
        """
        return CPD(lib.cpd(self.commonOpts))

    def req_state(self) -> NRMState:
        """ Upstream request: Obtain the current daemon state.
        This is a blocking call.

        Returns:
            NRMState: The full data structure that entirely describes the
            current state of the NRM daemon. This is useful for debugging
            or general inspection.
        """
        return NRMState(lib.state(self.commonOpts))

    def all_finished(self) -> bool:
        """ Upstream request: Checks NRM to see whether all tasks are finished.
        This is a blocking call.

        Returns:
            bool: True if no tasks are running, False if a task is still
            runninng.
        """
        return lib.finished(self.commonOpts)

    def upstream_recv(self) -> dict:
        """ Upstream listen: Receive a message from NRM's upstream PUB API.
        This is a blocking call.

        Returns:
            dict: A dictionary containing the message that respects the JSON
            schema description in hnrm/resources/schemas/upstream-pub.json.
        """
        return json.loads(self.upstreampub.recv())
