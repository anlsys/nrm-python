from build._nrm_cffi import ffi,lib
from typing import Union, List, Callable

class Slice:
    """Slice class for interacting with NRM C interface. Prototyped interface for client below.
    Tentative usage:
    ```
    from nrm import Slice, Actuator
    with Slice() as nrms:
        ...
        nrmc["my_actuator"] = actuator
        ...
        nrmc.send_event(get_time(), slice, scope, 1234)
        ...

    ```
    """

    def __enter__(self, name:str= "nrm-slice", uuid:str="default-uuid"):
        self._c_slice_name = ffi.new("char[]", bytes(name, "utf-8"))
        self._slice_ptr = lib.nrm_slice_create(self._c_slice_name)  # intantiate a pointer?

    def __exit__(self):
        lib.nrm_slice_destroy(self._slice_ptr)

    def __delitem__(self, key):
        lib.nrm_slice_destroy(self._slice_ptr)
