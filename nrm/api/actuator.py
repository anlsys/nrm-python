from _build._nrm_cffi import ffi,lib
from typing import Union, List, Callable

class Actuator:
    """Actuator class for interacting with NRM C interface. Prototyped interface for client below.
    Tentative usage:
    ```
    from nrm import Actuator, Client
    with Client("tcp://127.0.0.1", 2345, 3456) as nrmc:

        act = Actuator(name="hello-act", uuid="abcd1234")
        nrmc.actuators.append(act)


    ```
    """

    def __init__(self, name:str= "nrm-actuator", uuid:str="default-uuid"):
        self._c_actuator_name = ffi.new("char[]", bytes(name, "utf-8"))
        self._actuator_ptr = lib.nrm_actuator_create(self._c_actuator_name)  # intantiate a pointer?

    def __delitem__(self, key):
        lib.nrm_actuator_destroy(self._actuator_ptr)