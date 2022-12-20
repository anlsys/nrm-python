from build._nrm_cffi import ffi,lib
from typing import Union, List, Callable

class Sensor:
    """Sensor class for interacting with NRM C interface. Prototyped interface for client below.
    Tentative usage:
    ```
    from nrm import Sensor, Actuator
    with Sensor() as nrms:
        ...
        nrmc["my_actuator"] = actuator
        ...
        nrmc.send_event(get_time(), sensor, scope, 1234)
        ...

    ```
    """

    def __init__(self):
        self._nrm_objects = {}

    def __enter__(self, name:str= "nrm-sensor", uuid:str="default-uuid"):
        self._c_sensor_name = ffi.new("char[]", bytes(name, "utf-8"))
        sensor_ptr = lib.nrm_sensor_create(self._c_sensor_name)  # intantiate a pointer?

    def __exit__(self):
        lib.nrm_sensor_destroy(self._c_sensor_p)

    def __setitem__(self, uuid_key:str, nrm_object:Union["Scope", "Sensor", "Slice", "Actuator"]):
        self._nrm_objects[key] = nrm_object
        if isinstance(nrm_object, "Scope"):
            return lib.nrm_client_add_scope(self._c_client, nrm_object._c_scope)
        elif isinstance(nrm_object, "Sensor"):
            return lib.nrm_client_add_sensor(self._c_client, nrm_object._c_sensor)
        elif isinstance(nrm_object, "Slice"):
            return lib.nrm_client_add_slice(self._c_client, nrm_object._c_slice)
        elif isinstance(nrm_object, "Actuator"):
            return lib.nrm_client_add_actuator(self._c_client, nrm_object._c_actuator)

    def __getitem__(self, key):
        # lib.nrm_client_find
        return self._nrm_objects[key]

    def __delitem__(self, key):
        pass


if __name__ == "__main__":
    with Sensor() as nrmc:
        pass