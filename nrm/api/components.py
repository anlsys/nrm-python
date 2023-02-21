from typing import Callable, List, Union
from loguru import logger

from nrm.api._build._nrm_cffi import ffi, lib


class Actuator:
    """Actuator class for interacting with NRM C interface. Prototyped interface for client below.
    Tentative usage:
    ```
    from nrm import Actuator, Client
    with Client("tcp://127.0.0.1", 2345, 3456) as nrmc:

        act = Actuator(name="hello-act")
        nrmc.actuators.append(act)


    ```
    """

    def __init__(self, name: str = "nrm-actuator"):
        self.TYPE = 3
        self._actuator_ptr = ffi.new("nrm_actuator_t **")
        self._c_name = ffi.new("char[]", bytes(name, "utf-8"))
        self._actuator_ptr[0] = lib.nrm_actuator_create(self._c_name)

    def __del__(self):
        lib.nrm_actuator_destroy(self._actuator_ptr)

    def close(self):
        lib.nrm_actuator_destroy(self._actuator_ptr)

    def set_choices(self, *cargs) -> int:
        return lib.nrm_actuator_set_choices(
            self._actuator_ptr[0], len(cargs), list(cargs)
        )

    def set_value(self, value: float) -> int:
        return lib.nrm_actuator_set_value(self._actuator_ptr[0], value)


class Scope:
    """Scope class for interacting with NRM C interface. Prototyped interface for scope below."""

    def __init__(self, name: str = "nrm-scope"):
        self.TYPE = 2
        self._c_name = ffi.new("char[]", bytes(name, "utf-8"))
        self._scope_ptr = lib.nrm_scope_create(self._c_name)

    def __del__(self):
        lib.nrm_scope_destroy(self._scope_ptr)

    def close(self) -> int:
        return lib.nrm_scope_destroy(self._scope_ptr)


class Sensor:
    """Sensor class for interacting with NRM C interface. Prototyped interface for client below.
    Tentative usage:
    ```
    from nrm import Sensor, Actuator
    with Client("tcp://127.0.0.1", 2345, 3456) as nrmc:
        ...
        nrmc.sensors["abc123"] = my_sensor
        ...
        nrmc.send_event(get_time(), sensor, scope, 1234)
        ...

    ```
    """

    def __init__(self, name: str = "nrm-sensor"):
        self.TYPE = 1
        self._sensor_ptr = ffi.new("nrm_sensor_t **")
        self._c_name = ffi.new("char[]", bytes(name, "utf-8"))
        self._sensor_ptr[0] = lib.nrm_sensor_create(self._c_name)

    def __del__(self):
        lib.nrm_sensor_destroy(self._sensor_ptr)

    def close(self):
        lib.nrm_sensor_destroy(self._sensor_ptr)


class Slice:
    """Slice class for interacting with NRM C interface. Prototyped interface for client below.
    Tentative usage:
    ```
    from nrm import Client, Actuator
    with Client("tcp://127.0.0.1", 2345, 3456) as nrmc:
        ...
        my_slice = Slice("nrm-slice", "abc123)
        nrmc.slices["uuid"] = my_slice

        ...
        nrmc.send_event(get_time(), sensor, scope, 1234)
        ...
    ```
    """

    def __init__(self, name: str = "nrm-slice"):
        self.TYPE = 0
        self._slice_ptr = ffi.new("nrm_slice_t **")
        self._c_name = ffi.new("char[]", bytes(name, "utf-8"))
        self._slice_ptr[0] = lib.nrm_slice_create(self._c_name)

    def __del__(self):
        lib.nrm_slice_destroy(self._slice_ptr)

    def close(self):
        lib.nrm_slice_destroy(self._slice_ptr)


class _NRM_d(dict):
    def __init__(self, *args):
        dict.__init__(self, args)

    def _set_client(self, client):
        self._c_client = client


class NRMScopes(_NRM_d):
    def __setitem__(self, uuid_key: str, nrm_object: "Scope"):
        super().__setitem__(uuid_key, nrm_object)
        return lib.nrm_client_add_scope(self._c_client, nrm_object._scope_ptr)


class NRMSensors(_NRM_d):
    def __setitem__(self, uuid_key: str, nrm_object: "Sensor"):
        super().__setitem__(uuid_key, nrm_object)
        return lib.nrm_client_add_sensor(self._c_client, nrm_object._sensor_ptr[0])


class NRMSlices(_NRM_d):
    def __setitem__(self, uuid_key: str, nrm_object: "Slice"):
        super().__setitem__(uuid_key, nrm_object)
        return lib.nrm_client_add_slice(self._c_client, nrm_object._slice_ptr[0])


class NRMActuators(_NRM_d):
    def __setitem__(self, uuid_key: str, nrm_object: "Actuator"):
        super().__setitem__(uuid_key, nrm_object)
        return lib.nrm_client_add_actuator(self._c_client, nrm_object._actuator_ptr[0])
