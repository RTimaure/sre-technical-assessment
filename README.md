# SRE Technical Assessment

Submission by **Rebeca Timaure** for the Site Reliability Engineer role.

This repository contains the design documents and Terraform alerting configuration for the assessment. Nothing has been built or deployed; all artifacts are design deliverables prepared for walkthrough and discussion.

---

## Executive Summary

- **Task 1 — Production Readiness (`fx-quote-service`):** **NO-GO** for Tier 1 promotion in its current state. The service lacks customer-impact monitoring, on-call coverage, runbooks, validated rollback, peak load testing, and single-point-of-failure mitigation (single-node Redis and single external rate provider). Promotion to **GO** is conditional on resolving launch-blocking gaps and providing validation evidence within the three-week window.
- **Task 2 — Recovery Exercise Plan (`payout-service`):** Prioritizes an isolated **PostgreSQL Point-in-Time Recovery (PITR)** test first. Because PostgreSQL holds customer data and critical payout state with zero prior restore tests, validating whether the 800 GB database can meet the **2-hour RTO** and **5-minute RPO** safely—with auditable evidence for compliance—takes priority before broader workload or end-to-end failover tests.

---

## Repository Structure

| File | Deliverable | Description |
|---|---|---|
| `production-readiness.pdf` | Task 1 (Document) | Tier 1 readiness standard (10 items), ranked gap analysis and conditional Go/No-Go call, two SLOs with error-budget actions, and a 20-service rollout approach (2 pages). |
| `alerts.tf` | Task 1 (Code) | Datadog Terraform configuration defining the `fx-quote-service` availability SLO (99.9% over 30d) plus fast-burn and slow-burn alerts. |
| `recovery-exercise-plan.pdf` | Task 2 (Document) | One-page recovery exercise plan for `payout-service` covering scenario selection, step-by-step RTO breakdown, safety guardrails, RTO/RPO measurement, and compliance evidence. |

*(Note: Rename the file paths in the table above if you organize them into folders before pushing to GitHub.)*

---

## How the Deliverables Were Built

1. **Baseline & Constraint Mapping:** Extracted hard numbers, dependencies, and organizational limits directly from the brief (e.g., 200 RPS peak, <300 ms latency target, 15-minute untested rollback, 5-engineer single-timezone team, 800 GB PostgreSQL with no second region, 2-hour RTO / 5-minute RPO).
2. **Risk-Driven Prioritization:**
   - For **Task 1**, separated launch blockers (undetected customer impact, missing on-call/runbooks, unverified dependency/AZ/rollback resilience) from 30-day post-launch improvements, anchoring targets to what the current architecture can realistically sustain.
   - For **Task 2**, selected PostgreSQL PITR in an isolated environment as the first test so database recoverability and compliance evidence are proven without risking production data or external bank payouts.
3. **Alerting & Verification Design:** Translated the availability SLO into multi-window burn-rate alerts in `alerts.tf` (14.4x over 1h/5m for paging; 6x over 6h/30m for tickets), validating the burn-rate math manually against a 30-day error budget (43.2 minutes).

---

## Key Assumptions & Known Limitations

- **Tier 1 baseline:** No internal Tier 1 definition was provided; the 10-item standard is an initial baseline designed to be adaptable by the organization.
- **Availability Zone placement:** AZ distribution for the six `fx-quote-service` instances was unspecified. Worst-case placement (single AZ) is assumed and marked as a mandatory pre-launch verification item.
- **PostgreSQL PITR & restore duration:** Managed PostgreSQL is assumed to support PITR within the 7-day log retention window. The 60-minute snapshot restore in Task 2 is a planning estimate (~222 MB/s for 800 GB) to be replaced by measured test telemetry.
- **Alerting telemetry scope (`alerts.tf`):** The Terraform SLI measures server-side non-5xx traced requests (`trace.http.request.*`). Tracking stale quotes and client-side timeouts—included in the written SLO definition—requires custom application metrics or load-balancer telemetry and is noted as a known limitation of the sample configuration.
- **Team capacity:** On-call and rollout recommendations assume the five-engineer, single-timezone owning team described in the brief.

---

## Use of AI Tools

I used **Claude (Anthropic)** as a drafting and review assistant across the deliverables. I authored the initial drafts, defined all technical positions, numeric targets, and risk decisions, and verified every calculation and configuration manually.

| Area | How AI Was Used | What I Decided & Verified Myself |
|---|---|---|
| **Task 1 — Readiness standard** | Reviewed initial draft, suggested grouping/reordering items, and helped sharpen verification criteria. | Final 10-item list, mandatory vs. recommended split, and verification standards. |
| **Task 1 — Gap analysis & Go/No-Go** | Challenged ranking logic, flagged assumptions not stated in the brief (such as AZ placement), and helped tighten exit conditions. | Gap severity ranking, pre-launch blockers vs. 30-day items, and risk-acceptance ownership. |
| **Task 1 — SLOs** | Checked target consistency and helped clarify valid-request boundary wording. | 99.9% availability and 99% <300 ms latency targets, plus counting stale quotes as failures. |
| **Task 1 — Alert file (`alerts.tf`)** | Reviewed initial Terraform and helped structure the multi-window SLO monitor resources and comments. | SLO target, burn-rate thresholds and windows (`14.4x` over 1h/5m, `6x` over 6h/30m) verified manually against a 30-day budget, and final code review. |
| **Task 2 — Recovery exercise plan** | Reviewed draft structure against the one-page limit, challenged step durations, and helped tighten compliance evidence and safety-boundary phrasing. | Selection of PostgreSQL PITR as the first test, RTO step breakdown and RPO payout-loss math (~52 payouts at 15,000/day), isolation/stop rules, and pre-exercise checklist. |