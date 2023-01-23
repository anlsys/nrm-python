from build._nrm_cffi import ffi,lib
from typing import Union, List, Callable

class Scope:
    """Scope class for interacting with NRM C interface. Prototyped interface for scope below.
    """

    def __enter__(self, name:str= "nrm-actuator", uuid:str="default-uuid"):
        self._c_actuator_name = ffi.new("char[]", bytes(name, "utf-8"))
        self._actuator_ptr = lib.nrm_actuator_create(self._c_actuator_name)  # intantiate a pointer?

    def __init(self):
        self.__enter__()

    def __exit__(self):
        lib.nrm_actuator_destroy(self._actuator_ptr)

    def __delitem__(self, key):
        lib.nrm_actuator_destroy(self._actuator_ptr)

if __name__ == "__main__":
    with Client() as nrmc:
        pass