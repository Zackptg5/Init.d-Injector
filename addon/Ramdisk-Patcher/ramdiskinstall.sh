# Put install only logic here
PATCHONLY=false
# use sudaemon if present, permissive shell otherwise
if [ "$(sesearch --allow -s su $RD/sepolicy)" ]; then
  DOMAIN=su
elif [ "$($sesearch --allow -s sudaemon $RD/sepolicy)" ]; then
  DOMAIN=sudaemon
else
  DOMAIN=shell
fi

# detect already present init.d support
for FILE in $(find $RD /system /vendor -type f -name '*.rc'); do
  if [ "$(grep 'service sysinit' $FILE)" ]; then
    if [ "$(sed -n "/service sysinit/,/^$/{/seclabel/p}" $FILE)" ]; then
      # Only patch for current init.d implementation if it uses same seclabel to avoid scripts running more than once at boot
      DOMAIN2=$(sed -n "/service sysinit/,/^$/{/seclabel u:r:.*:s0/{s/.*seclabel u:r:\(.*\):s0.*/\1/; p}}" $FILE)
      [ "$DOMAIN" == "$DOMAIN2" ] && { PATCHONLY=true; $INSTALL && { ui_print "   Sysinit w/ seclabel detected in $(echo $FILE | sed "s|$ramdisk||")!"; "   Using existing init.d implementation!"; }; }
    fi
    break
  fi
done

# add proper init.d patch
if ! $PATCHONLY; then
  sed -i "s/<DOMAIN>/$DOMAIN/g" $TMPDIR/common/init.initd.rc
  cp_ch -n $TMPDIR/common/init.initd.rc /system/etc/init/init.initd.rc
  cp_ch -np 0755 $TMPDIR/common/initd.sh /system/bin/initd.sh
fi

case $DOMAIN in
  "su"|"sudaemon") ui_print "   $DOMAIN secontext found! No need for sepolicy patching";;
  *) ui_print "   Setting $DOMAIN to permissive..."; cp_ch $RD/sepolicy $RD/sepolicy; magiskpolicy --load $RD/sepolicy --save $RD/sepolicy "permissive $DOMAIN";;
esac
  
# copy magiskpolicy
ui_print "   Adding magiskpolicy to /sbin..."
cp_ch -p 0755 $UF/$ARCH32/magiskpolicy $RD/sbin/magiskpolicy
