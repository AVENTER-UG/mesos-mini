TAG=v1.11.0-0.8.0
BRANCH=${TAG}
LASTCOMMIT=$(shell git log -1 --pretty=short | tail -n 1 | tr -d " " | tr -d "UPDATE:")


build:
	docker buildx build --progress=plain --load -t avhost/mesos-mini:latest --no-cache -f Dockerfile .

push:
	@echo ">>>> Publish docker image: " ${BRANCH}
	-docker buildx create --use --name buildkit
	@docker buildx build --sbom=true --provenance=true --push  --platform linux/amd64,linux/arm64  -t avhost/mesos-mini:${BRANCH} -f Dockerfile .
	@docker buildx build --sbom=true --provenance=true --push  --platform linux/amd64,linux/arm64  -t avhost/mesos-mini:latest -f Dockerfile .
	-docker buildx rm buildkit

seccheck:
	grype --add-cpes-if-none .

imagecheck:
	grype --add-cpes-if-none avhost/mesos-mini:latest > cve-report.md

all: build seccheck build imagecheck
