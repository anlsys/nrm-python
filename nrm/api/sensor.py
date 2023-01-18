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

    def __enter__(self, name:str= "nrm-sensor", uuid:str="default-uuid"):
        self._c_sensor_name = ffi.new("char[]", bytes(name, "utf-8"))
        self._sensor_ptr = lib.nrm_sensor_create(self._c_sensor_name)  # intantiate a pointer?

    def __exit__(self):
        lib.nrm_sensor_destroy(self._sensor_ptr)

    def __delitem__(self, key):
        lib.nrm_sensor_destroy(self._sensor_ptr)
        pass


if __name__ == "__main__":
    with Sensor() as nrmc:
        pass