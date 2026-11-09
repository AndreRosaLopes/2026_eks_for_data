# syntax=docker/dockerfile:1.7
# Spark image for the phase 03 jobs (D-047, D-050 to D-055): the official Spark 4.0.5 image plus the
# jars to read bronze through S3A and to write Iceberg tables. Built and pushed from the user's
# computer as ghcr.io/andrerosalopes/spark:4.0.5-iceberg1.12.0.

# Official image, pinned by digest so every rebuild uses the same base (D-051)
FROM apache/spark:4.0.5-python3@sha256:45eb1b8261a89bc7692be05aa4664676856f1c886cecc7b97b4e10f635b45b3c

# Links the ghcr.io package to this repository (its page shows the repository README)
LABEL org.opencontainers.image.source=https://github.com/AndreRosaLopes/2026_eks_for_data

ARG MAVEN=https://repo1.maven.org/maven2

# Iceberg runtime for Spark 4.0 (D-050)
ADD --chown=spark:spark --chmod=644 \
    --checksum=sha256:3f50e93e8ed322ae0da0e380f1b6c27116404329c62e55f0586697b1b8378306 \
    ${MAVEN}/org/apache/iceberg/iceberg-spark-runtime-4.0_2.13/1.12.0/iceberg-spark-runtime-4.0_2.13-1.12.0.jar /opt/spark/jars/

# S3A connector, matching Spark 4.0.5's Hadoop 3.4.1 (D-050)
ADD --chown=spark:spark --chmod=644 \
    --checksum=sha256:01334a07e179cae2b7e251f24857f11e3759108c9d6a79dcbe362a4295227da2 \
    ${MAVEN}/org/apache/hadoop/hadoop-aws/3.4.1/hadoop-aws-3.4.1.jar /opt/spark/jars/

# One AWS SDK version for S3A and Iceberg S3FileIO (D-052)
ADD --chown=spark:spark --chmod=644 \
    --checksum=sha256:031dd6bb9ac2a0a13fef637f3e9d9bf46c935316e19b089055840d886843787c \
    ${MAVEN}/software/amazon/awssdk/bundle/2.54.17/bundle-2.54.17.jar /opt/spark/jars/
ADD --chown=spark:spark --chmod=644 \
    --checksum=sha256:871e7b53b7329bd1fc19b7252dcadbaeb9cb072fde2b05fe005b815d64a9d50e \
    ${MAVEN}/software/amazon/awssdk/apache5-client/2.54.17/apache5-client-2.54.17.jar /opt/spark/jars/
