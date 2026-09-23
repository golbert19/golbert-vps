#!/bin/bash
DATE=$(date +%Y-%m-%d)
LOG="/var/log/golbert/cron.log"
mkdir -p /var/log/golbert
for user in $(cut -d: -f1 /etc/passwd); do
  exp=$(chage -l $user 2>/dev/null | grep "Account expires" | cut -d: -f2 | xargs)
  if [[ "$exp"!= "never" && "$exp"!= "" ]]; then
    exp_sec=$(date -d "$exp" +%s 2>/dev/null)
    now_sec=$(date +%s)
    if [[ $exp_sec -lt $now_sec ]]; then
      userdel -f $user 2>/dev/null
      echo "[$DATE] BORRADO: $user" >> $LOG
    fi
  fi
done
systemctl restart xray 2>/dev/null
echo "9773873C2BC34C6D-da22c5b8" > /etc/golbert/license.key
