.PHONY: help bootstrap hooks scan \
	install-linux tolocal-linux fromlocal-linux \
	install-osx tolocal-osx fromlocal-osx \
	install-debian tolocal fromlocal

help: ## Show this help
	@grep -hE '^[a-z-]+:.*?## ' $(MAKEFILE_LIST) \
		| awk -F':.*?## ' '{ printf "  \033[36m%-18s\033[0m %s\n", $$1, $$2 }'

bootstrap: ## Full setup on a fresh machine (install + apply)
	./bootstrap.sh

hooks: ## Enable the gitleaks pre-commit hook (run once per clone)
	git config core.hooksPath .githooks
	@chmod +x .githooks/*
	@echo "Hooks enabled. Install gitleaks if you have not already."

scan: ## Scan the whole repository history for secrets
	gitleaks detect --redact --no-banner

## --- Linux ---

install-linux: ## Install packages and apt repositories (Linux)
	./linux/install.sh

tolocal-linux: ## Apply repository config to this machine (Linux)
	./linux/apply_to_local.sh

fromlocal-linux: ## Capture this machine's config into the repository (Linux)
	./linux/replicate_from_local.sh

## --- macOS ---

install-osx: ## Install packages (macOS)
	./osx/install.sh

tolocal-osx: ## Apply repository config to this machine (macOS)
	./osx/apply_to_local.sh

fromlocal-osx: ## Capture this machine's config into the repository (macOS)
	./osx/replicate_from_local.sh
