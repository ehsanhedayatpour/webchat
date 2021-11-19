FROM maven:3.6.2-jdk-8-slim as build
COPY pom.xml /build/
COPY src /build/src/
WORKDIR /build/
RUN mvn clean package

FROM openjdk:8-jdk-alpine
USER 1000
VOLUME /tmp
ARG JAVA_OPTS
ENV JAVA_OPTS=$JAVA_OPTS
COPY --from=build /build/target/websocket-demo-*.jar /usr/app/app.jar
WORKDIR /usr/app

EXPOSE 8080
ENTRYPOINT exec java $JAVA_OPTS -jar app.jar
