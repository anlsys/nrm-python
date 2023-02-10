import secrets
import time
from nrm.api import Client, Actuator, Scope, Sensor, Slice

act_uuid = secrets.token_hex(3)
sco_uuid = secrets.token_hex(3)
sen_uuid = secrets.token_hex(3)
sli_uuid = secrets.token_hex(3)


def test_client_init():
    print("test_client_init")
    with Client() as nrmc:
        pass


def test_set_objs_to_client():
    print("test_set_objs_to_client")
    act = Actuator("nrm-test-actuator")
    sco = Scope("nrm-test-scope")
    sen = Sensor("nrm-test-sensor")
    sli = Slice("nrm-test-slice")

    with Client() as nrmc:
        nrmc.actuators[act_uuid] = act
        nrmc.scopes[sco_uuid] = sco
        nrmc.sensors[sen_uuid] = sen
        nrmc.slices[sli_uuid] = sli


def test_actuate():
    print("test_actuate")
    act = Actuator("nrm-test-actuator")
    assert not act.set_choices(12.0, 123.0, 1234.0, 12345.0)
    assert not act.set_value(1234.0)
    with Client() as nrmc:
        nrmc.actuators[act_uuid] = act
        assert not nrmc.actuate(act, 123.0)


def test_send_event():
    print("test_send_event")
    sco = Scope("nrm-test-scope")
    sen = Sensor("nrm-test-sensor")
    with Client() as nrmc:
        nrmc.scopes[sco_uuid] = sco
        nrmc.sensors[sen_uuid] = sen
        assert not nrmc.send_event(sen, sco, 1234)


def test_event_callbacks():
    print("test_event_callbacks")
    def print_event_info(*args):
        print("Responding to subscribed event")
        uuid, time, scope, value = args
        print(uuid, time, scope, value)

    sco = Scope("nrm-test-scope")
    sen = Sensor("test-report-numa-pwr")
    with Client() as nrmc:
        nrmc.scopes[sco_uuid] = sco
        nrmc.sensors[sen_uuid] = sen
        assert not nrmc.set_event_listener(print_event_info)
        assert not nrmc.start_event_listener("test-report-numa-pwr")
        assert not nrmc.send_event(sen, sco, 1234)
        time.sleep(0.25)


def test_actuate_callbacks():
    print("test_actuate_callbacks")
    def print_actuate_info(*args):
        print("Responding to actuation request")
        uuid, value = args
        print(uuid, value)


    act = Actuator("nrm-test-actuator")
    assert not act.set_choices(12.0, 123.0, 1234.0, 12345.0)
    assert not act.set_value(1234.0)
    with Client() as nrmc:
        nrmc.actuators[act_uuid] = act
        assert not nrmc.set_actuate_listener(print_actuate_info)
        assert not nrmc.start_actuate_listener()
        assert not nrmc.actuate(act, 123.0)
        time.sleep(0.25)


if __name__ == "__main__":
    test_client_init()
    test_set_objs_to_client()
    test_actuate()
    test_send_event()
    test_event_callbacks()
    test_actuate_callbacks()
