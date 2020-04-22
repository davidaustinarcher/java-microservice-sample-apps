FROM maven:3.5-jdk-8

WORKDIR /app
COPY pom.xml .
COPY src ./src

RUN mvn clean package

EXPOSE 8003
ENTRYPOINT ["mvn","jetty:run"] 
