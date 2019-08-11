# AnyKernel3 Ramdisk Mod Script
# osm0sis @ xda-developers

## AnyKernel setup
# begin properties
properties() { '
kernel.string=
do.devicecheck=0
do.modules=0
do.cleanup=1
do.cleanuponabort=1
device.name1=
device.name2=
device.name3=
device.name4=
device.name5=
supported.versions=
supported.patchlevels=
'; } # end properties

# shell variables
block=auto;
is_slot_device=auto;
ramdisk_compression=auto;
MODID=InitdInjector;


## AnyKernel methods (DO NOT CHANGE)
# import patching functions/variables - see for reference
. tools/ak3-core.sh;


## AnyKernel file attributes
# set permissions/ownership for included ramdisk files
# set_perm_recursive 0 0 755 644 $ramdisk/*;
# set_perm_recursive 0 0 750 750 $ramdisk/init* $ramdisk/sbin;


## AnyKernel install
dump_boot;

# begin ramdisk changes

PATCHONLY=false
# use sudaemon if present, permissive shell otherwise
if [ "$($tools/sesearch --allow -s su $ramdisk/sepolicy)" ]; then
  DOMAIN=su
elif [ "$($tools/$sesearch --allow -s sudaemon $ramdisk/sepolicy)" ]; then
  DOMAIN=sudaemon
else
  DOMAIN=shell
fi

# detect already present init.d support
for FILE in $(find $ramdisk /system /vendor -type f -name '*.rc'); do
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
  sed -i "s/<DOMAIN>/$DOMAIN/g" $home/init.initd.rc
  cp -f $home/init.initd.rc /system/etc/init/init.initd.rc
  cp -f $home/initd.sh /system/bin/initd.sh
  chmod 0755 /system/bin/initd.sh
fi

case $DOMAIN in
  "su"|"sudaemon") ui_print "   $DOMAIN secontext found! No need for sepolicy patching";;
  *) ui_print "   Setting $DOMAIN to permissive..."; backup_file $ramdisk/sepolicy; $tools/magiskpolicy --load $ramdisk/sepolicy --save $ramdisk/sepolicy "permissive $DOMAIN";;
esac

# copy magiskpolicy
ui_print "   Adding magiskpolicy to /sbin..."
cp -f $tools/magiskpolicy $ramdisk/sbin/magiskpolicy
chmod 0755 $ramdisk/sbin/magiskpolicy

# end ramdisk changes

ui_print "   Repacking boot img..."
write_boot;
ui_print " "
## end install
