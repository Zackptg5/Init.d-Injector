# This script will be executed in late_start service mode
# More info in the main Magisk thread
COREPATH=$(dirname $MODPATH)
test ! -d $(dirname $COREPATH)/InitdInjector && { rm -f $COREPATH/post-fs-data.d/0000InitdInjector.sh; rm -f $0; exit; }
for FILE in $SYS/etc/init.d/*; do
  test "$FILE" != "$SYS/etc/init.d/0000liveboot" && su -c sh $FILE &
done
