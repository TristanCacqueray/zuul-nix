# Copyright 2021 Red Hat
#
# Licensed under the Apache License, Version 2.0 (the "License"); you may
# not use this file except in compliance with the License. You may obtain
# a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS, WITHOUT
# WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the
# License for the specific language governing permissions and limitations
# under the License.

import argparse
import json
import time
import paho.mqtt.client as mqtt
import requests
import statistics


def on_message(message, measures):
    event = json.loads(message.payload)
    if event["action"] == "success":
        measures[event["change"]] = dict(
            enqueue=event["enqueue_time"] - event["trigger_time"],
            report=event["timestamp"] - event["buildset"]["builds"][0]["end_time"],
        )


def print_summary(measures):
    print("Build count :", len(measures))

    def print_benchmark(name, key):
        xs = list(map(lambda x: x[key], measures.values()))
        print(
            "%s:" % name,
            "mean",
            "%.3f" % statistics.mean(xs),
            "std dev",
            "%.3f" % statistics.pstdev(xs),
        )

    print_benchmark("Enqueue time", "enqueue")
    print_benchmark("Report time ", "report")


def usage():
    parser = argparse.ArgumentParser()
    parser.add_argument("--mqtt", default="localhost")
    parser.add_argument("--count", type=int, default=100)
    return parser.parse_args()


def create_mqtt_client(host, measures):
    client = mqtt.Client("collector")
    client.on_message = lambda client, _d, msg: on_message(msg, measures)
    client.on_connect = lambda client, _d, _f, _r: client.subscribe("zuul/", 0)
    client.username_pw_set("zuul")
    client.connect("127.0.0.1", 1883, 60)
    client.loop_start()
    return client


def create_event(idx):
    # Use zuul-gateway to inject event
    req = requests.post(
        "http://localhost:5000/jobs/%d" % idx,
        data="[]",
        headers={"Content-Type": "application/yaml"},
    )
    if not req.ok:
        print(req)
        raise RuntimeError("Couldn't submit job %d" % idx)


def wait_for_zuul():
    print("[+] Waiting for zuul...")
    while True:
        try:
            if requests.get("http://localhost:9000/api/tenant/default/status").ok:
                break
        except Exception:
            pass


def main():
    args = usage()
    wait_for_zuul()
    measures = dict()
    client = create_mqtt_client(args.mqtt, measures)
    start_time = time.monotonic()
    print("[+] Creating %d jobs..." % args.count)
    for job in range(1, args.count + 1):
        create_event(job)
    print("[+] Waiting for results...")
    while True:
        elapsed = time.monotonic() - start_time
        count = len(measures)
        if elapsed > 10000 or count >= args.count:
            print("\nBenchmark  : %d seconds" % elapsed)
            break
        print("Completed build so far: %d\r" % count, end="")
        time.sleep(1)
    client.loop_stop()
    print_summary(measures)


if __name__ == "__main__":
    main()
