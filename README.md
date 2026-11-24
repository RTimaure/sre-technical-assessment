# SRE Technical Assessment
Submission by Rebeca Timaure for the Site Reliability Engineer role.

This repository contains a production readiness assessment, SLO-based monitoring configuration and disaster recovery planning for critical fintech workloads.
Nothing in this repository has been built or deployed. It contains design documents and a Terraform configuration file that has not been applied.

## Use of AI tools
I used Claude (Anthropic) as a drafting and review assistant. I wrote the first versions of the readiness standard, the gap table, the SLOs and the roll-out approach, and used the tool to challenge and refine them. For the alert file, I wrote a first version and Claude drafted the revised Terraform configuration, which I reviewed and adapted.

| Area | How I used AI | What I decided or verified myself |
|---|---|---|
| Readiness standard | Reviewed my draft, suggested merging and reordering items, and proposed verifiable evidence for each. | The final list of ten items, the mandatory/recommended split, and all numeric thresholds. |
| Gap analysis and go/no-go | Critiqued my ranking, pointed out claims not supported by the brief (for example, AZ placement), and helped phrase the exit conditions. | The ranking criteria, what blocks launch versus what can wait 30 days, and who accepts each risk. |
| SLOs | Flagged an inconsistency between my targets and helped define what counts as a valid request. | The targets (99.9% availability, 99% latency under 300 ms) and the decision to count stale quotes as failures. |
| Alert file | Reviewed my Terraform and drafted the revised file: SLO as code, separate paging and ticket channels, alert messages with runbook links, and header comments. | The SLO target, the burn-rate thresholds and windows (14.4× over 1 h, 6× over 6 h), checked by hand against a 30-day budget, and the final review of the file. |


## Repository contents

| Path | Description |
|---|---|
| **task1-production-readiness.pdf** | Task 1: Tier 1 readiness standard, ranked gaps for `fx-quote-service`, go/no-go recommendation, SLOs and roll-out approach (2 pages). |
| **task1-alerts/alerts.tf** | Task 1: availability SLO and burn-rate alert configuration as code, using the Datadog Terraform provider. |
| **task2-recovery-exercise-plan.pdf** | Task 2: recovery exercise plan for `payout-service`, prioritising PostgreSQL Point-in-Time Recovery (PITR) (1 page). |


## Key assumptions and limits
- No internal Tier 1 definition was supplied, so the readiness standard is a proposal the organisation can adjust.
- The availability-zone placement of the six fx-quote-service instances was not provided. I assume the worst case (a single zone) and require it to be verified before launch.
- Managed PostgreSQL is assumed to support point-in-time recovery. The 60-minute snapshot restore in the Task 2 timeline is a placeholder derived from the database size, to be replaced by a measured value.
- The Terraform file is a design artefact. Its availability SLI counts non-5xx server-side requests. Quote freshness and client-side timeouts, which the SLO definition in the document counts as failures, would need a custom metric or load balancer data to be measured; this is a known limitation of the file.
- No tooling or budget figures were given. Roll-out and on-call recommendations assume the five-engineer, single-time-zone owning team described in the brief.

## Summary

**Task 1 – Production readiness.** `fx-quote-service` is **NO-GO today** for Tier 1. It cannot detect a customer-impacting failure, there is no on-call coverage, and its rollback, capacity and dependency failure behaviour have not been tested. A **GO decision** is conditional on resolving the launch-blocking gaps and providing sufficient evidence of readiness within the three-week remediation period.

**Task 2 – Recovery exercise.** The first recovery exercise prioritises PostgreSQL Point-in-Time Recovery (PITR) for `payout-service`. The plan defines how to test database recoverability against the 2-hour RTO and 5-minute RPO, including recovery validation, execution safeguards and evidence collection. These targets remain unverified until the exercise is performed.






