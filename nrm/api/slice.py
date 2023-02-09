from nrm.api._build._nrm_cffi import ffi, lib
from typing import Union, List, Callable


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
        self._c_slice_name = ffi.new("char[]", bytes(name, "utf-8"))
        self._slice_ptr = lib.nrm_slice_create(
            self._c_slice_name
        )  # intantiate a pointer?

    def __delitem__(self, key):
        lib.nrm_slice_destroy(self._slice_ptr)
