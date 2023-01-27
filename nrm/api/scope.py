from nrm.api._build._nrm_cffi import ffi, lib
from typing import Union, List, Callable


class Scope:
    """Scope class for interacting with NRM C interface. Prototyped interface for scope below."""

    def __init__(self, name: str = "nrm-scope", uuid: str = "default-uuid"):
        self._c_scope_name = ffi.new("char[]", bytes(name, "utf-8"))
        self._scope_ptr = lib.nrm_scope_create(
            self._c_scope_name
        )  # intantiate a pointer?

    def __delitem__(self):
        lib.nrm_actuator_destroy(self._actuator_ptr)
