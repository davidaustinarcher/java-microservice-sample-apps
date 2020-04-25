FROM ubuntu as base

RUN apt-get update -y && apt install -y curl jq

ARG URL
ARG API_KEY
ARG ORG_ID
ARG SERVICE_KEY
ARG AUTH_HDR

WORKDIR /app

COPY grab-latest-*.sh ./
#COPY contrast_security-user.yaml .

RUN mkdir -p /app/agents/java
RUN sh ./grab-latest-from-maven.sh /app/agents/java/contrast.jar
RUN mkdir -p /app/agents/python
RUN sh ./grab-latest-from-teamserver.sh python /app/agents/python/contrast-python-agent.tar.gz
RUN mkdir -p /app/agents/node
RUN sh ./grab-latest-from-teamserver.sh node /app/agents/node/node-contrast.tgz

FROM ubuntu

WORKDIR /app
COPY --from=base /app/agents /app/agents
CMD cp -rp /app/agents/* /agents
