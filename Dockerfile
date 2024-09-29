# Dockerfile for JFrog Artifactory OSS
#
# This Dockerfile sets up a JFrog Artifactory OSS with two features, very useful
# to avoid setting up manually the repositories:
#
# - It will create a permanent token
# - It will create respositories (`./config/artifactory.repository.config.json`)
#
# Image directory struture.
# /opt/jfrog/artifactory/
#    var -> /var/opt/jfrog/artifactory
#
FROM releases-docker.jfrog.io/jfrog/artifactory-oss:latest

LABEL org.opencontainers.image.authors="Agorastis Mesaio"

# Copy entrypoint scripts
COPY --chown=1030:1030 --chmod=755 ./entrypoint.sh /entrypoint.sh
COPY --chown=1030:1030 --chmod=755 ./entrypoint-background.sh /opt/jfrog/artifactory/var/entrypoint-background.sh
COPY --chown=1030:1030 --chmod=755 ./test/testChangeAdminPassword.sh /opt/jfrog/artifactory/var/testChangeAdminPassword.sh

# Prepare the image
COPY --chmod=644 ./config/system.yaml /opt/jfrog/artifactory/var/etc
COPY --chmod=644 ./config/logback.xml /opt/jfrog/artifactory/var/etc/artifactory

# Next line doesn't appear in the log, but repo's are created, so it's working silently.
COPY --chmod=644 ./config/artifactory.repository.config.json /opt/jfrog/artifactory/var/etc/artifactory/artifactory.repository.config.import.json

# Next line does nothing... we might obsolete it...
COPY --chmod=644 ./config/access.config.template.yml /opt/jfrog/artifactory/var/etc/access/access.config.import.yml

# Execute as root
USER root

# Copy healthcheck
ADD healthcheck.sh /healthcheck.sh
RUN chmod +x /healthcheck.sh

# My custom health check
# I'm calling /healthcheck.sh so my container will report 'healthy' instead of running
# --interval=30s: Docker will run the health check every 'interval'
# --timeout=10s: Wait 'timeout' for the health check to succeed.
# --start-period=3s: Wait time before first check. Gives the container some time to start up.
# --retries=3: Retry check 'retries' times before considering the container as unhealthy.
HEALTHCHECK --interval=30s --timeout=10s --start-period=30s --retries=10 \
  CMD /healthcheck.sh || exit $?

# Go for it...
ENTRYPOINT ["/entrypoint.sh"]

# The CMD line represent the Arguments that will be passed to the
# entrypoint.sh. We'll use them to indicate the script what
# command will be executed through our entrypoint when it finishes
CMD ["/entrypoint-artifactory.sh"]
