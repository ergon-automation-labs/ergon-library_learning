SCRIPTS_DIRECTORY ?= $(abspath $(CURDIR)/../scripts)
MIX ?= /Users/abby/.local/share/mise/shims/mix

.PHONY: test-handlers test-stores test-nats test-integration test-full setup help deps test credo dialyzer coverage check format clean release publish-release setup-hooks setup-db reset-db logs push-and-publish bump-version

help:
	@echo "BotArmyLearning - Learning Bot"
	@echo ""
	@echo "Setup commands:"
	@echo "  make setup           - Set up project (deps.get + install git hooks + setup database)"
	@echo "  make setup-hooks     - Install git hooks for pre-push validation"
	@echo "  make setup-db        - Create and migrate test database (required for testing)"
	@echo "  make reset-db        - Drop and recreate test database (useful for troubleshooting)"
	@echo ""
	@echo "Development commands:"
	@echo "  make test            - Run all tests"
	@echo "  make credo           - Run linter"
	@echo "  make dialyzer        - Run static analysis"
	@echo "  make coverage        - Run tests with coverage"
	@echo "  make check           - Run all checks (test, credo, dialyzer)"
	@echo "  make format          - Format Elixir code"
	@echo "  make clean           - Clean build artifacts"
	@echo ""
	@echo "Operations (deployed server logs):"
	@echo "  make logs            - Tail learning_bot log with grc (brew install grc; make -C .. install-grc)"
	@echo ""
	@echo "Release commands:"
	@echo "  make bump-version BUMP=patch|minor|major"
	@echo "                       - Bump version in mix.exs (never edit it by hand)"
	@echo "  make release         - Build OTP release locally"
	@echo "  make test-release-smoke - Boot the release, verify no boot errors"
	@echo "  make publish-release - Build, package, and publish to GitHub"
	@echo "  make sync-release-version - Repair a stale .release-published marker"
	@echo ""
	@echo "Deployment commands:"
	@echo "  make deploy          - Deploy to air via the monorepo"
	@echo "  make verify-health   - Probe bot_army.learning.health over NATS"
	@echo "  make verify-bot-nats - Monorepo NATS verification"
	@echo ""
	@echo "Normal workflow:"
	@echo "  make push            - test + compile + credo, then push"
	@echo "  make bump-version BUMP=patch && make push && make publish-release && make deploy"
	@echo ""

setup: init deps setup-hooks setup-db
	@echo "✓ Setup complete!"
	@echo ""
	@echo "Next steps:"
	@echo "  1. Configure .env with your database settings (if needed)"
	@echo "  2. Run: make test"
	@echo "  3. Start developing!"
	@echo ""

setup-hooks:
	@git config core.hooksPath git-hooks
	@echo "✓ Git hooks installed (core.hooksPath = git-hooks)"

setup-db:
	@echo "Setting up test database..."
	@MIX_ENV=test $(MIX) ecto.create || true
	@MIX_ENV=test $(MIX) ecto.migrate
	@echo "✓ Test database created and migrations applied"

reset-db:
	@echo "⚠️  Resetting test database (dropping and recreating)..."
	@MIX_ENV=test $(MIX) ecto.drop || true
	@MIX_ENV=test $(MIX) ecto.create
	@MIX_ENV=test $(MIX) ecto.migrate
	@echo "✓ Test database reset complete"

init:
	@if [ ! -d .git ]; then git init; echo "Git initialized."; else echo "Git already initialized."; fi

deps:
	$(MIX) deps.get

_compile-impl:
	@LOG_FILE="/tmp/compile-learning-$$(date +%s).log"; \
	echo "Compiling learning and logging to $$LOG_FILE..."; \
	$(MIX) compile 2>&1 | tee "$$LOG_FILE"; \
	echo "✓ Compilation log: $$LOG_FILE"

test:
	$(MIX) test

test-handlers:
	MIX_ENV=test $(MIX) test --only handlers --trace

test-stores:
	MIX_ENV=test $(MIX) test --only stores --trace

test-nats:
	MIX_ENV=test $(MIX) test --only nats --trace

test-integration:
	$(MIX) test --include integration --trace

test-full:
	$(MIX) test --include integration --include nats_live --trace

credo:
	$(MIX) credo --only warning

dialyzer: deps
	$(MIX) dialyzer

coverage:
	$(MIX) coveralls

check: test credo
	@echo "All checks passed!"

format:
	$(MIX) format

clean:
	$(MIX) clean
	rm -rf _build cover

release: check
	@echo "==============================================="
	@echo "Building OTP release"
	@echo "==============================================="
	rm -rf _build/prod/rel/library_learning_bot
	MIX_ENV=prod $(MIX) release
	@echo ""
	@echo "✓ Release built successfully"
	@echo "Location: _build/prod/rel/library_learning_bot/"
	@echo ""

publish-release: release
	@set -e; \
	VERSION=$$(sed -n 's/^[[:space:]]*version:[[:space:]]*"\([^"]*\)".*/\1/p' mix.exs | head -n 1); \
	if [ -z "$$VERSION" ]; then \
		echo "Failed to resolve version from mix.exs"; \
		exit 1; \
	fi; \
	TARBALL=library_learning_bot-$$VERSION.tar.gz; \
	echo "Version: $$VERSION"; \
	echo "Creating release tarball..."; \
	tar -czf "$$TARBALL" -C _build/prod/rel library_learning_bot/; \
	echo "✓ Tarball created: $$TARBALL"; \
	echo ""; \
	echo "Creating GitHub release v$$VERSION..."; \
	if gh release view "v$$VERSION" >/dev/null 2>&1; then \
		gh release upload "v$$VERSION" "$$TARBALL" --clobber; \
	else \
		gh release create "v$$VERSION" "$$TARBALL" \
			--title "Release v$$VERSION" \
			--notes "Learning Bot Elixir release v$$VERSION. Download and deploy with Jenkins." \
			--draft=false; \
	fi; \
	echo "$$VERSION $$(date +%s)" > .release-published; \
	echo "✓ Release published to GitHub"; \
	echo ""
push-and-publish:
	@git push && $(MAKE) publish-release

logs:
	@$(SCRIPTS_DIRECTORY)/tail_bot_log.sh

bump-version:
	@if [ -z "$(BUMP)" ]; then echo "Usage: make bump-version BUMP=major|minor|patch"; exit 1; fi
	@OLD=$$(grep 'version:' mix.exs | head -1 | sed -E 's/.*version: "([^"]+)".*/\1/'); \
	bash $(SCRIPTS_DIRECTORY)/bump_version.sh mix.exs $(BUMP) > /dev/null; \
	NEW=$$(grep 'version:' mix.exs | head -1 | sed -E 's/.*version: "([^"]+)".*/\1/'); \
	echo "✓ Bumped: $$OLD → $$NEW"

push: test compile credo
	@echo "✅ All validations passed"
	@echo "$$(date +%s)" > .push-validated
	@echo "✓ Proof-of-validation created"
	@$(MAKE) git-push


git-push:
	@git push origin main 2>&1 | tail -3


# ---------------------------------------------------------------------------
# Release / deployment (delegates to the monorepo where appropriate)
# ---------------------------------------------------------------------------
.PHONY: test-release-smoke sync-release-version deploy deploy-bot verify-bot verify-bot-nats verify-health

test-release-smoke:
	@echo "Running release smoke test for library_learning_bot"
	@RELEASE_NAME=library_learning_bot NATS_SERVERS=nats://localhost:4224 \
		bash $(SCRIPTS_DIRECTORY)/test_release_smoke.sh

# Rewrites .release-published, which the monorepo deploy-bot gate reads.
# publish-release does this automatically; use this to repair a stale marker.
sync-release-version:
	@VERSION=$$(sed -n 's/^[[:space:]]*version:[[:space:]]*"\([^"]*\)".*/\1/p' mix.exs | head -n 1); \
	if [ -z "$$VERSION" ]; then \
		echo "❌ Failed to resolve version from mix.exs"; exit 1; \
	fi; \
	echo "$$VERSION $$(date +%s)" > .release-published; \
	echo "✓ Synced release marker: v$$VERSION"

_FIND_MONOREPO_ROOT = \
	if [ -n "$(MONOREPO_ROOT)" ]; then \
		echo "$(MONOREPO_ROOT)"; \
		exit 0; \
	fi; \
	CURRENT_DIR=$$(pwd); \
	while [ "$$CURRENT_DIR" != "/" ]; do \
		if [ -f "$$CURRENT_DIR/Makefile" ] && grep -q "verify-bot-nats:" "$$CURRENT_DIR/Makefile"; then \
			if [ -d "$$CURRENT_DIR/bots" ] || [ -d "$$CURRENT_DIR/bot_army_infra" ]; then \
				echo "$$CURRENT_DIR"; \
				exit 0; \
			fi; \
		fi; \
		CURRENT_DIR=$$(dirname "$$CURRENT_DIR"); \
	done; \
	if [ -d "../../elixir_bots" ] && [ -f "../../elixir_bots/Makefile" ]; then \
		echo "$$(cd ../../elixir_bots && pwd)"; \
		exit 0; \
	fi; \
	echo ""; \
	exit 1

deploy: deploy-bot

deploy-bot:
	@MONOREPO_ROOT=$$($(call _FIND_MONOREPO_ROOT)) || { \
		echo "❌ Could not find monorepo root"; exit 1; \
	}; \
	$(MAKE) -C "$$MONOREPO_ROOT" deploy-bot BOT=library_learning TARGET=air

verify-bot:
	@MONOREPO_ROOT=$$($(call _FIND_MONOREPO_ROOT)) || { \
		echo "❌ Could not find monorepo root"; exit 1; \
	}; \
	$(MAKE) -C "$$MONOREPO_ROOT" verify-bot BOT=library_learning

verify-bot-nats:
	@MONOREPO_ROOT=$$($(call _FIND_MONOREPO_ROOT)) || { \
		echo "❌ Could not find monorepo root"; exit 1; \
	}; \
	$(MAKE) -C "$$MONOREPO_ROOT" verify-bot-nats BOT=library_learning

# The monorepo's verify-bot-nats derives bot_army.library_learning.health from
# the directory name, which is not the subject this bot serves. Probe directly.
verify-health:
	@PORT=$${NATS_PORT:-4222}; \
	echo "Probing bot_army.learning.health on port $$PORT..."; \
	OUT=$$(nats request --server nats://localhost:$$PORT bot_army.learning.health '{}' --timeout 10s --raw 2>/dev/null); \
	case "$$OUT" in \
		*'"status"'*) ;; \
		*) \
			echo "❌ No health payload — bot not running, or responder not subscribed"; \
			echo "   Got: $${OUT:-<empty>}"; \
			echo "   Check: tail -50 /var/log/bot_army/learning_bot.log"; \
			exit 1; ;; \
	esac; \
	echo "$$OUT"; \
	echo "✓ Health responder answered"

# Shared targets (push, credo, pre-push-cleanup, bump-version, git-push).
# Defined once in bot_army_infra so they cannot drift per repo.
BOT_ARMY_COMMON_MK := $(abspath $(CURDIR)/../bot_army_infra/make/common.mk)
ifeq ($(wildcard $(BOT_ARMY_COMMON_MK)),)
$(warning bot_army_infra not found at $(BOT_ARMY_COMMON_MK) - shared targets unavailable)
else
include $(BOT_ARMY_COMMON_MK)
endif
