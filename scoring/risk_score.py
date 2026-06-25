#!/usr/bin/env python3
"""
SentinelOps Risk Scoring Engine
==============================
Aggregates outputs from three security scanners into a single 0-100 risk score.

Scanners:
  1. SonarQube (static code analysis)   — weight 40%
  2. OWASP Dependency-Check (SCA)        — weight 30%
  3. Trivy (container image CVE scan)    — weight 30%

Each scanner's raw findings are normalized to a 0-100 sub-score,
then weighted and summed into the final score.

Usage:
    python risk_score.py

Inputs (read from parent directory or current working directory):
    reports/sonar-issues.json
    reports/dependency-check-report.json
    reports/trivy-report.json

Output:
    risk_score_result.json   (score, decision, details)
    risk_score_result.md     (human-readable report)
"""

import json
import os
import sys
from pathlib import Path

# ---------------------------------------------------------------------------
# Configuration
# ---------------------------------------------------------------------------
WEIGHTS = {
    "sonar": 0.40,
    "owasp": 0.30,
    "trivy": 0.30,
}

THRESHOLD = 70   # score > 70 → high risk → manual approval gate

SEVERITY_MAP = {
    "BLOCKER": 10,
    "CRITICAL": 8,
    "MAJOR": 5,
    "MINOR": 2,
    "INFO": 0.5,
    "HIGH": 8,
    "MEDIUM": 4,
    "LOW": 1,
    "UNKNOWN": 0.5,
}


def load_json(path: str) -> dict:
    """Load a JSON file, returning {} if missing or malformed."""
    if not Path(path).exists():
        print(f"[WARN] {path} not found, returning empty data")
        return {}
    try:
        with open(path, "r", encoding="utf-8") as f:
            return json.load(f)
    except json.JSONDecodeError as exc:
        print(f"[WARN] {path} JSON error: {exc}, returning empty data")
        return {}


# ---------------------------------------------------------------------------
# SonarQube scoring
# ---------------------------------------------------------------------------
def score_sonar(data: dict) -> dict:
    """
    SonarQube issue counts → normalized 0-100 score.
    Lower is better (0 = perfect code, 100 = terrible).
    """
    issues = data.get("issues", [])
    if not issues:
        return {"score": 0.0, "details": "No issues found — perfect score"}

    severity_counts = {}
    raw_penalty = 0.0

    for issue in issues:
        sev = issue.get("severity", "INFO")
        severity_counts[sev] = severity_counts.get(sev, 0) + 1
        raw_penalty += SEVERITY_MAP.get(sev, 0.5)

    # Normalize: 0 penalty → 0 score (good), high penalty → 100 (bad)
    # Cap at 100
    score = min(100.0, raw_penalty * 2.5)

    return {
        "score": round(score, 2),
        "details": f"{len(issues)} issues ({severity_counts})",
    }


# ---------------------------------------------------------------------------
# OWASP Dependency-Check scoring
# ---------------------------------------------------------------------------
def score_owasp(data: dict) -> dict:
    """
    OWASP report → normalized 0-100 score.
    Focuses on CVSS scores and severity of dependency CVEs.
    """
    dependencies = data.get("dependencies", [])
    if not dependencies:
        return {"score": 0.0, "details": "No dependencies scanned"}

    vuln_count = 0
    raw_penalty = 0.0
    severity_breakdown = {}

    for dep in dependencies:
        vulns = dep.get("vulnerabilities", [])
        for vuln in vulns:
            vuln_count += 1
            cvss = vuln.get("cvssv3", {}).get("baseScore", 0)
            if cvss == 0:
                cvss = vuln.get("cvssv2", {}).get("score", 0) / 10 * 10  # rough normalize
            sev = vuln.get("severity", "UNKNOWN")
            severity_breakdown[sev] = severity_breakdown.get(sev, 0) + 1
            raw_penalty += cvss if cvss > 0 else SEVERITY_MAP.get(sev, 0.5)

    if vuln_count == 0:
        return {"score": 0.0, "details": "No vulnerabilities found"}

    # Normalize: cap at 100
    score = min(100.0, raw_penalty * 1.5)

    return {
        "score": round(score, 2),
        "details": f"{vuln_count} CVEs ({severity_breakdown})",
    }


# ---------------------------------------------------------------------------
# Trivy scoring
# ---------------------------------------------------------------------------
def score_trivy(data: dict) -> dict:
    """
    Trivy JSON report → normalized 0-100 score.
    """
    results = data.get("Results", [])
    if not results:
        return {"score": 0.0, "details": "No scan results"}

    vuln_count = 0
    raw_penalty = 0.0
    severity_breakdown = {}

    for result in results:
        vulns = result.get("Vulnerabilities", [])
        for vuln in vulns:
            vuln_count += 1
            sev = vuln.get("Severity", "UNKNOWN")
            severity_breakdown[sev] = severity_breakdown.get(sev, 0) + 1
            cvss_score = 0
            for cvss_entry in vuln.get("CVSS", {}).values():
                cvss_score = max(cvss_score, cvss_entry.get("V3Score", 0) or cvss_entry.get("V2Score", 0))
            raw_penalty += cvss_score if cvss_score > 0 else SEVERITY_MAP.get(sev, 0.5)

    if vuln_count == 0:
        return {"score": 0.0, "details": "No vulnerabilities found"}

    score = min(100.0, raw_penalty * 1.5)

    return {
        "score": round(score, 2),
        "details": f"{vuln_count} CVEs ({severity_breakdown})",
    }


# ---------------------------------------------------------------------------
# Aggregate
# ---------------------------------------------------------------------------
def aggregate(sub_scores: dict) -> dict:
    """Weighted average of sub-scores."""
    final = 0.0
    for key, weight in WEIGHTS.items():
        final += sub_scores[key]["score"] * weight
    final = round(final, 2)

    decision = "APPROVE" if final <= THRESHOLD else "MANUAL_APPROVAL"

    return {
        "score": final,
        "threshold": THRESHOLD,
        "decision": decision,
        "weights": WEIGHTS,
        "sub_scores": sub_scores,
    }


def write_report(result: dict, out_json: str, out_md: str):
    """Write JSON result and Markdown human-readable report."""
    with open(out_json, "w", encoding="utf-8") as f:
        json.dump(result, f, indent=2)
    print(f"[INFO] Written {out_json}")

    lines = [
        "# SentinelOps Risk Score Report",
        "",
        f"**Final Score:** {result['score']} / 100",
        f"**Threshold:** {result['threshold']}",
        f"**Decision:** {result['decision']}",
        "",
        "## Breakdown",
        "",
        "| Scanner | Weight | Raw Score | Details |",
        "|---------|--------|-----------|---------|",
    ]
    for key, weight in WEIGHTS.items():
        sub = result["sub_scores"][key]
        lines.append(f"| {key.upper()} | {weight*100:.0f}% | {sub['score']} | {sub['details']} |")
    lines.append("")
    lines.append("---")
    lines.append("*Generated by SentinelOps risk_score.py*")

    with open(out_md, "w", encoding="utf-8") as f:
        f.write("\n".join(lines))
    print(f"[INFO] Written {out_md}")


# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------
def main():
    # Resolve paths relative to repo root or current directory
    reports_dir = Path("reports")
    if not reports_dir.exists():
        reports_dir = Path("../reports")

    sonar_data = load_json(str(reports_dir / "sonar-issues.json"))
    owasp_data = load_json(str(reports_dir / "dependency-check-report.json"))
    trivy_data = load_json(str(reports_dir / "trivy-report.json"))

    sub_scores = {
        "sonar": score_sonar(sonar_data),
        "owasp": score_owasp(owasp_data),
        "trivy": score_trivy(trivy_data),
    }

    result = aggregate(sub_scores)

    scoring_dir = Path("scoring")
    if not scoring_dir.exists():
        scoring_dir = Path(".")

    write_report(result, str(scoring_dir / "risk_score_result.json"), str(scoring_dir / "risk_score_result.md"))

    print(f"\n{'='*60}")
    print(f"RISK SCORE: {result['score']} / 100")
    print(f"DECISION:   {result['decision']}")
    print(f"{'='*60}")

    if result["decision"] == "MANUAL_APPROVAL":
        print("\n[ALERT] Score exceeds threshold — manual approval required before deploy.")
        sys.exit(0)   # exit 0 so Jenkins doesn't mark as FAILURE, just stops for input
    else:
        print("\n[OK] Score within threshold — auto-promoting.")
        sys.exit(0)


if __name__ == "__main__":
    main()
