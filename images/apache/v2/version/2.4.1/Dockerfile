###############################################################################
# Hadoop 2.4.1 image
###############################################################################

# Set hadoop-2.x as base image
FROM crs4/hadoop-apache-v2

# set hadoop version
ENV HADOOP_VERSION 2.4.1

# set hadoop tar.gz archivename
ENV HADOOP_ARCHIVE_TARGZ hadoop-${HADOOP_VERSION}.tar.gz

# copy temp files (e.g., the optional HADOOP_ARCHIVE_TARGZ)
COPY * ./ 

# download hadoop distro
RUN ${HADOOP_ADMIN_SCRIPTS}/deploy-hadoop.sh . ${HADOOP_ARCHIVE_TARGZ} ${HADOOP_VERSION} ${HADOOP_HOME}

# Copy configuration files (hadoop v2)
RUN cp ${HADOOP_CUSTOM_CONF_DIR}/* ${HADOOP_CONF_DIR}/