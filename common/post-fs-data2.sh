# This script will be executed in post-fs-data mode
# More info in the main Magisk thread
test -f $SYS/etc/init.d/0000liveboot && su -c sh $SYS/etc/init.d/0000liveboot &
