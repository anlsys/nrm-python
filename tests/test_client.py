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
    # assert names, pointers, objects are instantiated underneath for each

    with Client() as nrmc:
        nrmc.actuators[act_uuid] = act
        nrmc.scopes[sco_uuid] = sco
        nrmc.sensors[sen_uuid] = sen
        nrmc.slices[sli_uuid] = sli
        # assert both py and C client contains new objects


def test_actuate():
    print("test_actuate")
    act = Actuator("nrm-test-actuator")
    act.set_choices(12.0, 123.0, 1234.0, 12345.0)
    act.set_value(1234.0)
    with Client() as nrmc:
        nrmc.actuators[act_uuid] = act
        flag = nrmc.actuate(act, 123.0)
        # assert flag == 0, read log?


def test_send_event():
    print("test_send_event")
    sco = Scope("nrm-test-scope")
    sen = Sensor("nrm-test-sensor")
    with Client() as nrmc:
        nrmc.scopes[sco_uuid] = sco
        nrmc.sensors[sen_uuid] = sen
        flag = nrmc.send_event(sen, sco, 1234)
        # assert flag == 0, read log?


def test_event_callbacks():
    print("test_event_callbacks")
    def print_event_info(*args):
        print("Responding to subscribed event")
        uuid, time, scope, value = args
        print(uuid, time, scope, value)

    sco = Scope("nrm-test-scope")
    with Client() as nrmc:
        nrmc.scopes[sco_uuid] = sco
        flag = nrmc.set_event_listener(print_event_info)
        # check if pyfn has made it into client struct?
        flag = nrmc.start_event_listener("test-report-numa-pwr")
        # check logs?


def test_actuate_callbacks():
    print("test_actuate_callbacks")
    def print_actuate_info(*args):
        print("Responding to actuation request")
        uuid, value = args
        print(uuid, value)


    act = Actuator("nrm-test-actuator")
    act.set_choices(12.0, 123.0, 1234.0, 12345.0)
    act.set_value(1234.0)
    with Client() as nrmc:
        nrmc.actuators[act_uuid] = act
        flag = nrmc.set_actuate_listener(print_actuate_info)
        # check if pyfn has made it into client struct?
        flag = nrmc.start_actuate_listener()
        # check logs?


if __name__ == "__main__":
    test_client_init()
    test_set_objs_to_client()
    test_actuate()
    test_send_event()
    test_event_callbacks()
    test_actuate_callbacks()
