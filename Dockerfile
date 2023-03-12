FROM rocker/shiny:latest

LABEL maintainer "Kangaroo Factory <xxx@xxx.com>"

RUN apt-get update && apt-get install -y \
sudo \
gdebi-core \
pandoc \
pandoc-citeproc \
libcurl4-gnutls-dev \
libcairo2-dev \
libxt-dev \
xtail \
wget

## Change timezone
ENV CONTAINER_TIMEZONE Europe/Paris
ENV TZ Europe/Paris

# -- kangaroo: adding this to update locales (fixing echo "fr_FR.UTF-8 UTF-8" ...)
#RUN sudo locale-gen fr_FR.UTF8

RUN sudo echo "Europe/Paris" > /etc/timezone
RUN echo "fr_FR.UTF-8 UTF-8" >> /etc/locale.gen \
  && locale-gen fr_FR.UTF-8 \
  && /usr/sbin/update-locale LANG=fr_FR.UTF-8

ENV LC_ALL fr_FR.UTF-8
ENV LANG fr_FR.UTF-8

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

#COPY ui.R /srv/shiny-server/${APP_NAME}
COPY shinyapp /srv/shiny-server/${APP_NAME}

RUN chown -R shiny.root /srv/shiny-server

EXPOSE 3838

CMD ["/usr/bin/shiny-server.sh"]