.PHONY: help

help:
	@perl -nle'print $& if m{^[a-zA-Z_-]+:.*?## .*$$}' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-30s\033[0m %s\n", $$1, $$2}'

release: ## Builds and generates escript for release
	@rm -f priv/bin/conform
	@MIX_ENV=prod EMBED_ELIXIR=false mix do compile, escript.build --force
