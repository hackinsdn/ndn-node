#!/usr/bin/python3
from flask import Flask, request, send_file, abort
import os

app_dir = "/tmp/ndn-cert-mgr"
if not os.path.exists(app_dir):
    os.makedirs(app_dir)

app = Flask(__name__)


@app.route("/gen-cert", methods=["POST"])
def generate_cert():
    data = request.get_json()
    print(f"generate_cert params: {data}", flush=True)
    sig = data.get("sig")
    sub = data.get("sub")
    pw = data.get("pw", "changeme")
    force = data.get("force")
    if not sig:
        abort(400, f"Invalid {sig=}")
    if not sub:
        abort(400, f"Invalid {sub=}")

    sig_pem = f"{app_dir}/sig.pem"

    # generate root cert and set it to be the default identity
    os.system(f"ndnsec-cert-dump -i {sig} >{sig_pem} 2>/dev/null")
    if force or not os.path.isfile(sig_pem) or os.path.getsize(sig_pem)==0:
        os.system(f"ndnsec-delete {sig} >/dev/null 2>&1")
        os.system(f"ndnsec-key-gen {sig} > /dev/null")
        os.system(f"ndnsec-cert-dump -i {sig} > {sig_pem}")
    os.system(f"ndnsec-set-default {sig}")

    # generate the certificate (remove previous certs)
    os.system(f"ndnsec-delete {sub} >/dev/null 2>&1")
    os.system(f"ndnsec-key-gen --not-default {sub} > {app_dir}/sub.csr")
    os.system(f"ndnsec-cert-gen -s {sig} -r {app_dir}/sub.csr > {app_dir}/sub.crt")
    os.system(f"ndnsec-cert-install {app_dir}/sub.crt")
    os.system(f"ndnsec-export -P {pw} {sub} > {app_dir}/sub.pem")
    os.system(f"cd {app_dir} && tar -cf bundle.tar sig.pem sub.pem sub.crt")

    return send_file(f"{app_dir}/bundle.tar", as_attachment=True)


if __name__ == "__main__":
    app.run(host="0.0.0.0", port="3000")
