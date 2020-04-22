FROM ubuntu

RUN apt-get update -y && apt install -y curl jq

WORKDIR /app

COPY grab-latest-*.sh .

RUN mkdir -p /app/agents/java
RUN sh ./grab-latest-from-maven.sh /app/agents/java/contrast.jar
#RUN mkdir -p /app/agents/python
#RUN sh ./grab-latest-for-python.sh /app/agents/python/contrast-python-agent.tar.gz
#RUN mkdir -p /app/agents/node
#RUN sh ./grab-latest-from-maven.sh /app/agents/node/node-contrast.tgz

CMD cp -rp /app/agents/* /agents
