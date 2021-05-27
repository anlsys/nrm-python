###############################################################################
# Copyright 2019 UChicago Argonne, LLC.
# (c.f. AUTHORS, LICENSE)
#
# This file is part of the NRM project.
# For more info, see https://xgitlab.cels.anl.gov/argo/nrm
#
# SPDX-License-Identifier: BSD-3-Clause
###############################################################################

from __future__ import print_function

import logging
import os
import time
import nrm.messaging as msg

logger = logging.getLogger("nrm")


class Progress(object):

    """Implements functions communicating with the NRM downstream interface."""

    def __init__(self, taskID="progressFromPythonID"):
        self.taskID = taskID
        self.timestamp = None
        self.progress_acc = 0

    def shutdown(self):
        self.downstream_event.send(
            timestamp=time.time_ns(),
            threadPause={
                "downstreamThreadID": {
                    "cmdID": self.cmdID,
                    "taskID": self.taskID,
                    "processID": os.getpid(),
                    "rankID": -1,
                    "threadID": 0,
                }
            },
        )

    def progress_report(self, progress):
        current_time = time.time_ns()
        timediff = current_time - self.timestamp
        timediff = timediff / 1000
        self.progress_acc += progress
        if timediff > self.ratelimit_threshold:
            self.downstream_event.send(
                timestamp=current_time,
                threadProgress={
                    "progress": self.progress_acc,
                    "downstreamThreadID": {
                        "cmdID": self.cmdID,
                        "taskID": self.taskID,
                        "processID": os.getpid(),
                        "rankID": -1,
                        "threadID": 0,
                    },
                },
            )
            self.progress_acc = 0
            self.timestamp = current_time

    def setup(self):
        downstream_url = os.environ.get(
            "NRM_DOWNSTREAM_EVENT_URI", "ipc:///tmp/nrm-downstream-event"
        )
        self.downstream_event = msg.DownstreamEventClient(downstream_url)
        self.downstream_event.connect()
        logger.info("downstream pub socket connected to: %s", downstream_url)

        # retrieve our command ID
        self.cmdID = os.environ.get("NRM_CMDID")
        # retrieve our ratelimiting
        self.ratelimit_threshold = int(os.environ.get("NRM_RATELIMIT", "100000"))
        if self.cmdID is None:
            logger.error("missing NRM_CMDID in environment")
            exit(1)
        self.timestamp = time.time_ns()
