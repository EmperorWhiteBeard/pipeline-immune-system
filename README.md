# pipeline-immune-system

**SentinelOps** — a GitOps pipeline that scores release risk before deploy, and diagnoses its own failures after deploy.

> _Why this repo name?_ Three independent scanners (SonarQube, OWASP Dependency-Check, Trivy) act like antibodies, screening every build before it's allowed into the bloodstream of the cluster. When something still gets through and the app gets sick in production, the system doesn't just alert — it diagnoses *why* and heals itself via an automatic Git-based rollback. Hence: pipeline immune system.

[Architecture diagram and risk-score-vs-error-rate dashboard screenshot go here once Stage 3 is done]

---

## What it does

1. **Build & Risk Gate** — every push triggers Jenkins, which builds the app, pushes the artifact to Nexus, then runs SonarQube, OWASP Dependency-Check, and Trivy in parallel. A custom Python scoring engine (`scoring/risk_score.py`) aggregates all three into a single 0–100 weighted risk score. Low score → auto-promote. High score → a Slack approval card gates the deploy.
2. **GitOps Deploy & Live Watch** — ArgoCD continuously reconciles the cluster from Git. Prometheus scrapes the running app; Grafana overlays the risk score history against live error rate.
3. **Failure Diagnosis & Rollback** — if production error rate/latency crosses a threshold, a Flask listener pulls pod logs and the last build's scan reports, classifies the root cause (quality-gate fail / critical CVE / runtime fail), posts it to Slack, and calls the ArgoCD API to roll back to the last known-good commit.

The closed loop: the same risk score that gated the deploy is the first thing the failure classifier checks. A low-risk build that still fails in production is a signal the scoring weights need tuning — a real, discussable insight rather than just tool-wiring.

## Payload application

A deliberately simple Spring Boot REST API (task tracker) — `POST /tasks`, `GET /tasks`, `DELETE /tasks/{id}`, in-memory or H2-backed. It exists to give the pipeline something real to build, scan, and deploy. Exposes `/health` for Kubernetes probes and `/actuator/metrics` for Prometheus scraping.

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
| IaC | Terraform | Provisions the kind cluster (and cloud infra, optionally) |
| Config Management | Ansible | Node/config-level reconciliation |
| Containerization | Docker | Packages the app |
| Orchestration | Kubernetes (kind) | Runs the live app pods |
| CD / GitOps | ArgoCD | Syncs cluster state from Git, performs rollback |
| Observability | Prometheus & Grafana | Metrics, alert rules, risk-score-vs-error-rate dashboard |
| Alerts | Slack Webhooks | Approval cards, root-cause alerts |
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
│   │   ├── modules/kind-cluster/    # Reusable kind cluster module
│   │   └── environments/
│   │       ├── local/                # What you actually run day-to-day
│   │       └── cloud/                # Placeholder for an EKS/GKE demo recording
│   ├── ansible/               # Config management playbooks
│   ├── docker-compose.cicd.yml # Jenkins + SonarQube + Nexus
│   └── scripts/
│       ├── bootstrap.sh       # One-command Stage 0 setup
│       └── teardown.sh        # One-command Stage 0 teardown
├── k8s/
│   ├── base/                  # Kustomize base manifests
│   └── overlays/local/        # Local-cluster overlay
├── argocd/                    # ArgoCD Application manifests
├── monitoring/
│   ├── prometheus/            # Alert rules
│   └── grafana/dashboards/    # Dashboard JSON
├── slack/                     # Block Kit message templates
└── docs/                      # Architecture diagrams, screenshots
```

## Getting started (Stage 0)

Prerequisites: Docker, Terraform, `kubectl`, `kind`.

```bash
./infra/scripts/bootstrap.sh
```

This provisions a local `kind` cluster via Terraform and starts Jenkins, SonarQube, and Nexus via Docker Compose.

| Service | URL | Default credentials |
|---|---|---|
| Jenkins | http://localhost:8080 | set on first login |
| SonarQube | http://localhost:9000 | admin / admin |
| Nexus | http://localhost:8081 | admin / see `docker exec sentinelops-nexus cat /nexus-data/admin.password` |

To tear everything down:

```bash
./infra/scripts/teardown.sh        # keep volumes (fast restart later)
./infra/scripts/teardown.sh -v     # full wipe, including volumes
```

> **Note:** SonarQube's bundled Elasticsearch requires `vm.max_map_count >= 262144` on the Docker host. `bootstrap.sh` checks this and tells you the exact command to run if it's too low.

## Project status

- [x] Stage 0 — Repo scaffold, kind cluster (Terraform), Jenkins/SonarQube/Nexus (Compose)
- [ ] Stage 1 — Spring Boot payload app
- [ ] Stage 2 — CI pipeline + risk scoring engine
- [ ] Stage 3 — GitOps deploy (ArgoCD) + observability (Prometheus/Grafana)
- [ ] Stage 4 — Failure diagnosis + automatic rollback
- [ ] Stage 5 — Polish, architecture diagram, demo recording

## Why this project

Built specifically to demonstrate Jenkins, SonarQube Quality Gates, Nexus, OWASP/Trivy scanning, Kubernetes, and ArgoCD — and to go one step further than typical fresher CI/CD clones via a genuinely custom weighted risk-scoring engine and a closed feedback loop between pre-deploy scoring and post-deploy failure diagnosis.
