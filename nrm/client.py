from _nrm_cffi import ffi,lib
from typing import Union, List, Callable

class Client:
    """Client class for interacting with NRM C interface. Prototyped interface for client below.
    Tentative usage:
    ```
    from nrm import Client, "Actuator"
    with Client("tcp://127.0.0.1", 2345, 3456) as nrmc:
        ...
        nrmc["my_actuator"] = actuator
        ...
        nrmc.send_event(get_time(), sensor, scope, 1234)
        ...

    ```
    """

    def __init__(self):
        self._nrm_objects = {}

    def __enter__(self, uri:str= "tcp://127.0.0.1", pub_port:int=2345, rpc_port:int=3456):
        self._c_client_p = ffi.new("nrm_client_t **")
        self._c_uri = ffi.new("char[]", bytes(uri, "utf-8"))
        self.pub_port = pub_port
        self.rpc_port = rpc_port
        lib.nrm_client_create(self._c_client, self._c_uri, self.pub_port, self.rpc_port)
        self._c_client = self._c_client_p[0]
        # Based on following from cffi docs:
        # p_handle = ffi.new("opaque_t **")
        # lib.init_stuff(p_handle)   # pass the pointer to the 'handle' pointer
        # handle = p_handle[0]       # now we can read 'handle' out of 'p_handle'
        # lib.more_stuff(handle)

    def __exit__(self):
        lib.nrm_client_destroy(self._c_client_p)

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