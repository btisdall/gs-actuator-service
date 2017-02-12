FROM openjdk:8-jre-alpine

WORKDIR /mnt/app
COPY gs-actuator-service-0.1.1.jar /mnt/app/

ENTRYPOINT java -jar /mnt/app/gs-actuator-service-0.1.1.jar
EXPOSE 9000
