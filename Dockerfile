FROM r-base:latest

LABEL maintainer "Kangaroo Factory <xxx@xxx.com>"

## Add here libraries dependencies
## there are more libraries that are needed here
RUN apt-get update && apt-get install -y \
    sudo \
    gdebi-core \
    pandoc \
    #pandoc-citeproc \
    libcurl4-gnutls-dev \
    libssl-dev \
    libpq-dev \
    libgeos-dev \
    locales \
    libproj-dev \
    libgdal-dev gdal-bin \
    libudunits2-0 libudunits2-data libudunits2-dev \
    git \
    openssh-client \
    libssh2-1-dev \
    libgit2-dev \
    libglib2.0-dev/unstable \
    libgsl-dev \
    #lsb_release \
  && apt-get clean \
  && rm -rf /var/lib/apt/lists/*

## Change timezone
ENV CONTAINER_TIMEZONE Europe/Paris
ENV TZ Europe/Paris

RUN sudo echo "Europe/Paris" > /etc/timezone
RUN echo "fr_FR.UTF-8 UTF-8" >> /etc/locale.gen \
  && locale-gen fr_FR.UTF8 \
  && /usr/sbin/update-locale LANG=fr_FR.UTF-8

ENV LC_ALL fr_FR.UTF-8
ENV LANG fr_FR.UTF-8

## Download and install Shiny-server
RUN wget --no-verbose https://download3.rstudio.org/ubuntu-14.04/x86_64/VERSION -O "version.txt" \
  && VERSION=$(cat version.txt) \
  && wget --no-verbose "https://download3.rstudio.org/ubuntu-14.04/x86_64/shiny-server-$VERSION-amd64.deb" -O ss-latest.deb \
  #&& gdebi -n ss-latest.deb \
  && dpkg -i ss-latest.deb \
  && rm -f version.txt ss-latest.deb \
  && rm -rf /var/lib/apt/lists/*

## R package dependencies
## Add here R packages dependencies
RUN Rscript -e "install.packages(c('shiny'), repos='https://cran.biotools.fr/')"
## To get last version of packages
# comment it if you install specific R packages version
RUN Rscript -e "update.packages(ask=FALSE)"

## App name by default, the name is set at docker build dynamically using project name
ARG APP_NAME="my-kangaroo-app"

## Shiny-server configuration
## Configuration Files creation 
RUN echo "run_as shiny;\n\
  preserve_logs true;\n\
  server { \n\
  listen 3838;\n\
  location / { \n\
    app_init_timeout 120; \n\
    app_idle_timeout 30; \n\
    site_dir /srv/shiny-server/${APP_NAME}; \n\
    log_dir /var/log/shiny-server;\n\
    directory_index off; \n\
  }\n\
}" > /etc/shiny-server/shiny-server.conf

RUN echo '#!/bin/sh\n\
  touch /var/log/shiny-server.log\n\
  chown shiny.root /var/log/shiny-server.log\n\
  touch /var/run/shiny-server.pid\n\
  chown shiny.root /var/run/shiny-server.pid\n\
  chown -R shiny.shiny /var/lib/shiny-server\n\
  su shiny -c "shiny-server --pidfile=/var/run/shiny-server.pid >> /var/log/shiny-server.log 2>&1"\n' > /usr/bin/shiny-server.sh

RUN chown -R shiny.root /srv/shiny-server \
  && chown -R shiny.root /usr/bin/shiny-server.sh \
  && chmod u+x /usr/bin/shiny-server.sh

## Clean unnecessary libraries
RUN apt-get update && apt-get remove --purge -y \
    gdebi-core \
    libcurl4-gnutls-dev \
    libcairo2-dev/unstable \
    libxt-dev \
    libssl-dev \
    libpq-dev \
    libgeos-dev \
    libproj-dev \
    libgdal-dev \
    libudunits2-dev \
    git \
    openssh-client \
    libssh2-1-dev \
    libgit2-dev \
  && apt-get autoremove -y \
  && apt-get clean \
  && rm -rf /var/lib/apt/lists/*

## Change shiny user rights
## USER shiny
RUN passwd shiny -d
RUN mkdir -p /var/log/shiny-server \
  && chown shiny.shiny /var/log/shiny-server
WORKDIR /home/shiny

## Copy the application into image
## Add here files and directory necessary for the app.
## global.R ui.R server.R ...
RUN mkdir -p /srv/shiny-server/${APP_NAME}
COPY ui.R /srv/shiny-server/${APP_NAME}
COPY server.R /srv/shiny-server/${APP_NAME}
COPY www/* /srv/shiny-server/${APP_NAME}/www/

RUN chown -R shiny.root /srv/shiny-server

EXPOSE 3838

CMD ["/usr/bin/shiny-server.sh"]


