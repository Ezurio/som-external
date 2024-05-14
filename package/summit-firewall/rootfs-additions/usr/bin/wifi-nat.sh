#!/bin/sh

start() {
  iptables-restore </etc/wifi-nat.conf
  ip6tables-restore </etc/wifi6-nat.conf

  [ ! -f /etc/default/wifi-nat ] || . /etc/default/wifi-nat start

  sysctl -qw net.ipv4.ip_forward=1 net.ipv6.conf.all.forwarding=1
}

stop() {
  sysctl -qw net.ipv4.ip_forward=0 net.ipv6.conf.all.forwarding=0

  [ ! -f /etc/default/wifi-nat ] || . /etc/default/wifi-nat stop

  # flushing all rules (really we should just delete what we created)
  iptables -F # Deleting all rules
  iptables -X # Deleting all non-builtin chains themselves
  iptables -t nat -F

  ip6tables -F # Deleting all rules
  ip6tables -X # Deleting all non-builtin chains themselves
  ip6tables -t nat -F
}

case "${1}" in

start) ## up - setup network policy
  start
  ;;

stop) ## down - cleanup things we configured earlier
  stop
  ;;

restart | reload)
  stop
  start
  ;;

*)
  echo "Usage: $0 <start|stop|restart|reload>"
  exit 1
  ;;

esac
