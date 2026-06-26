import os
import time
import threading
import multiprocessing
import ctypes
import math
from flask import Flask, jsonify

app = Flask(__name__)

CPU_PERCENT = int(os.environ.get("CPU_PERCENT", 80))
RAM_PERCENT = int(os.environ.get("RAM_PERCENT", 0))
DURATION = int(os.environ.get("BURN_DURATION", 30))

_burn_lock = threading.Lock()
_burn_active = False


def _cpu_worker(stop_event, target_percent, duration):
    deadline = time.time() + duration
    cycle = 0.1
    on_time = cycle * (target_percent / 100.0)
    off_time = cycle - on_time
    while not stop_event.is_set() and time.time() < deadline:
        start = time.time()
        while time.time() - start < on_time:
            math.factorial(5000)
        time.sleep(off_time)


def _ram_worker(stop_event, target_percent, duration):
    total = os.sysconf("SC_PAGE_SIZE") * os.sysconf("SC_PHYS_PAGES")
    size = int(total * target_percent / 100)
    buf = ctypes.create_string_buffer(size)
    ctypes.memset(buf, 0, size)
    stop_event.wait(timeout=duration)


def _run_burn(cpu_pct, ram_pct, duration):
    global _burn_active
    stop = threading.Event()
    threads = []

    num_cpus = multiprocessing.cpu_count()
    if cpu_pct > 0:
        for _ in range(num_cpus):
            t = threading.Thread(target=_cpu_worker, args=(stop, cpu_pct, duration), daemon=True)
            t.start()
            threads.append(t)

    if ram_pct > 0:
        t = threading.Thread(target=_ram_worker, args=(stop, ram_pct, duration), daemon=True)
        t.start()
        threads.append(t)

    time.sleep(duration)
    stop.set()
    for t in threads:
        t.join(timeout=5)

    with _burn_lock:
        _burn_active = False


@app.route("/")
def healthz():
    return jsonify({"status": "ok"}), 200


@app.route("/burn")
def burn():
    global _burn_active
    with _burn_lock:
        if _burn_active:
            return jsonify({"status": "already burning"}), 409
        _burn_active = True

    t = threading.Thread(target=_run_burn, args=(CPU_PERCENT, RAM_PERCENT, DURATION), daemon=True)
    t.start()

    return jsonify({
        "status": "burning",
        "cpu_percent": CPU_PERCENT,
        "ram_percent": RAM_PERCENT,
        "duration_seconds": DURATION,
    }), 202


if __name__ == "__main__":
    port = int(os.environ.get("PORT", 8080))
    app.run(host="0.0.0.0", port=port)
