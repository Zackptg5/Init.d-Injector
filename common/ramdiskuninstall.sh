ui_print "   Removing setools from /sbin..."
for FILE in /system/bin/sepolicy-inject /system/xbin/sepolicy-inject /system/bin/seinfo /system/xbin/seinfo /system/bin/sesearch /system/xbin/sesearch; do
  [ -f "$FILE.bak" ] && mv -f $FILE.bak $FILE
done
