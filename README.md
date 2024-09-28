# JFrog Artifactory OSS Container

![GitHub action workflow status](https://github.com/AgorastisMesaio/docker-img-jfrog-artifactory/actions/workflows/docker-publish.yml/badge.svg)

This repository contains a `Dockerfile` aimed to create a *base image* to provide a JFrog Artifactory OSS container. JFrog Artifactory OSS (Open Source Software) is a binary repository manager that provides a robust and scalable solution for managing binary artifacts throughout the application development lifecycle. It serves as a single source of truth for all binary artifacts, enabling efficient management, storage, and retrieval.
.

This image implements the ability to:

- Create a permanent Token under `./token/permanentToken.json`, which is very useful while developing against Artifactory. You don't even need to enter into the GUI.
- Create a set of repositories during first time deployment (see `./config/artifactory.repository.config.json`)

## Key Features

- **Universal Repository**: Supports multiple package formats including Maven, Gradle, Docker, npm, and more.
- **Efficient Storage**: Optimizes storage with deduplication and garbage collection.
- **High Availability**: Ensures reliable access to artifacts with redundancy and failover mechanisms.
- **Security**: Provides secure access to artifacts with fine-grained permissions and LDAP integration.
- **Integration**: Integrates seamlessly with CI/CD tools, version control systems, and other DevOps tools.

## User cases

- Dependency Management: Artifactory OSS acts as a proxy between developers and external repositories, caching and managing dependencies to ensure build stability and speed up build times.

- CI/CD Pipeline Integration: Integrates with CI/CD tools like Jenkins, Bamboo, and TeamCity to streamline the build and release process by managing artifacts efficiently.

- Docker Registry: Serves as a Docker registry, managing Docker images and providing capabilities such as image promotion, distribution, and cleanup.

- Release Management: Facilitates the release process by managing versioned artifacts, ensuring consistency, and providing a clear audit trail for releases.

- Binary Storage: Provides a central repository for all binary artifacts, enabling easy retrieval, versioning, and distribution across teams.

- Secure Distribution: Ensures secure distribution of artifacts with role-based access control and integration with security tools to scan for vulnerabilities.

## Usage

### Consume in your `docker-compose.yml`

This is the typical use case; I want to have a binary storage to have a central repository for all binary artifacts. I've setup a PostgreSQL as backend in my docker compose project that will work together with Artifactory

```yaml
### Docker Compose example

volumes:
  # Artifactory
  postgres_data:
    driver: local
  artifactory_data:
    driver: local

networks:
  my_network:
    name: my_network
    driver: bridge

services:
  ct_postgres:
    image: ghcr.io/agorastismesaio/docker-img-postgres:main
    hostname: postgres
    container_name: ct_postgres
    restart: always
    environment:
      - POSTGRES_DB=artifactory
      - POSTGRES_USER=artifactory
      - POSTGRES_PASSWORD=password
    volumes:
      - postgres_data:/var/lib/postgresql/data
    logging:
      driver: json-file
      options:
        max-size: "50m"
        max-file: "10"
    ulimits:
      nproc: 65535
      nofile:
        soft: 32000
        hard: 40000
    networks:
      - my_network

  ct_artifactory:
    build:
      context: .
      dockerfile: Dockerfile
    image: ghcr.io/agorastismesaio/docker-img-jfrog-artifactory:main
    hostname: artifactory
    container_name: ct_artifactory
    restart: always
    ulimits:
      nproc: 65535
      nofile:
        soft: 32000
        hard: 40000
    environment:
      #- ARTIFACTORY_LOG_LEVEL=warn
      - ENABLE_MIGRATION=y
      - JF_SHARED_DATABASE_TYPE=postgresql
      - JF_SHARED_DATABASE_USERNAME=artifactory
      - JF_SHARED_DATABASE_PASSWORD=password
      - JF_SHARED_DATABASE_URL=jdbc:postgresql://ct_postgres:5432/artifactory
      - JF_SHARED_DATABASE_DRIVER=org.postgresql.Driver
      - JF_SHARED_NODE_IP=artifactory
      - JF_SHARED_NODE_ID=myid
      - JF_SHARED_NODE_NAME=myname
      - JF_ROUTER_ENTRYPOINTS_EXTERNALPORT=8082
    ports:
      - '8082:8082'
    volumes:
      - ./config:/config
      - artifactory_data:/var/opt/jfrog/artifactory
      - ./token:/var/opt/jfrog/artifactory/token
    networks:
      - my_network
    depends_on:
      - ct_postgres
```

Start your services

```sh
docker compose up --build -d
```

In our example, you can now connect to [http://localhost:8082](http://localhost:8082)

## For developers

If you copy or fork this project to create their own base image, instead of consuming the image itself.

### Building the Image

To build the Docker image for local testing your can run the following command in the directory containing the Dockerfile:

```sh
docker build --no-cache -t docker-img-jfrog-artifactory:main .
or
docker compose up --build -d
```

### Troubleshoot

```sh
docker run --rm -it --entrypoint /bin/bash --name artifactory --hostname artifactory agorastismesaio/docker-img-jfrog-artifactory:main
```
