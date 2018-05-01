#!/system/bin/sh
if [ "$1" == "-ls" ]; then LS=true; else LS=false; fi

for i in /system/etc/init.d/*; do
  case $i in
    *-ls|*-ls.sh) $LS && if [ -f "$i" -a -x "$i" ]; then $i & fi;;
    *) $LS || if [ -f "$i" -a -x "$i" ]; then $i & fi;;
  esac
done

exit 0
