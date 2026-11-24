# sre-technical-assessment
Submission by Rebeca Timaure for the Site Reliability Engineer role. Includes production readiness assessment and Disaster Recovery for critical fintech workloads.
Nothing in this repository is built or deployed. It contains design documents and one Terraform file that has not been applied.

## Use of AI tools
I used Claude (Anthropic) as a drafting and review assistant. I wrote the first versions of the readiness standard, the gap table, the SLOs and the roll-out approach, and used the tool to challenge and refine them. For the alert file, I wrote a first version and Claude drafted the revised Terraform, which I reviewed and adapted.

| Area | How I used AI | What I decided or verified myself |
|---|---|---|
| Readiness standard | Reviewed my draft, suggested merging and reordering items, and proposed verifiable evidence for each. | The final list of ten items, the mandatory/recommended split, and all numeric thresholds. |
| Gap analysis and go/no-go | Critiqued my ranking, pointed out claims not supported by the brief (for example AZ placement), and helped phrase the exit conditions. | The ranking criteria, what blocks launch versus what can wait 30 days, and who accepts each risk. |
| SLOs | Flagged an inconsistency between my targets and helped define what counts as a valid request. | The targets (99.9% availability, 99% latency under 300 ms) and the decision to count stale quotes as failures. |
| Alert file | Reviewed my Terraform and drafted the revised file: SLO as code, separate paging and ticket channels, alert messages with runbook links, header comments. | The SLO target, the burn-rate thresholds and windows (14.4× over 1 h, 6× over 6 h), checked by hand against a 30-day budget, and the final review of the file. |

## Repository contents

| Path   | Description |
|---|---|
| **task1-production-readiness.pdf** | Task 1: Tier 1 readiness standard, ranked gaps for `fx-quote-service`, go/no-go recommendation, SLOs and roll-out approach (2 pages) |
| **task1-alerts/alert**s.tf | Task 1: availability SLO and burn-rate alerts as code (Terraform, Datadog provider) |
| **task2-recovery-exercise-plan.pdf** | Task 2: first recovery exercise plan for `payout-service` (1 page). |

## Summary

**Task 1.** `fx-quote-service` is **NO-GO today** for Tier 1. It cannot detect a customer-impacting failure, nobody is on call, and its rollback, capacity and dependency failure behaviour have never been tested. The recommendation becomes **GO if the gaps are fixed and is enough evidenced** within the three weeks.





