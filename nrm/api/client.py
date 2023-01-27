from nrm.api._build._nrm_cffi import ffi, lib
from typing import Union, List, Callable
from dataclasses import dataclass, field


class _NRM_d(dict):
    def __init__(self, *args):
        dict.__init__(self, args)

    def _set_client(self, client):
        self._c_client = client


class _NRMScopes(_NRM_d):
    def __setitem__(self, uuid_key: str, nrm_object: "Scope"):
        super().__setitem__(uuid_key, nrm_object)
        return lib.nrm_client_add_scope(self._c_client, nrm_object._scope_ptr)


class _NRMSensors(_NRM_d):
    def __setitem__(self, uuid_key: str, nrm_object: "Sensor"):
        super().__setitem__(uuid_key, nrm_object)
        return lib.nrm_client_add_sensor(self._c_client, nrm_object._sensor_ptr)


class _NRMSlices(_NRM_d):
    def __setitem__(self, uuid_key: str, nrm_object: "Slice"):
        super().__setitem__(uuid_key, nrm_object)
        return lib.nrm_client_add_slice(self._c_client, nrm_object._slice_ptr)


class _NRMActuators(_NRM_d):
    def __setitem__(self, uuid_key: str, nrm_object: "Actuator"):
        super().__setitem__(uuid_key, nrm_object)
        return lib.nrm_client_add_actuator(self._c_client, nrm_object._actuator_ptr)


@dataclass
class Client:
    """Client class for interacting with NRM C interface. Prototyped interface for client below.
    Tentative usage:
    ```
    from nrm import Client, Actuator
    with Client("tcp://127.0.0.1", 2345, 3456) as nrmc:
        ...
        nrmc.scopes["uuid"] = my_scope

        ...
        nrmc.send_event(get_time(), sensor, scope, 1234)
        ...

    ```
    """

    scopes: _NRMScopes = field(default_factory=_NRMScopes)
    sensors: _NRMSensors = field(default_factory=_NRMSensors)
    slices: _NRMSlices = field(default_factory=_NRMSlices)
    actuators: _NRMActuators = field(default_factory=_NRMActuators)

    def __enter__(
        self, uri: str = "tcp://127.0.0.1", pub_port: int = 2345, rpc_port: int = 3456
    ):
        self._c_client_p = ffi.new("nrm_client_t **")
        self._c_uri = ffi.new("char[]", bytes(uri, "utf-8"))
        self.pub_port = pub_port
        self.rpc_port = rpc_port
        flag = lib.nrm_init(ffi.NULL, ffi.NULL)
        flag = lib.nrm_client_create(
            self._c_client_p, self._c_uri, self.pub_port, self.rpc_port
        )
        self._c_client = self._c_client_p[0]

        for d in [self.scopes, self.sensors, self.slices, self.actuators]:
            d._set_client(self._c_client)

        return self

    def __exit__(self, exc_type, exc_value, traceback):
        lib.nrm_client_destroy(self._c_client_p)

    def actuate(self, actuator: "Actuator", value: float) -> int:
        return lib.nrm_client_actuate(self._c_client, actuator._actuator_ptr, value)

    def send_event(
        self, sensor: "Sensor", scope: "Scope", value: float
    ) -> int:
        timespec_p = ffi.new("nrm_time_t **")
        lib.nrm_time_gettime(timespec_p)
        timespec = timespec_p[0]
        return lib.nrm_client_send_event(
            self._c_client, timespec, sensor._sensor_ptr, scope._scope_ptr, value
        )

    def set_event_listener(self, event_listener: Callable) -> int:
        pass
        # assert event_listener accepts 4 arguments?
        #  with call with: uuid, time, scope, msg->event->value
        # lib.nrm_client_set_event_Pylistener

    def start_event_listener(self, topic: str) -> int:
        topic = ffi.new("char []", bytes(topic, "utf-8"))
        topic_as_nrm_string_t = ffi.new("nrm_string_t *", topic)
        # lib.nrm_client_start_event_Pylistener

    def set_actuate_listener(self, actuate_listener: Callable) -> int:
        pass
        # assert actuate_listener accepts 2 arguments?
        #  will call with: uuid, msg->event->value
        # lib.nrm_client_set_actuate_Pylistener

    def start_actuate_listener(self) -> int:
        pass
        # lib.nrm_client_start_event_Pylistener


if __name__ == "__main__":
    with Client() as nrmc:
        pass
