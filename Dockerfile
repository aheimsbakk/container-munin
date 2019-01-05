FROM alpine:3.8

# Thats me
MAINTAINER Arnulf Heimsbakk <arnulf.heimsbakk@gmail.com>

# Install packages
RUN apk update; \
    apk add dumb-init sudo logrotate munin rrdtool-cached \
            nginx spawn-fcgi perl-cgi-fast; \
    rm /var/cache/apk/*

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
