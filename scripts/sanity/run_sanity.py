import argparse
import datetime as dt
import json
import sys
import traceback
import urllib.error
import urllib.request
import xml.etree.ElementTree as ET


def http_post(url: str, body: bytes, headers: dict) -> tuple[int, dict, bytes]:
    req = urllib.request.Request(url=url, data=body, method="POST")
    for k, v in headers.items():
        req.add_header(k, v)
    try:
        with urllib.request.urlopen(req, timeout=30) as resp:
            return resp.status, dict(resp.headers.items()), resp.read()
    except urllib.error.HTTPError as e:
        return e.code, dict(e.headers.items()), e.read()


def now_iso() -> str:
    return dt.datetime.utcnow().replace(tzinfo=dt.timezone.utc).isoformat()


def assert_contains(haystack: str, needle: str, msg: str):
    if needle not in haystack:
        raise AssertionError(msg)


def assert_truthy(value, msg: str):
    if not value:
        raise AssertionError(msg)


def rest_test(gateway_url: str) -> dict:
    url = gateway_url.rstrip("/") + "/api/rest/echo"
    payload = {"type": "REST", "message": "hello-rest", "amount": 123.0}
    status, _, raw = http_post(
        url,
        body=json.dumps(payload).encode("utf-8"),
        headers={"Content-Type": "application/json", "Accept": "application/json"},
    )
    data = json.loads(raw.decode("utf-8"))

    assert_truthy(status == 200, f"REST status expected 200, got {status}")
    assert_truthy("computedOutput" in data, "REST response missing computedOutput")
    assert_contains(data["computedOutput"], "processed(", "REST computedOutput does not look like backend output")
    assert_truthy(data.get("clientCertificateSubject"), "REST missing clientCertificateSubject")
    assert_truthy(data.get("clientCertificateSerial"), "REST missing clientCertificateSerial")
    assert_truthy(
        data.get("receivedClientSubject") == data.get("clientCertificateSubject"),
        "REST receivedClientSubject != clientCertificateSubject (mTLS header chain broken)",
    )
    assert_truthy(
        data.get("receivedClientSerial") == data.get("clientCertificateSerial"),
        "REST receivedClientSerial != clientCertificateSerial (mTLS header chain broken)",
    )

    return {"name": "REST", "ok": True, "url": url, "status": status, "response": data}


def graphql_test(gateway_url: str) -> dict:
    url = gateway_url.rstrip("/") + "/graphql"
    query = """
    { process(type: "GRAPHQL", message: "hello-graphql", amount: 456.0) {
        computedOutput
        clientCertificateSubject
        clientCertificateSerial
        receivedClientSubject
        receivedClientSerial
      } }
    """.strip()
    status, _, raw = http_post(
        url,
        body=json.dumps({"query": query}).encode("utf-8"),
        headers={"Content-Type": "application/json", "Accept": "application/json"},
    )
    data = json.loads(raw.decode("utf-8"))

    assert_truthy(status == 200, f"GraphQL status expected 200, got {status}")
    assert_truthy("data" in data and "process" in data["data"], "GraphQL response missing data.process")
    pr = data["data"]["process"]
    assert_contains(pr["computedOutput"], "processed(", "GraphQL computedOutput does not look like backend output")
    assert_truthy(pr.get("clientCertificateSubject"), "GraphQL missing clientCertificateSubject")
    assert_truthy(pr.get("clientCertificateSerial"), "GraphQL missing clientCertificateSerial")
    assert_truthy(
        pr.get("receivedClientSubject") == pr.get("clientCertificateSubject"),
        "GraphQL receivedClientSubject != clientCertificateSubject (mTLS header chain broken)",
    )
    assert_truthy(
        pr.get("receivedClientSerial") == pr.get("clientCertificateSerial"),
        "GraphQL receivedClientSerial != clientCertificateSerial (mTLS header chain broken)",
    )

    return {"name": "GraphQL", "ok": True, "url": url, "status": status, "response": data}


def soap_test(gateway_url: str) -> dict:
    url = gateway_url.rstrip("/") + "/ws"
    soap_body = f"""<?xml version="1.0" encoding="UTF-8"?>
<soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/"
                  xmlns:pr="http://demo.netflixoss.com/userbff/process">
  <soapenv:Header/>
  <soapenv:Body>
    <pr:ProcessRequest>
      <pr:type>SOAP</pr:type>
      <pr:message>hello-soap</pr:message>
      <pr:amount>789.0</pr:amount>
    </pr:ProcessRequest>
  </soapenv:Body>
</soapenv:Envelope>
"""
    status, _, raw = http_post(
        url,
        body=soap_body.encode("utf-8"),
        headers={"Content-Type": "text/xml; charset=utf-8", "Accept": "text/xml"},
    )

    assert_truthy(status == 200, f"SOAP status expected 200, got {status}")

    root = ET.fromstring(raw.decode("utf-8"))
    ns = {
        "soapenv": "http://schemas.xmlsoap.org/soap/envelope/",
        "pr": "http://demo.netflixoss.com/userbff/process",
    }
    resp = root.find(".//pr:ProcessResponse", ns)
    assert_truthy(resp is not None, "SOAP missing ProcessResponse")

    computed = resp.findtext("pr:computedOutput", default="", namespaces=ns)
    subject = resp.findtext("pr:clientCertificateSubject", default="", namespaces=ns)
    serial = resp.findtext("pr:clientCertificateSerial", default="", namespaces=ns)
    recv_subject = resp.findtext("pr:receivedClientSubject", default="", namespaces=ns)
    recv_serial = resp.findtext("pr:receivedClientSerial", default="", namespaces=ns)

    assert_contains(computed, "processed(", "SOAP computedOutput does not look like backend output")
    assert_truthy(subject, "SOAP missing clientCertificateSubject")
    assert_truthy(serial, "SOAP missing clientCertificateSerial")
    assert_truthy(recv_subject == subject, "SOAP receivedClientSubject != clientCertificateSubject")
    assert_truthy(recv_serial == serial, "SOAP receivedClientSerial != clientCertificateSerial")

    return {
        "name": "SOAP",
        "ok": True,
        "url": url,
        "status": status,
        "response": {
            "computedOutput": computed,
            "clientCertificateSubject": subject,
            "clientCertificateSerial": serial,
            "receivedClientSubject": recv_subject,
            "receivedClientSerial": recv_serial,
        },
        "rawXml": raw.decode("utf-8"),
    }


def render_html(report: dict) -> str:
    rows = []
    for t in report["tests"]:
        status = "PASS" if t["ok"] else "FAIL"
        rows.append(
            "<tr>"
            f"<td>{t['name']}</td>"
            f"<td>{status}</td>"
            f"<td>{t.get('status','')}</td>"
            f"<td><code>{t.get('url','')}</code></td>"
            f"<td><pre style='white-space:pre-wrap'>{html_escape(json.dumps(t.get('error') or t.get('response'), indent=2)[:4000])}</pre></td>"
            "</tr>"
        )

    return f"""<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8"/>
  <title>Sanity Report</title>
  <style>
    body {{ font-family: Arial, sans-serif; margin: 24px; }}
    table {{ border-collapse: collapse; width: 100%; }}
    th, td {{ border: 1px solid #ddd; padding: 8px; vertical-align: top; }}
    th {{ background: #f5f5f5; text-align: left; }}
    code {{ background: #f0f0f0; padding: 2px 4px; }}
  </style>
</head>
<body>
  <h1>Sanity Report</h1>
  <p><b>Generated:</b> {report['generatedAt']}</p>
  <p><b>Gateway:</b> <code>{html_escape(report['gatewayUrl'])}</code></p>
  <table>
    <thead>
      <tr><th>Test</th><th>Result</th><th>HTTP</th><th>URL</th><th>Details</th></tr>
    </thead>
    <tbody>
      {''.join(rows)}
    </tbody>
  </table>
</body>
</html>
"""


def html_escape(s: str) -> str:
    return (
        s.replace("&", "&amp;")
        .replace("<", "&lt;")
        .replace(">", "&gt;")
        .replace('"', "&quot;")
        .replace("'", "&#039;")
    )


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--gateway-url", required=True)
    ap.add_argument("--out-json", required=True)
    ap.add_argument("--out-html", required=True)
    args = ap.parse_args()

    report = {"generatedAt": now_iso(), "gatewayUrl": args.gateway_url, "tests": []}

    for fn in (rest_test, soap_test, graphql_test):
        try:
            report["tests"].append(fn(args.gateway_url))
        except Exception as e:
            report["tests"].append(
                {
                    "name": fn.__name__.replace("_test", "").upper(),
                    "ok": False,
                    "error": {"message": str(e), "trace": traceback.format_exc()},
                }
            )

    with open(args.out_json, "w", encoding="utf-8") as f:
        json.dump(report, f, indent=2)

    with open(args.out_html, "w", encoding="utf-8") as f:
        f.write(render_html(report))

    failed = [t for t in report["tests"] if not t.get("ok")]
    if failed:
        print("Sanity checks FAILED. See reports/sanity-report.*", file=sys.stderr)
        sys.exit(1)

    print("Sanity checks PASSED. See reports/sanity-report.*")


if __name__ == "__main__":
    main()

