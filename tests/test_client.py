import secrets
import pytest
from nrm.api import Client, Actuator, Scope, Sensor, Slice


def test_client_objs_init():
    with Client("tcp://127.0.0.1", 2345, 3456) as nrmc:
        act_uuid = secrets.token_hex(3)
        sco_uuid = secrets.token_hex(3)
        sen_uuid = secrets.token_hex(3)
        sli_uuid = secrets.token_hex(3)

        act = Actuator("nrm-test-actuator", act_uuid)
        sco = Scope("nrm-test-scope", sco_uuid)
        sen = Sensor("nrm-test-sensor", sen_uuid)
        sli = Slice("nrm-test-slice", sli_uuid)

def test_client_delete():
    pass

def test_set_objs_to_client():
    with Client("tcp://127.0.0.1", 2345, 3456) as nrmc:
        act_uuid = secrets.token_hex(3)
        sco_uuid = secrets.token_hex(3)
        sen_uuid = secrets.token_hex(3)
        sli_uuid = secrets.token_hex(3)

        act = Actuator("nrm-test-actuator", act_uuid)
        sco = Scope("nrm-test-scope", sco_uuid)
        sen = Sensor("nrm-test-sensor", sen_uuid)
        sli = Slice("nrm-test-slice", sli_uuid)

        nrmc.actuators[act_uuid] = act
        nrmc.scopes[sco_uuid] = sco
        nrmc.sensors[sen_uuid] = sen
        nrmc.slices[sli_uuid] = sli

def test_actuate():
    pass

def test_send_event():
    pass

def test_event_callbacks():
    pass

def test_actuate_callbacks():
    pass


if __name__ == "__main__":
    test_client_objs_init()
    test_client_delete()
    test_set_objs_to_client()
    test_actuate()
    test_send_event()
    test_event_callbacks()
    test_actuate_callbacks()
