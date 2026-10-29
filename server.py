#!/usr/bin/env python3
"""Flask backend: runs `make build query IOC=<target>` and streams output via SSE."""

import os
import subprocess
from flask import Flask, Response, request, jsonify
from flask_cors import CORS

BASE_DIR = os.path.dirname(os.path.abspath(__file__))

app = Flask(__name__)
CORS(app)


@app.route("/")
def health():
    return jsonify({"status": "ok"})


@app.route("/api/enrich")
def enrich():
    target = request.args.get("target", "").strip()
    if not target:
        return jsonify({"error": "missing target"}), 400

    def generate():
        proc = subprocess.Popen(
            ["make", "build", "query", f"IOC={target}"],
            cwd=BASE_DIR,
            stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
            text=True, bufsize=1
        )
        for line in proc.stdout:
            yield f"data: {line.rstrip()}\n\n"
        proc.wait()
        yield f"data: __DONE__:{proc.returncode}\n\n"

    return Response(generate(), mimetype="text/event-stream")


if __name__ == "__main__":
    app.run(host="127.0.0.1", port=5001, threaded=True)
