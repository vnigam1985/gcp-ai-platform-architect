# What was tested, and what wasn't

Google Cloud AI changes every month. This file records what was checked before publishing, on **October 30, 2026**, so you know what to trust.

## Checked

| Check | Result |
| --- | --- |
| Every Terraform root in `infra/` | `terraform fmt -check` and `terraform validate` pass (Terraform 1.9.8, hashicorp/google 7.46) |
| Model and region | `gemini-3.5-flash` lists northamerica-northeast1 for availability and ML processing; Gemini 2.5 models were retired October 20, 2026 |
| Model Armor location | Not listed in Montreal; Toronto is listed without the malicious-URL filter |
| Apigee AI policies | Extensible policies, so Intermediate or Comprehensive environments only |
| Org policies and VPC Service Controls | Need an Organization |
| LiteLLM `model_armor` guardrail config with environment variables | **Run**: loads with the right template, project, location and modes |
| LiteLLM gateway image with Postgres | **Run with no network egress** (same image as the AWS course) |
| Week 4 test script logic | **Run** against a local LiteLLM gateway: 5/5 |
| Week 6 attack commands (quoting) | **Run** locally |
| Week 0 local lab | **Run end to end**: 6/6 checks |
| Model inventory checker | **Run** locally |

## Links

Every external link in the README and the week guides (88 across this repo and its sister repo) was opened on October 30, 2026. Moved pages were updated to their new addresses.

## Not verified yet (please report what you see)

No Google Cloud project was used to build this course, so **nothing has been deployed end to end**. In particular:

- On-demand calls to `gemini-3.5-flash` on the Montreal endpoint in a fresh project (the model page lists some PayGo options only for global, us and eu)
- Model Armor's regional Toronto endpoint called from the gateway with `PRIVATE_RANGES_ONLY` egress
- The exact log text the week 6 filters match (`401 Unauthorized`, `429 Too Many Requests`, and Model Armor blocks) in the LiteLLM image you pull
- The BETA token metrics and labels used in the week 7 dashboard
- The `course-release` workflow against a live project
