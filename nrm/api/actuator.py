from nrm.api._build._nrm_cffi import ffi, lib
from typing import Union, List, Callable


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
        self._c_actuator_name = ffi.new("char[]", bytes(name, "utf-8"))
        self._actuator_ptr = lib.nrm_actuator_create(
            self._c_actuator_name
        )  # intantiate a pointer?

    def __delitem__(self, key):
        lib.nrm_actuator_destroy(self._actuator_ptr)

    def set_choices(self, *cargs) -> int:
        return lib.nrm_actuator_set_choices(self._actuator_ptr, len(cargs), list(cargs))

    def set_value(self, value: float) -> int:
        return lib.nrm_actuator_set_value(self._actuator_ptr, value)
