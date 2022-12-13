from _nrm_cffi import ffi,lib
from dataclasses import dataclass
from typing import Union, List, Callable


@dataclass
class NRMClient:
    """Client class for interacting with NRM C interface. Prototyped interface for client below.

    Tentative usage:

    ```
    with NRMClient() as nrmc:

        ...
        nrmc.add_actuator(my_actuator)
        ...
        nrmc.send_event(get_time(), sensor, scope, 1234)
        ...

    ```

    """

    uri:str = "tcp://127.0.0.1"
    pub_port:int=2345
    rpc_port:int=3456
    actuators: List[NRMActuator] = []
    scopes: List[NRMScope] = []
    sensors: List[NRMSensor] = []
    slices: List[NRMSlice] = []

    def __enter__(self):
        self._c_client = ffi.new("nrm_client_t **")
        self._c_uri = ffi.new("char[]", bytes(self.uri))
        lib.nrm_client_create(self._c_client, self._c_uri, self.pub_port, self.rpc_port)

    def __exit__(self):
        pass
        # lib.nrm_client_destroy

    def actuate(self, actuator:NRMActuator, float:value) -> int:
        pass
        # lib.nrm_client_actuate

    def add_actuator(self, actuator:NRMActuator) -> int:
        pass
        # lib.nrm_client_add_actuator

    def add_scope(self, scope:NRMScope) -> int:
        pass
        # lib.nrm_client_add_scope

    def add_sensor(self, sensor:NRMSensor) -> int:
        pass
        # lib.nrm_client_add_sensor

    def add_slice(self, slice:NRMSlice) -> int:
        pass
        # lib.nrm_client_add_slice

    def find(self, obj:Union[NRMScope, NRMSensor, NRMSlice], uuid:str) -> Union[NRMScope, NRMSensor, NRMSlice]:
        pass
        # lib.nrm_client_find

    def get_actuators(self) -> List[NRMActuator]:
        pass
        # lib.nrm_client_list_actuators

    def get_scopes(self) -> List[NRMScope]:
        pass
        # lib.nrm_client_list_scopes

    def get_sensors(self) -> List[NRMSensor]:
        pass
        # lib.nrm_client_list_sensors

    def get_slices(self) -> List[NRMSlice]:
        pass
        # lib.nrm_client_list_slices

    def remove_slice(self, type:int, uuid:str) -> int:
        pass
        # lib.nrm_client_remove

    def send_event(self, time:int, sensor:NRMSensor, scope:NRMScope, value:float) -> int:
        pass
        # lib.nrm_client_send_event

    def set_event_listener(self, event_listener:Callable) -> int:
        pass
        # lib.nrm_client_set_event_listener

    def start_event_listener(self, topic:str) -> int:
        pass
        # lib.nrm_client_start_event_listener

    def set_actuate_listener(self, actuate_listener:Callable) -> int:
        pass
        # lib.nrm_client_set_actuate_listener

    def start_actuate_listener(self) -> int:
        pass
        # lib.nrm_client_start_actuate_listener