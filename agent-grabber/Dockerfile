FROM ubuntu as base

RUN apt-get update -y && apt install -y curl jq

# These build args tell us how to contact Team Server.  Ideally, we should
# find alternative sources for the agents which don't require Team Server
# credentials.  Then we wouldn't need these args at all.
ARG URL
ARG API_KEY
ARG ORG_ID
ARG AUTH_HDR

# During the build phase, pull down the latest agents
WORKDIR /app

COPY grab-latest-*.sh ./

# Get Java agent from Maven repo
RUN mkdir -p /app/agents/java
RUN sh ./grab-latest-from-maven.sh /app/agents/java/contrast.jar

# Get Python agent from Team Server
RUN mkdir -p /app/agents/python
RUN sh ./grab-latest-from-teamserver.sh python /app/agents/python/contrast-python-agent.tar.gz

# Get Node agent from Team Server
RUN mkdir -p /app/agents/node
RUN sh ./grab-latest-from-teamserver.sh node /app/agents/node/node-contrast.tgz


###########################################
# STAGE 2

# In second stage, just copy in the downlaoded agents
FROM ubuntu

WORKDIR /app
COPY --from=base /app/agents /app/agents


# When the container runs, it will copy the agents into /agents, which will
# normally be a volume shared with containers where apps to be instrumented
# with Contrast will run.
CMD cp -rp /app/agents/* /agents
