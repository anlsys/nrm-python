import time
from loguru import logger
from dataclasses import dataclass, field
from typing import Callable, List, Union

from nrm.api._build._nrm_cffi import ffi, lib
from nrm.api.components import NRMActuators, NRMScopes, NRMSensors, NRMSlices


@dataclass
class Client:
    """Client class for interacting with NRM C interface. Use as a context switcher.
    Tentative usage:
    ```
    from nrm.api import Client, Actuator
    with Client("tcp://127.0.0.1", 2345, 3456) as nrmc:
        ...
        nrmc.scopes["uuid"] = my_scope

        ...
        nrmc.send_event(sensor, scope, 1234)
        ...

    ```
    """

    scopes: NRMScopes = field(default_factory=NRMScopes)
    sensors: NRMSensors = field(default_factory=NRMSensors)
    slices: NRMSlices = field(default_factory=NRMSlices)
    actuators: NRMActuators = field(default_factory=NRMActuators)

    def __enter__(
        self, uri: str = "tcp://127.0.0.1", pub_port: int = 2345, rpc_port: int = 3456
    ):
        self._c_client_p = ffi.new("nrm_client_t **")
        self._c_uri = ffi.new("char[]", bytes(uri, "utf-8"))
        self._pyinfo_p = ffi.new("pyinfo_t **")
        self._py_client_h = ffi.new_handle(self)
        self.pub_port = pub_port
        self.rpc_port = rpc_port

        assert not lib.nrm_init(ffi.NULL, ffi.NULL), \
            "NRM library did not initialize successfully"
        logger.debug("NRM initialized")

        assert not lib.nrm_client_create(
            self._c_client_p, self._c_uri, self.pub_port, self.rpc_port
        ), "Python Client was unable to instantiate an underlying NRM C client"
        logger.debug("NRM client created")
        self._c_client = self._c_client_p[0]

        assert not lib.nrm_pyinfo_create(
            self._pyinfo_p,
            self._py_client_h,
            lib._event_listener_wrap,
            lib._actuate_listener_wrap,
        ), "Python Client was unable to instantiate an underlying NRM C structure"
        logger.debug("C pyinfo structure populated")
        self._pyinfo = self._pyinfo_p[0]

        for d in [self.scopes, self.sensors, self.slices, self.actuators]:
            d._set_client(self._c_client)
        logger.debug("NRM client assigned to Scopes, Sensors, Slices, and Actuators dict subclasses")
        logger.info("Client instance initialized. Starting")
        return self

    def __exit__(self, exc_type, exc_value, traceback):
        logger.info("Destroying Client instance")
        lib.nrm_client_destroy(self._c_client_p)

    def actuate(self, actuator: "Actuator", value: float) -> int:
        """Perform an actuation given an actuator and a value to set. Register this actuator
        with the client first:
        ```
        from nrm.api import Client, Actuator
        act = Actuator("my-actuator")
        act.set_choices(1.0, 2.0, 3.0, 4.0)
        with Client("tcp://127.0.0.1", 2345, 3456) as nrmc:
        ```
        NOTE: The given value should've already been set with `actuator_instance.set_values()`.

        Parameters
        ----------
        """
        logger.debug(f"ACTUATING with (actuator: {actuator}), (value: {value})")
        return lib.nrm_client_actuate(self._c_client, actuator._actuator_ptr, value)

    def send_event(self, sensor: "Sensor", scope: "Scope", value: float) -> int:
        """
        Parameters
        ----------
        """
        timespec = lib.nrm_time_fromns(time.time_ns())
        logger.debug(f"SENDING EVENT with (sensor: {sensor}), (value: {value}), (Value: {value})")
        return lib.nrm_client_send_event(
            self._c_client, timespec, sensor._sensor_ptr, scope._scope_ptr, value
        )

    def set_event_listener(self, event_listener: Callable) -> int:
        """
        Parameters
        ----------
        """
        self._event_listener = event_listener
        logger.debug(f"Setting event Python callback: {event_listener}")
        return lib.nrm_client_set_event_Pylistener(self._c_client, self._pyinfo)

    def start_event_listener(self, topic: str) -> int:
        """
        Parameters
        ----------
        """
        topic = ffi.new("char []", bytes(topic, "utf-8"))
        topic_as_nrm_string_t = ffi.new("nrm_string_t *", topic)
        logger.debug(f"Starting event listener. Will call: {self._event_listener}")
        return lib.nrm_client_start_event_listener(self._c_client, topic)

    def set_actuate_listener(self, actuate_listener: Callable) -> int:
        """
        Parameters
        ----------
        """
        self._actuate_listener = actuate_listener
        logger.debug(f"Setting actuate Python callback: {actuate_listener}")
        return lib.nrm_client_set_actuate_Pylistener(self._c_client, self._pyinfo)

    def start_actuate_listener(self) -> int:
        """
        Returns
        -------
        """
        logger.debug(f"Starting actuate listener. Will call: {self._actuate_listener}")
        return lib.nrm_client_start_actuate_listener(self._c_client)

    def _event(self, sensor_uuid, time, scope, value):
        logger.debug(f"Calling event callback: {self._event_listener}")
        return self._event_listener(sensor_uuid, time, scope, value)

    def _actuate(self, uuid, value):
        logger.debug(f"Calling actuate callback: {self._actuate_listener}")
        return self._actuate_listener(uuid, value)


@ffi.def_extern()
def _event_listener_wrap(
    sensor_uuid, timespec, scope, value, py_client
):  # see build.py for the C declaration of this and _actuate_listener_wrap
    logger.debug("In event extern wrapper. Unpacking client")
    return ffi.from_handle(py_client)._event(sensor_uuid, timespec, scope, value)


@ffi.def_extern()
def _actuate_listener_wrap(uuid, value, py_client):
    logger.debug("In actuate extern wrapper. Unpacking client")
    return ffi.from_handle(py_client)._actuate(uuid, value)
