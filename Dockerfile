FROM harbor.wistron.com/base_image/openjdk:8-jdk
COPY target/ccm-backend-latest.jar /app/app.jar
COPY src/main/resources/logback.xml /app/logback.xml
ENTRYPOINT ["java","-jar","/app/app.jar"]
