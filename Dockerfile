FROM jelastic/maven:3.9.5-openjdk-21 AS java_build 
ENV HOME=/usr/src/app
RUN mkdir -p $HOME
WORKDIR $HOME
ADD java-modules/modules/callgate $HOME
#ADD pom.xml $HOME
RUN mvn verify --fail-never
RUN sed -i'' -e "s|localhost|\$\{AUTHEN_SERVER\}|g" src/main/resources/application.properties
RUN mvn clean -Dmaven.test.skip=true install

FROM golang:1.24 as go_build
ENV HOME=/usr/src/app
WORKDIR $HOME
COPY go-modules $HOME
RUN pwd
RUN go mod tidy
RUN go build -v -o vocab /apps/vocab-builder/vocab-quiz-generator/cmd.go

FROM ubuntu

RUN apt update
RUN apt install openjdk-21-jdk openjdk-21-jre -y

ENV HOME=/usr/src/app

COPY --from=java_build $HOME/target/Callgate-0.0.1-SNAPSHOT.jar /usr/app/Callgate-0.0.1-SNAPSHOT.jar
COPY --from=go_build $HOME/vocab /usr/app/vocab
EXPOSE 8080 8080
ENTRYPOINT ["java","-jar","/usr/app/Callgate-0.0.1-SNAPSHOT.jar"]
