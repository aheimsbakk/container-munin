FROM aheimsbakk/base-alpine:latest

# Thats me
MAINTAINER Arnulf Heimsbakk <arnulf.heimsbakk@gmail.com>

# Install packages
RUN apk add --no-cache \
  coreutils \
  dumb-init \
  findutils \
  logrotate \
  munin \
  nginx \
  perl-cgi-fast \
  procps \
  rrdtool-cached \
  spawn-fcgi \
  sudo \
  ttf-opensans \
  tzdata \
  ;

# Set munin crontab
RUN sed '/^[^*].*$/d; s/ munin //g' /etc/munin/munin.cron.sample | crontab -u munin - 

# Log munin-node to stdout
RUN sed -i 's#^log_file.*#log_file /dev/stdout#' /etc/munin/munin-node.conf

# Add missing directory for nginx
RUN mkdir /run/nginx

# Default nginx.conf
COPY nginx.conf /etc/nginx/

# Copy munin config to nginx
COPY default.conf /etc/nginx/conf.d/

# Copy munin conf
COPY munin.conf /etc/munin/

# Start script with all processes
COPY docker-cmd.sh /

# Logrotate script for munin logs
COPY munin /etc/logrotate.d/

# Expose volumes
VOLUME /etc/munin/munin-conf.d /etc/munin/plugin-conf.d /var/lib/munin /var/log/munin

# Expose nginx
EXPOSE 80

# Use dumb-init since we run a lot of processes
ENTRYPOINT ["/usr/bin/dumb-init", "--"]

# Run start script or what you choose
CMD /docker-cmd.sh
