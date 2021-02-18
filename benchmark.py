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
import select
import socket
import threading
import statistics


def on_message(message, measures):
    event = json.loads(message.payload)
    if event["action"] == "success":
        measures[event["change"]] = dict(
            enqueue=event["enqueue_time"] - event["trigger_time"],
            report=event["timestamp"] - event["buildset"]["builds"][0]["end_time"],
        )


def on_metric(data, metrics):
    metric, rest = data.split(":", 1)
    value, typ = rest.split("|", 1)
    metric_name = typ + metric
    if typ == "c":
        metrics.setdefault(metric_name, 0)
        metrics[metric_name] += int(1)
    elif typ == "g":
        metrics[metric_name] = value
    elif typ == "ms":
        metrics.setdefault(metric_name, [])
        metrics[metric_name].append(value)
    else:
        print("Unknown metrics", data)


def print_summary(measures, metrics):
    print("Build count :", len(measures))

    def print_benchmark(name, xs):
        print(
            "%s:" % name,
            "mean",
            "%.5f" % statistics.mean(xs),
            "std dev",
            "%.5f" % statistics.pstdev(xs),
        )

    def print_measures(name, key):
        print_benchmark(name, list(map(lambda x: x[key], measures.values())))

    print_measures("Enqueue time     ", "enqueue")
    print_measures("Report time      ", "report")

    def print_metrics(name, key, subkey):
        print_benchmark(
            name,
            list(
                map(
                    lambda metric: float(metric[1]),
                    filter(
                        lambda metric: metric[0].endswith(subkey),
                        map(lambda metric: metric.split(":"), metrics[key]),
                    ),
                )
            ),
        )

    print_metrics(
        "Scheduler enqueue",
        "mszuul.tenant.default.pipeline.check.project.localhost",
        "enqueue_time",
    )


def usage():
    parser = argparse.ArgumentParser()
    parser.add_argument("--mqtt", default="localhost")
    parser.add_argument("--count", type=int, default=100)
    return parser.parse_args()


def run_statsd(skt, metrics):
    poll = select.poll()
    poll.register(skt, select.POLLIN)
    while metrics["collect"]:
        if not poll.poll(5):
            continue
        pkt = skt.recvfrom(1024)
        if not pkt:
            break
        for metric in pkt[0].strip().decode("utf-8").split("\n"):
            on_metric(metric, metrics)
    skt.close()


def create_statsd_server(metrics):
    skt = socket.socket(socket.AF_INET6, socket.SOCK_DGRAM)
    skt.bind(("", 8125))
    server = threading.Thread(target=run_statsd, args=(skt, metrics))
    server.start()
    return server


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
    measures, metrics = dict(), dict(collect=True)
    client = create_mqtt_client(args.mqtt, measures)
    server = create_statsd_server(metrics)
    start_time = time.monotonic()
    print("[+] Creating %d jobs..." % args.count)
    for job in range(1, args.count + 1):
        create_event(job)
    print("[+] Waiting for results...")
    while True:
        elapsed = time.monotonic() - start_time
        count = len(measures)
        if elapsed > 10000 or count >= args.count:
            print("\nBenchmark   : %.2f seconds" % elapsed)
            break
        print("Completed build so far: %d\r" % count, end="")
        time.sleep(1)
    client.loop_stop()
    metrics["collect"] = False
    server.join()
    print_summary(measures, metrics)
    json.dump(metrics, open("/tmp/metrics.json", "w"))


if __name__ == "__main__":
    main()
