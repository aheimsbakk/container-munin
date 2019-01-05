#!/bin/bash

NODES="${NODES:-}"
SNMP_NODES="${SNMP_NODES:-}"

# Fix ownership
chown munin.munin \
  /var/log/munin /run/munin /var/lib/munin \
  /etc/munin/munin-conf.d /etc/munin/plugin-conf.d

# Prepare for rrdcached
sudo -u munin -- mkdir -p /var/lib/munin/rrdcached-journal

# Start rrdcached
sudo -u munin -- /usr/sbin/rrdcached \
  -p /run/munin/rrdcached.pid \
  -B -b /var/lib/munin/ \
  -F -j /var/lib/munin/rrdcached-journal/ \
  -m 0660 -l unix:/run/munin/rrdcached.sock \
  -w 1800 -z 1800 -f 3600

# Concifure munin node in the docker
munin-node-configure --shell --suggest 2>/dev/null | bash

# generate node list
[[ ! -z "$NODES" ]] && for NODE in "$NODES"
do
  NAME=`echo "$NODE" | cut -d ":" -f1`
  HOST=`echo "$NODE" | cut -d ":" -f2`
  PORT=`echo "$NODE" | cut -d ":" -f3`
  if [ ${#PORT} -eq 0 ]; then
      PORT=4949
  fi
  if ! grep -q "$HOST" /etc/munin/munin-conf.d/nodes.conf 2>/dev/null ; then
    cat << EOF >> /etc/munin/munin-conf.d/nodes.conf
[$NAME]
    address $HOST
    use_node_name yes
    port $PORT

EOF
  fi
done

# generate smtp node list, and query smtp hosts for config
[[ ! -z "$SNMP_NODES" ]] && for NODE in "$SNMP_NODES"
do
  HOST=`echo "$NODE" | cut -d ":" -f1`
  COMMUNITY=`echo "$NODE" | cut -d ":" -f2`
  if ! grep -q "$HOST" /etc/munin/munin-conf.d/smtp-nodes.conf 2>/dev/null ; then
    cat << EOF >> /etc/munin/munin-conf.d/smtp-nodes.conf
[$HOST]
    address 127.0.0.1
    use_node_name no

EOF
    HOST=`echo "$HOST" | cut -d ";" -f2`
    cat << EOF >> /etc/munin/plugin-conf.d/snmp_communities
[snmp_${HOST}_*]
env.community $COMMUNITY

EOF
    munin-node-configure --shell --snmp "$HOST" --snmpcommunity "$COMMUNITY" | bash
  fi
done

# Start munin node on the docker 
munin-node

# Run once before we start fcgi
sudo -u munin -- /usr/bin/munin-cron munin

# Spawn fast cgi process for generating graphs on the fly
spawn-fcgi -s /var/run/munin/fastcgi-graph.sock -U nginx -u munin -g munin -- \
  /usr/share/webapps/munin/cgi/munin-cgi-graph

# Spawn fast cgi process for generating html on the fly
spawn-fcgi -s /var/run/munin/fastcgi-html.sock -U nginx -u munin -g munin -- \
  /usr/share/webapps/munin/cgi/munin-cgi-html

# Munin and logrotate runs in cron, start cron
crond

# Start web-server
nginx
