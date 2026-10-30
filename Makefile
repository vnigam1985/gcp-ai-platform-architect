# Google Cloud AI Platform Architect: 8-week build-along course. `make help` lists everything.
# Set your lab project once:  gcloud config set project <your-lab-project>

SHELL    := /bin/bash
PROJECT  ?= $(shell gcloud config get-value project 2>/dev/null)
REGION   ?= northamerica-northeast1
PREFIX   ?= aiplat
EMAIL    ?=
TF       := terraform
TFVARS   := -var project_id=$(PROJECT) -var region=$(REGION) -var prefix=$(PREFIX)
APPLY     = cd infra/$(1) && $(TF) init -input=false -upgrade >/dev/null && $(TF) apply -input=false -auto-approve $(TFVARS) $(2)

.DEFAULT_GOAL := help
help: ## Show all commands
	@grep -E '^[a-zA-Z0-9_-]+:.*?## ' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-20s\033[0m %s\n", $$1, $$2}'

# ----------------------------------------------------- week 0: local, $0 -----
local-up: ## Week 0: start app + LiteLLM gateway + Ollama locally (free)
	docker compose up -d --build
	docker compose exec ollama ollama pull qwen2.5:3b

local-keys: ## Week 0: create the bank app's team key on the local gateway
	./local/team-key.sh

local-test: ## Week 0: prove keys, model access and rate limits on the local gateway
	./local/smoke.sh

local-down: ## Week 0: stop the local lab
	docker compose down

check: ## Week 0: show which project and account you're about to spend money in
	@echo "Project: $(PROJECT)   Region: $(REGION)   Account: $$(gcloud config get-value account 2>/dev/null)"
	@gcloud billing projects describe $(PROJECT) --format="value(billingAccountName, billingEnabled)"

week0: ## Week 0: budget alert on the lab project (needs BILLING=<billing account id>)
	@test -n "$(BILLING)" || (echo "Set BILLING=XXXXXX-XXXXXX-XXXXXX (gcloud billing accounts list)" && exit 1)
	$(call APPLY,week00-budget,-var billing_account=$(BILLING))

# ---------------------------------------------------------- weeks 1 to 7 -----
week1: ## Week 1: private VPC, Private Google Access, private googleapis.com DNS, IAP SSH
	$(call APPLY,week01-landing-zone)

week2: ## Week 2: test VM (no external IP), model service account, audit logs
	$(call APPLY,week02-private-model)

week2-test: ## Week 2: prove the private path to Gemini from the VM
	./scripts/week2-test.sh

week3: ## Week 3: Model Armor template (plus org policies if ORG=true)
	$(call APPLY,week03-guardrails,$(if $(ORG),-var enable_org_policies=true,))

week3-test: ## Week 3: send attacks to the Model Armor template
	./scripts/week3-test.sh

week4: ## Week 4: AI gateway (LiteLLM on Cloud Run, Cloud SQL private IP). About 15 minutes
	$(call APPLY,week04-ai-gateway,-var deploy_gateway=false)
	./scripts/build-image.sh gateway
	$(call APPLY,week04-ai-gateway,-var deploy_gateway=true)

week4-test: ## Week 4: keys, model access, limits, from inside the VPC
	./scripts/week4-test.sh

week5: ## Week 5: build the app, create its team key, run it on internal Cloud Run
	./scripts/build-image.sh app
	$(call APPLY,week05-private-app,-var deploy_app=false)
	./scripts/week5-key.sh
	$(call APPLY,week05-private-app,-var deploy_app=true)

week5-test: ## Week 5: ask the private bank app questions from inside the VPC
	./scripts/week5-test.sh

week6: ## Week 6: gateway abuse and control-tampering alerts (needs EMAIL)
	@test -n "$(EMAIL)" || (echo "Set EMAIL=you@example.com" && exit 1)
	$(call APPLY,week06-security,-var email=$(EMAIL))

week7: ## Week 7: token dashboard and daily token alert
	$(call APPLY,week07-observability)

# --------------------------------------------------------------- week 8 ------
week8: ## Week 8: GitHub federation + release gate job (needs REPO=owner/name)
	@test -n "$(REPO)" || (echo "Set REPO=yourname/gcp-ai-platform-architect" && exit 1)
	$(call APPLY,week08-cicd,-var github_repo=$(REPO) -var deploy_gate=false)
	./scripts/build-image.sh gate
	$(call APPLY,week08-cicd,-var github_repo=$(REPO) -var deploy_gate=true)

week8-inventory: ## Week 8: compare the model in use with the model inventory
	./scripts/gcp-models-in-use.sh > /tmp/models-in-use.json
	python3 scripts/check_model_inventory.py --deployed /tmp/models-in-use.json

week8-gate: ## Week 8: run the release gate job inside the VPC
	./scripts/release-gate.sh

# ------------------------------------------------------------ cost control ---
validate: ## Format-check and validate every week (no Google Cloud account needed)
	@for d in infra/week0*; do (cd $$d && $(TF) init -backend=false -input=false >/dev/null && $(TF) validate -no-color | head -1 && $(TF) fmt -check) || exit 1; done

pause: ## Stop the VM and the Cloud SQL instance (Cloud Run already scales to zero)
	-gcloud compute instances stop $(PREFIX)-jumpbox --zone $(REGION)-a --quiet
	-gcloud sql instances patch $(PREFIX)-gateway-keys --activation-policy=NEVER --quiet

resume: ## Start the Cloud SQL instance again after make pause
	gcloud sql instances patch $(PREFIX)-gateway-keys --activation-policy=ALWAYS --quiet

destroy: ## DELETE everything, newest week first (asks you to confirm)
	./scripts/destroy.sh $(PROJECT) $(REGION) $(PREFIX)
