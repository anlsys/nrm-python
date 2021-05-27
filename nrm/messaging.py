###############################################################################
# Copyright 2019 UChicago Argonne, LLC.
# (c.f. AUTHORS, LICENSE)
#
# This file is part of the NRM project.
# For more info, see https://xgitlab.cels.anl.gov/argo/nrm
#
# SPDX-License-Identifier: BSD-3-Clause
###############################################################################

import json
import os
import logging
import yaml
import uuid
from jsonschema import Draft4Validator
import zmq
import warlock
import zmq.utils
import zmq.utils.monitor
from zmq.eventloop import zmqstream


_logger = logging.getLogger("nrm")
_jsonexts = ["json"]
_yamlexts = ["yml", "yaml"]


def loadschema(ext, api):
    sourcedir = os.path.dirname(os.path.realpath(__file__))
    with open(os.path.join(sourcedir, "schemas", api + "." + ext)) as f:
        if ext in _jsonexts:
            s = json.load(f)
        elif ext in _yamlexts:
            s = yaml.load(f)
        else:
            raise ("Schema extension not in %s" % str(_jsonexts + _yamlexts))
        Draft4Validator.check_schema(s)
        return warlock.model_factory(s)


def send(apiname=None, cons=dict):
    if apiname:
        model = loadschema("json", apiname)
    else:
        model = None

    def wrap(cls):

        if model:

            def send(self, *args, **kwargs):
                self.socket.send(json.dumps(model(cons(*args, **kwargs))).encode())

        else:

            def send(self, msg):
                try:
                    m = msg.encode()
                except Exception as e:
                    m = msg
                self.socket.send(m)

        setattr(cls, "send", send)

        def send_multi(self, msgs):
            for msg in msgs:
                send(self, msg)

        setattr(cls, "send_multi", send_multi)

        return cls

    return wrap


def recv_callback(apiname=None):
    if apiname:
        return recv_callback_api(apiname)
    else:
        return recv_callback_noapi()


def recv_callback_noapi():
    def wrap(cls):
        def recv(self):
            wire = self.socket.recv()
            _logger.info("received message: %r", wire)
            return wire

        def do_recv_callback(self, frames):
            _logger.info("receiving message: %r", frames)
            assert len(frames) == 2
            msg = frames[1]
            try:
                identity = frames[0].decode()
            except UnicodeDecodeError as e:
                identity = "unassigned"
            assert self.callback
            self.callback(msg, identity)

        def setup_recv_callback(self, callback):
            self.stream = zmqstream.ZMQStream(self.socket)
            self.callback = callback
            self.stream.on_recv(self.do_recv_callback)

        setattr(cls, "recv", recv)
        setattr(cls, "do_recv_callback", do_recv_callback)
        setattr(cls, "setup_recv_callback", setup_recv_callback)

        return cls

    return wrap


def recv_callback_api(apiname):
    def wrap(cls):
        model = loadschema("json", apiname)

        def recv(self):
            wire = self.socket.recv()
            _logger.debug("received message: %r", wire)
            return model(json.loads(wire))

        def do_recv_callback(self, frames):
            _logger.info("receiving message: %r", frames)
            assert len(frames) == 2
            msg = model(json.loads(frames[1]))
            assert self.callback
            self.callback(msg, str(frames[0]))

        def setup_recv_callback(self, callback):
            self.stream = zmqstream.ZMQStream(self.socket)
            self.callback = callback
            self.stream.on_recv(self.do_recv_callback)

        setattr(cls, "recv", recv)
        setattr(cls, "do_recv_callback", do_recv_callback)
        setattr(cls, "setup_recv_callback", setup_recv_callback)

        return cls

    return wrap


class RPCClient(object):

    """Implements the message layer client to the upstream RPC API."""

    def __init__(self, address):
        self.address = address
        self.uuid = str(uuid.uuid4())
        self.zmq_context = zmq.Context.instance()
        self.socket = self.zmq_context.socket(zmq.DEALER)
        self.socket.setsockopt(zmq.IDENTITY, self.uuid.encode())
        self.socket.setsockopt(zmq.SNDHWM, 0)
        self.socket.setsockopt(zmq.RCVHWM, 0)

    def connect(self, wait=True):
        """Connect, and wait for the socket to be connected."""
        monitor = self.socket.get_monitor_socket()
        self.socket.connect(self.address)
        while wait:
            msg = zmq.utils.monitor.recv_monitor_message(monitor)
            _logger.debug("monitor message: %r", msg)
            if int(msg["event"]) == zmq.EVENT_CONNECTED:
                _logger.debug("socket connected")
                break
        self.socket.disable_monitor()


class RPCServer(object):

    """Implements the message layer server to the upstream RPC API."""

    def __init__(self, address):
        self.address = address
        self.zmq_context = zmq.Context.instance()
        self.socket = self.zmq_context.socket(zmq.ROUTER)
        self.socket.setsockopt(zmq.SNDHWM, 0)
        self.socket.setsockopt(zmq.RCVHWM, 0)
        self.socket.bind(address)


@recv_callback()
class UpstreamRPCServer(RPCServer):

    """Implements the message layer server to the upstream RPC API."""

    def send(self, client_uuid, msg):
        """Sends a message to the identified client."""
        _logger.info("sending message: %r to client: %r", msg, client_uuid)
        self.socket.send_multipart([client_uuid.encode(), msg.encode()])


@send()
class UpstreamPubServer(object):

    """Implements the message layer server for the upstream PUB/SUB API."""

    def __init__(self, address):
        self.address = address
        self.zmq_context = zmq.Context.instance()
        self.socket = self.zmq_context.socket(zmq.PUB)
        self.socket.setsockopt(zmq.LINGER, 0)
        self.socket.setsockopt(zmq.SNDHWM, 0)
        self.socket.bind(address)


class UpstreamPubClient(object):

    """Implements the message layer client to the upstream Pub API."""

    def __init__(self, address):
        self.address = address
        self.zmq_context = zmq.Context.instance()
        self.socket = self.zmq_context.socket(zmq.SUB)
        self.socket.setsockopt(zmq.RCVHWM, 0)
        self.socket.setsockopt_string(zmq.SUBSCRIBE, "")

    def connect(self, wait=True):
        """Creates a monitor socket and wait for the connect event."""
        monitor = self.socket.get_monitor_socket()
        self.socket.connect(self.address)
        while wait:
            msg = zmq.utils.monitor.recv_monitor_message(monitor)
            _logger.debug("monitor message: %r", msg)
            if int(msg["event"]) == zmq.EVENT_CONNECTED:
                _logger.debug("socket connected")
                break
        self.socket.disable_monitor()

    def recv(self):
        """Receives a message and returns it."""
        frames = self.socket.recv_multipart()
        _logger.info("received message: %r", frames)
        assert len(frames) == 1
        return frames[0]

    def do_recv_callback(self, frames):
        """Receives a message from zmqstream.on_recv, passing it to a user
        callback."""
        _logger.info("receiving message: %r", frames)
        assert len(frames) == 1
        assert self.callback
        self.callback(frames[0])

    def setup_recv_callback(self, callback):
        """Setup a ioloop-backed callback for receiving messages."""
        self.stream = zmqstream.ZMQStream(self.socket)
        self.callback = callback
        self.stream.on_recv(self.do_recv_callback)


@recv_callback()
class DownstreamEventServer(RPCServer):
    pass

    """Implements the message layer server for the downstream event API."""


def downHeader(*args, **kwargs):
    assert len(kwargs) == 2
    assert len(args) == 0
    ret = {"timestamp": kwargs.pop("timestamp")}
    ret["info"] = kwargs
    return ret


@send("downstreamEvent", downHeader)
class DownstreamEventClient(RPCClient):
    pass

    """Implements the message layer client for the downstream event API."""
