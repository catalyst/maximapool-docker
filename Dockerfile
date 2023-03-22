FROM tomcat:9-jre11
LABEL maintainer="O: University of Halle (Saale) Germany; OU: ITZ, department application systems" \
      license="Docker composition: MIT; Components: Please check"

ARG QTYPE_STACK_COMMIT=master
ARG QTYPE_STACK_REMOTE="https://github.com/maths/moodle-qtype_stack.git"

ENV MAXIMAPOOL=/opt/maximapool \
    TOMCAT=${CATALINA_HOME} \
    STACK_MAXIMA=/opt/maxima \
    RUN_USER=tomcat \
    RUN_GROUP=tomcat

RUN apt-get update \
    && apt-get install -y \
      openjdk-$(echo "$JAVA_VERSION" | cut -d '-' -f2 | cut -d '.' -f1)-jdk \
      ant \
      wget \
      gnuplot \
      sbcl \
      gettext-base \
      ca-certificates \
      curl \
      gpg \
      php \
      git

# Fetch some GPG keys we need to verify downloads
RUN set -ex \
  && for key in \
    B42F6819007F00F88E364FD4036A9C25BF357DD4 \
    6380DC428747F6C393FEACA59A84159D7001A4E5 \
  ; do \
    gpg --batch --keyserver pgp.mit.edu --recv-keys "$key" || \
    gpg --batch --keyserver ha.pool.sks-keyservers.net --recv-keys "$key" || \
    gpg --batch --keyserver keyserver.ubuntu.com --recv-keys "$key" || \
    gpg --batch --keyserver keyserver.pgp.com --recv-keys "$key" || \
    gpg --batch --keyserver ha.pool.sks-keyservers.net --recv-keys "$key" ; \
done

# 1. Update the image and install packages required
# openjdk-8-jdk, ant --> Building the *.war
# wget --> Downloading the maxima-sbcl packages
# gnuplot, sbcl --> for the STACK/maxima application
# gettext-base --> for envsubst
#
# 2. Install Maxima (sbcl) and remove Tomcat's host manager and examples
#
# 3. grab gosu for easy step-down from root and tini for signal handling
#
# 4. Remove package, which are no longer required
RUN cd ~ \
    && wget http://downloads.sourceforge.net/project/maxima/Maxima-Linux/5.41.0-Linux/maxima-common_5.41.0-6_all.deb \
    && wget http://downloads.sourceforge.net/project/maxima/Maxima-Linux/5.41.0-Linux/maxima-sbcl_5.41.0-6_amd64.deb \
    && echo "4b7615699050abd93b65210814e59eef783466f789157422979c7c242aa4661f  maxima-common_5.41.0-6_all.deb" | sha256sum -c \
    && echo "ebc38cb95833a630469bbad026937e6a4ac87cfb246d9100074a75d03bda1657  maxima-sbcl_5.41.0-6_amd64.deb" | sha256sum -c \
    && dpkg -i ./maxima-sbcl_5.41.0-6_amd64.deb ./maxima-common_5.41.0-6_all.deb \
    && rm maxima-common_5.41.0-6_all.deb maxima-sbcl_5.41.0-6_amd64.deb \
    && cd ${CATALINA_HOME}/webapps \
    && curl -o /usr/local/bin/gosu -fSL "https://github.com/tianon/gosu/releases/download/1.11/gosu-$(dpkg --print-architecture)" \
    && curl -o /usr/local/bin/gosu.asc -fSL "https://github.com/tianon/gosu/releases/download/1.11/gosu-$(dpkg --print-architecture).asc" \
    && gpg --batch --verify /usr/local/bin/gosu.asc /usr/local/bin/gosu \
    && rm /usr/local/bin/gosu.asc \
    && chmod +x /usr/local/bin/gosu \
    && curl -o /usr/local/bin/tini -fSL "https://github.com/krallin/tini/releases/download/v0.18.0/tini" \
    && curl -o /usr/local/bin/tini.asc -fSL "https://github.com/krallin/tini/releases/download/v0.18.0/tini.asc" \
    && gpg --batch --verify /usr/local/bin/tini.asc /usr/local/bin/tini \
    && rm /usr/local/bin/tini.asc \
    && chmod +x /usr/local/bin/tini \
    && rm -r /var/lib/apt/lists/*

# Add a tomcat user
RUN groupadd -r ${RUN_GROUP} && useradd -g ${RUN_GROUP} -d ${CATALINA_HOME} -s /bin/bash ${RUN_USER}

# Add pool source code and configuration assets
COPY assets/init-maxima-pool.sh assets/docker-healthcheck.sh assets/stack_util_maximapool assets/optimize.mac assets/servlet.conf.template assets/process.conf.template assets/generate_maximalocal_template.php ${MAXIMAPOOL}/

# Add STACK maxima.
RUN git clone ${QTYPE_STACK_REMOTE} qtype_stack && cd qtype_stack && git checkout ${QTYPE_STACK_COMMIT} && cd - \
    && cp -r  qtype_stack/stack/maxima ${STACK_MAXIMA} \
    && cp qtype_stack/stack/cas/casstring.units.class.php ${MAXIMAPOOL} \
    && sed -i 's/require_once/\/\/ require_once/g' ${MAXIMAPOOL}/casstring.units.class.php \
    && php ${MAXIMAPOOL}/generate_maximalocal_template.php > ${MAXIMAPOOL}/maximalocal.mac.template

# Remove unneeded packages.
RUN apt-get purge -y --auto-remove wget git php && rm -rf qtype_stack

RUN VER=$(grep stackmaximaversion ${STACK_MAXIMA}/stackmaxima.mac | grep -oP "\d+") \
    && echo "${VER}" >> ${MAXIMAPOOL}/stack-version \
    && mv ${MAXIMAPOOL}/init-maxima-pool.sh / \
    && chmod +x /init-maxima-pool.sh \
    && mkdir -p ${MAXIMAPOOL}/${VER} \
    && mv ${STACK_MAXIMA} ${MAXIMAPOOL}/${VER}/maxima \
    && mkdir -p ${MAXIMAPOOL}/${VER}/tmp/plots/ \
    && mkdir -p ${MAXIMAPOOL}/${VER}/tmp/logs/ \
    && cd ${MAXIMAPOOL}/ \
    && echo "Configuring Maxima for STACK" \
       && VER=$VER sh -c 'envsubst < servlet.conf.template > servlet.conf \
       && envsubst < process.conf.template > ${VER}/process.conf \
       && envsubst < maximalocal.mac.template > ${VER}/maximalocal.mac \
       && echo "Successfully configured Maxima for STACK ${VER}" \
       && echo "Optimizing Maxima (There will be some warnings due to docker container restrictions and strictness of sbcl) ..." \
       && mv ${MAXIMAPOOL}/optimize.mac ${MAXIMAPOOL}/${VER} \
       && cd ${MAXIMAPOOL}/${VER} \
       && maxima -b optimize.mac \
       && echo "Successfully optimized Maxima. Building the web application archive (war)."' \
    && cd ${MAXIMAPOOL} \
    && ant \
    && rm MaximaPool.war

HEALTHCHECK --interval=10s --timeout=9s --start-period=15s CMD ${MAXIMAPOOL}/docker-healthcheck.sh
ENTRYPOINT ["tini", "--", "/init-maxima-pool.sh"]
CMD ["catalina.sh", "run"]
