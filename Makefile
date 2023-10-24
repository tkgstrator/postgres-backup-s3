include .secrets

PHONY: build
build:
	docker buildx build --push --build-arg ALPINE_VERSION=3.18 --platform=linux/amd64,linux/arm64 -t ${DOCKERHUB_USERNAME}/postgres-backup-s3:latest .
