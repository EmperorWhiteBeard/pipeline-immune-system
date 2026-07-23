# pipeline-immune-system

**SentinelOps** — a GitOps pipeline that scores release risk before deploy, and diagnoses its own failures after deploy.

> _Why this repo name?_ Three independent scanners (SonarQube, OWASP Dependency-Check, Trivy) act like antibodies, screening every build before it's allowed into the bloodstream of the cluster. When something still gets through and the app gets sick in production, the system doesn't just alert — it diagnoses *why* and heals itself via an automatic Git-based rollback. Hence: pipeline immune system.

[Architecture diagram and risk-score-vs-error-rate dashboard screenshot go here once Stage 3 is done]

---

## What it does

1. **Build & Risk Gate** — every push triggers Jenkins, which builds the app, pushes the artifact to Nexus, then runs SonarQube, OWASP Dependency-Check, and Trivy in parallel. A custom Python scoring engine (`scoring/risk_score.py`) aggregates all three into a single 0–100 weighted risk score. Low score → auto-promote. High score → a Slack approval card gates the deploy.
2. **GitOps Deploy & Live Watch** — ArgoCD continuously reconciles the cluster from Git. Datadog monitors the running app and infrastructure (e.g. Jenkins container health), tracking the risk score history against live error rate and alerting to Slack on failure/recovery.
3. **Failure Diagnosis & Rollback** — if production error rate/latency crosses a threshold, a Flask listener pulls pod logs and the last build's scan reports, classifies the root cause (quality-gate fail / critical CVE / runtime fail), posts it to Slack, and calls the ArgoCD API to roll back to the last known-good commit.

The closed loop: the same risk score that gated the deploy is the first thing the failure classifier checks. A low-risk build that still fails in production is a signal the scoring weights need tuning — a real, discussable insight rather than just tool-wiring.

## Payload application

A deliberately simple Spring Boot REST API (task tracker) — `POST /tasks`, `GET /tasks`, `DELETE /tasks/{id}`, in-memory or H2-backed. It exists to give the pipeline something real to build, scan, and deploy. Exposes `/health` for Kubernetes probes and `/actuator/metrics` for metrics scraping.

## Tech stack

| Layer | Tool | Role |
|---|---|---|
| Plan & Code | Git / GitHub | Source control, webhook trigger into Jenkins |
| Build | Maven | Compiles/packages the Spring Boot app |
| CI Engine | Jenkins | Orchestrates all pipeline stages |
| Static Code Analysis | SonarQube | Code quality score (input #1) |
| SCA | OWASP Dependency-Check | Dependency CVE score (input #2) |
| Container Security | Trivy | Container image CVE score (input #3) |
| Artifact/Container Registry | Nexus | Stores build artifacts + Docker images |
| IaC | Terraform | Provisions the EC2 instance, security group, and key pair |
| Containerization | Docker | Packages the app and runs the CI stack |
| Orchestration | Kubernetes (k3s) | Runs the live app pods on the EC2 host |
| CD / GitOps | ArgoCD | Syncs cluster state from Git, performs rollback |
| Observability | Datadog | Container/infra health monitoring (e.g. Jenkins uptime), metrics, alerting — risk-score-vs-error-rate dashboard |
| Alerts | Slack Webhooks | Approval cards, root-cause alerts, Datadog infra alerts |
| Custom glue | Python (`scoring/`, `rootcause/`) | Aggregates scanner output into one score; classifies failure type |

## Repo structure

```
.
├── app/                      # Spring Boot payload app (Stage 1)
├── pipeline/                 # Jenkinsfile and pipeline stage scripts (Stage 2)
├── scoring/                  # risk_score.py — the weighted scoring engine (Stage 2)
├── rootcause/                # Failure classifier + Flask webhook listener (Stage 4)
├── infra/
│   ├── terraform/
│   │   ├── modules/ec2-host/        # Reusable EC2 + k3s bootstrap module
│   │   └── environments/
│   │       ├── local/                # Primary dev environment (AWS ap-south-1)
│   │       └── cloud/                # Retired placeholder
│   ├── docker-compose.cicd.yml # Jenkins + SonarQube + Nexus
│   └── scripts/
│       ├── bootstrap.sh       # One-command Stage 0 setup
│       └── teardown.sh        # One-command Stage 0 teardown
├── k8s/
│   ├── base/                  # Kustomize base manifests
│   └── overlays/local/        # Local-cluster overlay
├── argocd/                    # ArgoCD Application manifests
├── monitoring/
│   └── datadog/               # Datadog monitor configs (Jenkins container health + Slack alerting)
├── slack/                     # Block Kit message templates
└── docs/                      # Architecture diagrams, screenshots
```

## Getting started (Stage 0)

Prerequisites: Terraform, AWS CLI (configured with `aws configure`).

1. Get your public IP:
   ```bash
   curl -s https://checkip.amazonaws.com
   ```

2. Create your Terraform variables file:
   ```bash
   cp infra/terraform/environments/local/terraform.tfvars.example infra/terraform/environments/local/terraform.tfvars
   # Edit terraform.tfvars and set allowed_cidr to YOUR_PUBLIC_IP/32
   ```

3. Bootstrap the environment:
   ```bash
   ./infra/scripts/bootstrap.sh
   ```

   This provisions an Ubuntu 22.04 EC2 instance (`m7i-flex.large`) in `ap-south-1` via Terraform. The instance automatically installs Docker, k3s, and starts Jenkins, SonarQube, and Nexus via Docker Compose (cloud-init). After ~2–3 minutes, the services are ready.

4. Save the private key and SSH in:
   ```bash
   cd infra/terraform/environments/local
   terraform output -raw private_key_pem > sentinelops-key.pem
   chmod 600 sentinelops-key.pem
   ssh -i sentinelops-key.pem ubuntu@$(terraform output -raw public_ip)
   ```

| Service | URL | Default credentials |
|---|---|---|
| Jenkins | `http://<PUBLIC_IP>:8080` | set on first login |
| SonarQube | `http://<PUBLIC_IP>:9000` | admin / admin |
| Nexus | `http://<PUBLIC_IP>:8081` | admin / see `docker exec sentinelops-nexus cat /nexus-data/admin.password` |

To tear everything down (stops billing for the EC2 instance):

```bash
./infra/scripts/teardown.sh
```

> **Cost note:** The EC2 instance is billed per hour while running. When you're done working, either run `teardown.sh` or stop the instance from the AWS Console to avoid burning credits. The EBS volume persists when stopped (pennies per GB-month) so your data is safe.

> **Security note:** The security group is locked to your public IP only. If your IP changes (e.g., router restart), you may need to re-run `terraform apply` to update the ingress rules.

## Project status

- [x] Stage 0 — Repo scaffold, AWS EC2 + k3s (Terraform), Jenkins/SonarQube/Nexus (Compose via cloud-init)
- [x] Stage 1 — Spring Boot payload app (built, containerized, pushed to Nexus)
- [ ] Stage 2 — CI pipeline + risk scoring engine
- [ ] Stage 3 — GitOps deploy (ArgoCD) + observability (Datadog)
  - [x] Datadog infra monitoring (Jenkins container health) + Slack alerting — see `monitoring/datadog/`
  - [ ] ArgoCD GitOps deploy
  - [ ] Datadog risk-score-vs-error-rate dashboard
- [ ] Stage 4 — Failure diagnosis + automatic rollback
- [ ] Stage 5 — Polish, architecture diagram, demo recording

## Why this project

Built specifically to demonstrate Jenkins, SonarQube Quality Gates, Nexus, OWASP/Trivy scanning, Kubernetes, and ArgoCD — and to go one step further than typical fresher CI/CD clones via a genuinely custom weighted risk-scoring engine and a closed feedback loop between pre-deploy scoring and post-deploy failure diagnosis.
