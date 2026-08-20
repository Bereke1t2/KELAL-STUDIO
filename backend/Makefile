# Kelal Studio backend — developer tasks.
# Run `make help` for the list.

BINARY_API    := bin/api
BINARY_WORKER := bin/worker
PKG           := ./...

.DEFAULT_GOAL := help

.PHONY: help
help: ## Show this help
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | \
		awk 'BEGIN{FS=":.*?## "}{printf "  \033[36m%-14s\033[0m %s\n", $$1, $$2}'

.PHONY: tidy
tidy: ## Resolve deps + write go.sum (run this first, after clone)
	go mod tidy

.PHONY: build
build: ## Compile api + worker into bin/
	go build -o $(BINARY_API) ./cmd/api
	go build -o $(BINARY_WORKER) ./cmd/worker

.PHONY: run
run: ## Run the API server
	go run ./cmd/api

.PHONY: worker
worker: ## Run the async video worker
	go run ./cmd/worker

.PHONY: migrate
migrate: ## Apply DB migrations, then exit
	go run ./cmd/api -migrate-only

.PHONY: test
test: ## Run tests with the race detector + coverage
	go test -race -coverprofile=coverage.out $(PKG)

.PHONY: cover
cover: test ## Open the HTML coverage report
	go tool cover -html=coverage.out

.PHONY: vet
vet: ## Run go vet
	go vet $(PKG)

.PHONY: fmt
fmt: ## Format all Go code in place
	gofmt -w .

.PHONY: fmt-check
fmt-check: ## Fail if any file isn't gofmt-clean
	@test -z "$$(gofmt -l .)" || (echo "gofmt needed on:"; gofmt -l .; exit 1)

.PHONY: lint
lint: ## Run golangci-lint (v2+; see .golangci.yml)
	golangci-lint run

.PHONY: check
check: fmt-check vet test ## The full local gate (mirrors CI)

.PHONY: db-up
db-up: ## Start local Postgres in the background
	docker compose up -d db

.PHONY: db-down
db-down: ## Stop + remove the local Postgres container
	docker compose down

.PHONY: clean
clean: ## Remove build + coverage artifacts
	rm -rf bin coverage.out coverage.html
