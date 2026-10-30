# What the course costs, and how to keep it low

Prices are approximate USD list prices checked in October 2026. Some Google Cloud prices on the public pages are shown for Iowa (us-central1) by default; Montreal can be a little higher. Your billing currency may be CAD. **Set the week 0 budget first**, and check the [Google Cloud pricing calculator](https://cloud.google.com/products/calculator).

## Per item, while it exists

| Item | Week | About | Notes |
| --- | --- | --- | --- |
| Local lab | 0 | $0 | Your laptop |
| Budgets and alerts | 0 | Free | |
| VPC, subnets, firewall rules | 1 | Free | |
| Flow logs | 1 | Cents | Volume sent to Cloud Logging |
| Test VM e2-small | 2 | About $0.017/hour in Iowa; check Montreal | Stops at 19:00 daily; `make pause` |
| Gemini 3.5 Flash tokens | 2+ | Cents for the whole course | |
| Data Access audit logs | 2+ | Cents | |
| Model Armor | 3+ | Free up to 2 million tokens a month, then $0.10 per million | |
| Cloud SQL `db-f1-micro` | 4 | About $0.0105/hour in Iowa plus storage; check Montreal | `make pause` stops it |
| Cloud Run (gateway, app, gate job) | 4, 5, 8 | Scales to zero; cents for the lab | |
| Cloud Build, Artifact Registry, Secret Manager | 4+ | Within free tiers or cents | |
| Log-based metrics, alerts, dashboard | 6, 7 | Within free allowances at this volume | |

Not used on purpose: **Apigee Intermediate** (about $1,460 a month, the cheapest environment that allows the AI policies), **Security Command Center Premium**, **Cloud NAT**, **Private Service Connect** endpoints ($0.01/hour each).

## Three ways to take the course

| Plan | What you do | Rough total |
| --- | --- | --- |
| **Sprint** (recommended) | All 8 weeks within 2 to 3 weeks, `make pause` between sessions, then delete the project | $10 to $25 |
| Weekend | Build, learn and destroy every weekend (rebuild takes about 30 minutes, mostly Cloud SQL) | $3 to $8 per weekend |
| Leave it running for a month | Everything up, never paused | About $25 to $40 |

These are estimates, not quotes. Check Billing > Reports after the first few days.

## Stop spending

```bash
make pause                               # stop the VM and Cloud SQL
make destroy                             # delete every week (type DESTROY)
gcloud projects delete <lab-project-id>  # the surest way: removes everything left
```

A budget alert tells you. Only deleting things stops the spending.
