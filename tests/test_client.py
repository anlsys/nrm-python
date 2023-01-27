import secrets
import time
from nrm.api import Client, Actuator, Scope, Sensor, Slice

act_uuid = secrets.token_hex(3)
sco_uuid = secrets.token_hex(3)
sen_uuid = secrets.token_hex(3)
sli_uuid = secrets.token_hex(3)


def test_client_init():
    with Client() as nrmc:
        # evaluate nrmc
        pass


def test_set_objs_to_client():

    act = Actuator("nrm-test-actuator", act_uuid)
    sco = Scope("nrm-test-scope", sco_uuid)
    sen = Sensor("nrm-test-sensor", sen_uuid)
    sli = Slice("nrm-test-slice", sli_uuid)
    # assert names, pointers, objects are instantiated underneath for each

    with Client() as nrmc:
        nrmc.actuators[act_uuid] = act
        nrmc.scopes[sco_uuid] = sco
        nrmc.sensors[sen_uuid] = sen
        nrmc.slices[sli_uuid] = sli
        # assert both py and C client contains new objects


def test_actuate():
    act = Actuator("nrm-test-actuator", act_uuid)
    with Client() as nrmc:
        nrmc.actuators[act_uuid] = act
        flag = nrmc.actuate(act, 1234)
        # assert flag == 0, read log?


def test_send_event():
    sco = Scope("nrm-test-scope", sco_uuid)
    sen = Sensor("nrm-test-sensor", sen_uuid)
    with Client() as nrmc:
        nrmc.scopes[sco_uuid] = sco
        nrmc.sensors[sen_uuid] = sen
        now = int(time.time())
        flag = nrmc.send_event(now, sen, sco, 1234)
        # assert flag == 0, read log?


def test_event_callbacks():

    def print_event_info(*args):
        print("Responding to subscribed event")
        uuid, time, scope, value = args
        print(uuid, time, scope, value)

    with Client() as nrmc:
        flag = nrmc.set_event_listener(print_event_info)
        # check if pyfn has made it into client struct?
        flag = nrmc.start_event_listener("test-report-numa-pwr")
        # check logs?


def test_actuate_callbacks():
    def print_actuate_info(*args):
        print("Responding to actuation request")
        uuid, value = args
        print(uuid, value)

    with Client() as nrmc:
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
