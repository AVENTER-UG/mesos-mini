TAG=`git describe`
BRANCH=`git symbolic-ref --short HEAD`
LASTCOMMIT=$(shell git log -1 --pretty=short | tail -n 1 | tr -d " " | tr -d "UPDATE:")


ifeq (${BRANCH}, master) 
        BRANCH=latest
endif

ifneq ($(shell echo $(LASTCOMMIT) | grep -E '^v([0-9]+\.){0,2}(\*|[0-9]+)'),)
        BRANCH=${LASTCOMMIT}
else
        BRANCH=latest
endif


build:
	docker build -t avhost/mesos-mini:latest -f Dockerfile .

push:
	@echo ">>>> Publish docker image: " ${BRANCH}
	@docker buildx create --use --name buildkitd
	@docker buildx build --push  --platform linux/arm64,linux/amd64  -t avhost/mesos-mini:${BRANCH} -f Dockerfile .
	@docker buildx build --push  --platform linux/arm64,linux/amd64  -t avhost/mesos-mini:latest -f Dockerfile .
	@docker buildx rm buildkitd

seccheck:
	grype --add-cpes-if-none .

imagecheck:
	trivy image	avhost/mesos-mini:latest

all: seccheck build imagecheck
