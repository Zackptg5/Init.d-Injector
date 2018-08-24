# AnyKernel2 Ramdisk Mod Script
# osm0sis @ xda-developers

## AnyKernel setup
# reinitialize needed vars and functions
INSTALLER=<INSTALLER>
OUTFD=<OUTFD>
BOOTMODE=<BOOTMODE>
MAGISK=<MAGISK>
slot=<SLOT>
INSTALL=true
PATCHONLY=false

ui_print() {
  $BOOTMODE && echo "$1" || echo -e "ui_print $1\nui_print" >> /proc/self/fd/$OUTFD
}

. $INSTALLER/config.sh
. $INSTALLER/common/unityfiles/util_functions.sh
api_level_arch_detect

# shell variables
ramdisk_compression=auto
block=auto;


## AnyKernel methods (DO NOT CHANGE)
# import patching functions/variables - see for reference
. $INSTALLER/common/unityfiles/tools/ak2-core.sh

## AnyKernel file attributes
# set permissions/ownership for included ramdisk files
chmod -R 750 $ramdisk/*
chown -R root:root $ramdisk/*

## AnyKernel install
ui_print "   Unpacking boot image..."
ui_print " "
dump_boot

# File list - only needed for slot devices. Place every file you will modify with relative path to root in the list variable
# See here for more details: https://forum.xda-developers.com/showpost.php?p=71924246&postcount=451
list="sepolicy"
[ "$slot" -a "$list" ] && slot_device

# detect setools (binaries by xmikos @github)
case $ABILONG in
  arm64*) SETOOLS=$bin/setools-android/arm64-v8a;;
  armeabi-v7a*) SETOOLS=$bin/setools-android/armeabi-v7a;;
  arm*) SETOOLS=$bin/setools-android/armeabi;;
  x86_64*) SETOOLS=$bin/setools-android/x86_64;;
  x86*) SETOOLS=$bin/setools-android/x86;;
  mips64*) SETOOLS=$bin/setools-android/mips64;;
  mips*) SETOOLS=$bin/setools-android/mips;;
esac

# use sudaemon if present, permissive shell otherwise
if [ "$($SETOOLS/sesearch --allow -s su $overlay\sepolicy)" ]; then
  DOMAIN=su
elif [ "$($SETOOLS/sesearch --allow -s sudaemon $overlay\sepolicy)" ]; then
  DOMAIN=sudaemon
else
  DOMAIN=shell
fi

# detect already present init.d support
for FILE in $(find $overlay /system /vendor -type f -name '*.rc'); do
  if [ "$(grep 'service sysinit' $FILE)" ]; then
    if [ "$(sed -n "/service sysinit/,/^$/{/seclabel/p}" $FILE)" ]; then
      # Only patch for current init.d implementation if it uses same seclabel to avoid scripts running more than once at boot
      DOMAIN2=$(sed -n "/service sysinit/,/^$/{/seclabel u:r:.*:s0/{s/.*seclabel u:r:\(.*\):s0.*/\1/; p}}" $FILE)
      [ "$DOMAIN" == "$DOMAIN2" ] && { PATCHONLY=true; $INSTALL && { ui_print "   Sysinit w/ seclabel detected in $(echo $FILE | sed "s|$ramdisk||")!"; "   Using existing init.d implementation!"; }; }
    fi
    break
  fi
done

# begin ramdisk changes
if $INSTALL; then
  # add proper init.d patch
  if ! $PATCHONLY; then
    ui_print "   Installing scripts..."
    sed -i "s/<DOMAIN>/$DOMAIN/g" $INSTALLER/patch/init.initd.rc
    cp_ch_nb $INSTALLER/patch/init.initd.rc /system/etc/init/init.initd.rc 0644 false
    cp_ch_nb $INSTALLER/patch/initd.sh /system/bin/initd.sh 0755 false
  fi
  
  case $DOMAIN in
    "su"|"sudaemon") ui_print "   $DOMAIN found! No need for sepolicy patching";;
    *) ui_print "   Setting $DOMAIN to permissive..."; backup_file $overlay\sepolicy; $SETOOLS/sepolicy-inject -Z $DOMAIN -P $overlay\sepolicy;;
  esac
    
  # copy setools
  ui_print "   Adding setools to /sbin..."
  for FILE in /system/bin/sepolicy-inject /system/xbin/sepolicy-inject /system/bin/seinfo /system/xbin/seinfo /system/bin/sesearch /system/xbin/sesearch; do
    backup_and_remove $FILE
  done
  cp -f $SETOOLS/* $overlay\sbin
  chmod 0755 $overlay\sbin/*
else
  ui_print "   Removing patches and setools..."
  rm -f /system/bin/initd.sh /system/etc/init/init.initd.rc $overlay\sbin/sepolicy-inject $overlay\sbin/sesearch $overlay\sbin/seinfo
  ui_print "   Restoring original files..."
  [ "$DOMAIN" != "su" -a "$DOMAIN" != "sudaemon" ] && restore_file $overlay\sepolicy
  for FILE in /system/bin/sepolicy-inject /system/xbin/sepolicy-inject /system/bin/seinfo /system/xbin/seinfo /system/bin/sesearch /system/xbin/sesearch; do
    restore_file $FILE
  done
fi

#end ramdisk changes
ui_print "   Repacking boot image..."
write_boot

# end install
