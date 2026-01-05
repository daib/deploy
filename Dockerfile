FROM maven:3.9.9-eclipse-temurin-21 AS java_build
ENV HOME=/usr/src/app
RUN mkdir -p $HOME
WORKDIR $HOME
ADD java-modules/modules/callgate $HOME
ADD conf $HOME
RUN mvn verify --fail-never
RUN sed -i'' -e "s|localhost|\$\{AUTHEN_SERVER\}|g" src/main/resources/application.properties
COPY conf/langrobo.com.p12 src/main/resources/
RUN mvn clean -Dmaven.test.skip=true install

FROM golang:1.24 AS go_build
ENV HOME=/usr/src/app
RUN mkdir -p $HOME
WORKDIR $HOME
COPY go-modules $HOME
RUN pwd
RUN go mod tidy
RUN go build -v -o vocab ./apps/vocab-builder/vocab-quiz-generator/cmd/main.go

FROM ubuntu

RUN apt update
RUN apt install openjdk-21-jdk openjdk-21-jre -y
RUN apt install wget unzip vim iputils-ping -y

RUN groupadd -r langrobogroup && useradd -r -g langrobogroup langrobo

ENV BUILD_HOME=/usr/src/app
#ENV HOME=/home/root
ENV HOME=/home/langrobo
ENV INSTALL_HOME=$HOME/app

COPY --from=java_build $BUILD_HOME/target/Callgate-0.0.1-SNAPSHOT.jar $INSTALL_HOME/Callgate-0.0.1-SNAPSHOT.jar
COPY --from=go_build $BUILD_HOME/vocab $INSTALL_HOME/vocab
COPY java-modules/modules/auth-server/src/main/resources/auth-server-realm.json $INSTALL_HOME/resources/
#RUN sed -i'' -e "s|localhost|langrobo.com|g" resources/auth-server-realm.json
COPY vocab_quiz.csv $INSTALL_HOME/resources
#RUN wget -P $INSTALL_HOME "https://github.com/keycloak/keycloak/releases/download/26.4.0/keycloak-26.4.0.zip"
#RUN unzip keycloak-26.4.0.zip
COPY keycloak-26.3.3 $INSTALL_HOME/keycloak
COPY conf/* $INSTALL_HOME/keycloak/conf
RUN $INSTALL_HOME/keycloak/bin/kc.sh import --file $INSTALL_HOME/resources/auth-server-realm.json
COPY scripts $INSTALL_HOME/scripts

ARG TARGETARCH
# add current (including keycloak) certifiate to trustStore so that spingboot server can connect to keycloak
RUN export JAVA_HOME=$(readlink -f /usr/bin/java | sed "s:bin/java::")
RUN keytool -import -alias langrobo.com -keystore /usr/lib/jvm/java-21-openjdk-$TARGETARCH/lib/security/cacerts -file $INSTALL_HOME/keycloak/conf/langrobo.com.crt -storepass changeit -noprompt
RUN chown -R langrobo:langrobogroup $HOME
RUN mkdir $INSTALL_HOME/data && chown -R langrobo:langrobogroup $INSTALL_HOME/data
USER langrobo
CMD ["/home/langrobo/app/scripts/start"]
