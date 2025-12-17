# demo-netflix-oss-architecture (Spring Boot + Netflix OSS on AWS EC2)

End-to-end **Spring Boot 3.x (Java 17)** Netflix OSS microservices stack deployed on **AWS EC2 Ubuntu 22.04 t3.medium**, with **each service on its own EC2**, fully automated by **Terraform**.

Public entrypoint (only): **Cloud Gateway :8080** → `user-bff` → (**mTLS**) → `mtls-middleware` → `core-backend`.

## Repo Layout (STRICT)

```
/infra/terraform
/services/config-server
/services/eureka-server
/services/cloud-gateway
/services/user-bff
/services/mtls-middleware
/services/core-backend
/config-repo
/scripts/certs
/scripts/provision
/scripts/sanity
/reports
architecture.html
```

## Architecture (Ports)

1. `config-server` : `8888`
2. `eureka-server` : `8761`
3. `cloud-gateway` : `8080` (ONLY public entry)
4. `user-bff` : `8081`
5. `mtls-middleware` : `8443` (HTTPS + mTLS required)
6. `core-backend` : `8082`

Flow (STRICT): `Client -> Gateway -> user-bff -> (mTLS) -> mtls-middleware -> core-backend -> response`

## Prereqs (Local Machine)

- AWS credentials configured for Terraform (env vars or `~/.aws/credentials`)
- Terraform `>= 1.5`
- `bash` + `python3` available locally (Terraform runs `scripts/sanity/run_sanity.sh` via `local-exec`)
  - On Windows: install Git Bash or WSL and ensure `bash` is on `PATH`

## Deploy (terraform apply)

From `infra/terraform`:

```bash
terraform init
terraform apply \
  -var "aws_region=us-east-1" \
  -var "admin_cidr=YOUR_PUBLIC_IP/32" \
  -var "key_name=your-ec2-keypair" \
  -var "repo_url=https://github.com/YOUR_ORG/demo-netflix-oss-architecture.git" \
  -var "git_branch=main"
```

What happens automatically:

- Provisions 6 EC2 instances + security groups (only `8080` public; SSH limited to `admin_cidr`)
- Each VM installs Java 17 + Maven + Git, clones the repo, builds only its own module, installs a systemd unit, starts the service
- Dependency order enforced via waits: Config → Eureka → Backend → Middleware → BFF → Gateway
- mTLS certs are generated on `config-ec2` via `scripts/certs/generate-certs.sh` and distributed via a private S3 bucket
- Runs sanity tests from your local machine and generates:
  - `reports/sanity-report.json`
  - `reports/sanity-report.html`

Gateway URL is printed as Terraform output: `gateway_public_url`.

## Destroy (terraform destroy)

```bash
cd infra/terraform
terraform destroy
```

## API Calls (via Gateway)

Set:

```bash
export GATEWAY_URL="http://<gateway-public-ip>:8080"
```

### A) REST (POST /api/rest/echo)

```bash
curl -sS -X POST "$GATEWAY_URL/api/rest/echo" \
  -H "Content-Type: application/json" \
  -d '{ "type":"REST", "message":"hello-rest", "amount":123 }' | jq
```

### B) SOAP (/ws)

```bash
curl -sS -X POST "$GATEWAY_URL/ws" \
  -H "Content-Type: text/xml; charset=utf-8" \
  -d @- <<'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/"
                  xmlns:pr="http://demo.netflixoss.com/userbff/process">
  <soapenv:Header/>
  <soapenv:Body>
    <pr:ProcessRequest>
      <pr:type>SOAP</pr:type>
      <pr:message>hello-soap</pr:message>
      <pr:amount>456.0</pr:amount>
    </pr:ProcessRequest>
  </soapenv:Body>
</soapenv:Envelope>
EOF
```

WSDL (through gateway):

```bash
curl -sS "$GATEWAY_URL/ws/process.wsdl"
```

### C) GraphQL (/graphql)

```bash
curl -sS -X POST "$GATEWAY_URL/graphql" \
  -H "Content-Type: application/json" \
  -d '{"query":"{ process(type:\"GRAPHQL\", message:\"hello-graphql\", amount:789.0) { computedOutput clientCertificateSubject clientCertificateSerial receivedClientSubject receivedClientSerial } }"}' | jq
```

## mTLS Verification

- `user-bff` presents a client certificate when calling `mtls-middleware`
- `mtls-middleware` requires client auth and validates the client cert using its truststore
- `mtls-middleware` logs and returns:
  - client cert **subject DN**
  - client cert **serial**
- It forwards these to `core-backend` as `X-Client-Subject` and `X-Client-Serial`
- `core-backend` echoes them back in its response to prove the chain

## Reports

After `terraform apply` completes, sanity reports are written locally:

- `reports/sanity-report.json`
- `reports/sanity-report.html`

## Architecture Diagram

Open `architecture.html` in a browser for an animated, interactive end-to-end flow (runtime + bootstrap) with per-service technical details.

## Notes (Security / Demo)

- This is a demo stack. mTLS artifacts are generated automatically at deploy time and distributed via a private S3 bucket for convenience.
- Do not reuse this approach for production key management; use ACM/Private CA, Secrets Manager, or a dedicated PKI workflow.

## Ops (VM)

Each service runs as a systemd unit named after the service:

```bash
sudo systemctl status config-server
sudo systemctl status eureka-server
sudo systemctl status core-backend
sudo systemctl status mtls-middleware
sudo systemctl status user-bff
sudo systemctl status cloud-gateway
```

Logs are appended to:

- `/var/log/<service>/app.log`
