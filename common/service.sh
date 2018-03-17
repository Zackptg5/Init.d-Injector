# This script will be executed in late_start service mode
# More info in the main Magisk thread
for i in $SYS/etc/init.d/*; do
  if [ -x $i ]; then
    [ "$(basename $i)" != "0000liveboot" ] && su -c $i &
  fi
done
