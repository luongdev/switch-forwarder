#!/bin/bash
set -e

RUN_FILE="/var/run/.freeswitch"
PASS_FILE="/var/run/.pass"
CONF_DIR="/etc/switch/conf"

mkdir -p /opt/switch/conf
rm -rf "$CONF_DIR"

FIRST_RUN="0"
if [ ! -e $RUN_FILE ]; then
  FIRST_RUN="1"
fi

if [ "$FIRST_RUN" = "1" ]; then
  mv /tmp/bin/*                             /usr/bin/
# mv "$CONF_DIR"                            "$CONF_DIR.bak"
  mv /tmp/conf                              "$CONF_DIR" 
  cp "$CONF_DIR/vars.xml"                   /opt/switch/conf/vars.xml

  echo "Default#Switch@6699" > "$PASS_FILE"

  CONTAINER_IP=$(getip "docker0")

  if [ "$LOCAL_IP" = "" ]; then
    LOCAL_IP=$(getip)
  fi

  if [ "$PUBLIC_IP" = "" ]; then
    PUBLIC_IP=$(getip "public")
  fi

  echo "Detect local_ip: $LOCAL_IP"
  echo "Detect container_ip: $CONTAINER_IP"
  echo "Detect public_ip: $PUBLIC_IP"

  ACL_CONF="$CONF_DIR/autoload_configs/acl.conf.xml"

  LB_RN=$(sed -n '/<node type="allow" cidr="127.0.0.1\/32"\/>/=' "$ACL_CONF" | head -n 1)
  LB_RN=${LB_RN:-4}

  sed -i "${LB_RN}a <node type=\"allow\" cidr=\"$LOCAL_IP/24\"/>" "$ACL_CONF"
  sed -i "${LB_RN}a <node type=\"allow\" cidr=\"$CONTAINER_IP/24\"/>" "$ACL_CONF"

  DB_HOST=${DB_HOST:-}
  DB_PORT=${DB_PORT:-}
  DB_USER=${DB_USER:-}
  DB_PASS=${DB_PASS:-}
  DB_NAME=${DB_NAME:-switch}
  DB_OPTS=${DB_OPTS:-}

  if [ "$DB_HOST" != "" ]; then
    CORE_DSN="pgsql://hostaddr=$DB_HOST port=$DB_PORT user=$DB_USER password=$DB_PASS dbname=$DB_NAME options='$DB_OPTS'"
    sed -i "2a <X-PRE-PROCESS cmd=\"set\" data=\"core_dsn=$CORE_DSN\"/>" "$CONF_DIR/vars_diff.xml"
    pgready -h $DB_HOST -p $DB_PORT -U $DB_USER -P $DB_PASS -t 15 -w

    for var in $(compgen -v | grep '^DB_'); do
      unset $var
    done
  fi

  touch "$RUN_FILE"

  if [ "$1" = 'freeswitch' ]; then
    shift

    while :; do
      case $1 in 
      -g|--g711-only)
          sed -i -e "s/global_codec_prefs=.*\"/global_codec_prefs=PCMU,PCMA\"/g" "$CONF_DIR/vars.xml"
          sed -i -e "s/outbound_codec_prefs=.*\"/outbound_codec_prefs=PCMU,PCMA\"/g" "$CONF_DIR/vars.xml"
        shift
        ;;

      --g711-only-alaw-preferred)
          sed -i -e "s/global_codec_prefs=.*\"/global_codec_prefs=PCMA,PCMU\"/g" "$CONF_DIR/vars.xml"
          sed -i -e "s/outbound_codec_prefs=.*\"/outbound_codec_prefs=PCMA,PCMU\"/g" "$CONF_DIR/vars.xml"
        shift
        ;;

      -e|--event-socket-port)
        if [ -n "$2" ]; then
          sed -i -e "s/name=\"listen-port\" value=\"8021\"/name=\"listen-port\" value=\"$2\"/g" "$CONF_DIR/autoload_configs/event_socket.conf.xml"
        fi
        shift
        shift
        ;;

      -a|--rtp-range-start)
        if [ -n "$2" ]; then
          sed -i -e "s/name=\"rtp-start-port\" value=\".*\"/name=\"rtp-start-port\" value=\"$2\"/g" "$CONF_DIR/autoload_configs/switch.conf.xml"
        fi
        shift
        shift
        ;;

      -z|--rtp-range-end)
        if [ -n "$2" ]; then
          sed -i -e "s/name=\"rtp-end-port\" value=\".*\"/name=\"rtp-end-port\" value=\"$2\"/g" "$CONF_DIR/autoload_configs/switch.conf.xml"
        fi
        shift
        shift
        ;;

      --ext-rtp-ip)
        if [ -n "$2" ]; then
          sed -i -e "s/ext_rtp_ip=.*\"/ext_rtp_ip=$2\"/g" "$CONF_DIR/vars_diff.xml"
        fi
        shift
        shift
        ;;

      --ext-sip-ip)
        if [ -n "$2" ]; then
          sed -i -e "s/ext_sip_ip=.*\"/ext_sip_ip=$2\"/g" "$CONF_DIR/vars_diff.xml"
        fi
        shift
        shift
        ;;

      -p|--password)
        if [ -n "$2" ]; then
          echo "$2" > "$PASS_FILE"
          sed -i -e "s/name=\"password\" value=\"Default#Switch@6699\"/name=\"password\" value=\"$2\"/g" "$CONF_DIR/autoload_configs/event_socket.conf.xml"
        fi
        shift
        shift
        ;;

      --codec-list)
        if [ -n "$2" ]; then
          sed -i -e "s/global_codec_prefs=.*\"/global_codec_prefs=$2\"/g" "$CONF_DIR/vars.xml"
          sed -i -e "s/outbound_codec_prefs=.*\"/outbound_codec_prefs=$2\"/g" "$CONF_DIR/vars.xml"
        fi
        shift
        shift
        ;;

      -l|--log-level)
        if [ -n "$2" ]; then
          sed -i -e "s/name=\"loglevel\" value=\".*\"/name=\"loglevel\" value=\"$2\"/g" "$CONF_DIR/autoload_configs/switch.conf.xml"
        fi
        shift
        shift
        ;;
      --auto)
          sed -i '2a <X-PRE-PROCESS cmd="set" data="local_ip_v4='$LOCAL_IP'"/>' "$CONF_DIR/vars_diff.xml"
          if [ "$PUBLIC_IP" != "$LOCAL_IP" ]; then
            sed -i -e "s/ext_sip_ip=.*\"/ext_sip_ip=$PUBLIC_IP\"/g" "$CONF_DIR/vars_diff.xml"
            sed -i -e "s/ext_rtp_ip=.*\"/ext_rtp_ip=$PUBLIC_IP\"/g" "$CONF_DIR/vars_diff.xml"
          fi
        shift
        ;;
      --)
        shift
        break
        ;;

      *)
        break
      esac

    done

    exec freeswitch "$@"
  fi
fi

exec "$@"