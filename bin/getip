#!/bin/bash

get_ifname_ip() {
  IFNAME=$1
  echo "$(ip addr show $IFNAME | grep 'inet ' | awk '{print $2}' | cut -d/ -f1 | head -n 1)"
}

get_default_ip() {
  IFNAME="$(ip route show default | awk '/default/ {print $5}')"
  echo "$(get_ifname_ip $IFNAME)"
}

if [ $# -eq 0 ]; then
  GATEWAY_IP=$(get_default_ip)
  echo "$GATEWAY_IP"
elif [ "$1" = "public" ]; then
  PUBLIC_IP=$(curl -sk --connect-timeout 5 https://ifconfig.me)
  if [ -z "$PUBLIC_IP" ]; then
      PUBLIC_IP=$(get_default_ip)
  fi
  echo "$PUBLIC_IP"
else
  IP_ADDRESS=$(get_ifname_ip $1)
  if [ -z "$IP_ADDRESS" ]; then
      IP_ADDRESS=$(get_default_ip)
  fi
  echo "$IP_ADDRESS"
fi