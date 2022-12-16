from build._nrm_cffi import ffi,lib
from typing import Union, List, Callable

class Scope:
    """Scope class for interacting with NRM C interface. Prototyped interface for scope below.
    """

    def __init__(self):
        self._nrm_objects = {}

    def actuate(self, actuator:"Actuator", value:float) -> int:
        return lib.nrm_client_actuate(self._c_client, actuator._c_actuator, value)

    def send_event(self, time:int, sensor:"Sensor", scope:"Scope", value:float) -> int:
        return lib.nrm_client_send_event(self._c_client, time, sensor._c_sensor, scope._c_scope, value)

    def set_event_listener(self, event_listener:Callable) -> int:
        pass
        # lib.nrm_client_set_event_listener

    def start_event_listener(self, topic:str) -> int:
        topic = ffi.new("char []", bytes(topic, "utf-8"))
        topic_as_nrm_string_t = ffi.new("nrm_string_t *", topic)
        return lib.nrm_client_start_event_listener(self._c_client, topic_as_nrm_string_t)

    def set_actuate_listener(self, actuate_listener:Callable) -> int:
        pass
        # lib.nrm_client_set_actuate_listener

    def start_actuate_listener(self) -> int:
        pass
        return lib.nrm_client_start_actuate_listener(self._c_client)


if __name__ == "__main__":
    with Client() as nrmc:
        pass