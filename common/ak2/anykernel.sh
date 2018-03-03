# AnyKernel2 Ramdisk Mod Script
# osm0sis @ xda-developers

## AnyKernel setup
# reinitialize needed vars and functions
INSTALLER=<INSTALLER>
OUTFD=<OUTFD>
BOOTMODE=<BOOTMODE>
SLOT=<SLOT>

ui_print() {
  $BOOTMODE && echo "$1" || echo -e "ui_print $1\nui_print" >> /proc/self/fd/$OUTFD
}

. $INSTALLER/common/unityfiles/util_functions.sh

# shell variables
ramdisk_compression=auto                        
# determine the location of the boot partition
if [ "$(find /dev/block -name boot | head -n 1)" ]; then
  block=$(find /dev/block -name boot | head -n 1)
elif [ -e /dev/block/platform/sdhci-tegra.3/by-name/LNX ]; then
  block=/dev/block/platform/sdhci-tegra.3/by-name/LNX
else
  abort "   ! Boot img not found! Aborting!"
fi

# force expansion of the path so we can use it
block=`echo -n $block`;

## AnyKernel methods (DO NOT CHANGE)
# import patching functions/variables - see for reference
. $INSTALLER/common/ak2/tools/ak2-core.sh

## AnyKernel file attributes
# set permissions/ownership for included ramdisk files
chmod -R 750 $ramdisk/*
chown -R root:root $ramdisk/*

# detect setools (binaries by xmikos @github)
case $(grep_prop ro.product.cpu.abi) in
  arm64*) SETOOLS=$INSTALLER/common/ak2/tools/setools-android/arm64-v8a;;
  armeabi-v7a*) SETOOLS=$INSTALLER/common/ak2/tools/setools-android/armeabi-v7a;;
  arm*) SETOOLS=$INSTALLER/common/ak2/tools/setools-android/armeabi;;
  x86_64*) SETOOLS=$INSTALLER/common/ak2/tools/setools-android/x86_64;;
  x86*) SETOOLS=$INSTALLER/common/ak2/tools/setools-android/x86;;
  mips64*) SETOOLS=$INSTALLER/common/ak2/tools/setools-android/mips64;;
  mips*) SETOOLS=$INSTALLER/common/ak2/tools/setools-android/mips;;
  *) ui_print " "; abort " ! CPU Type not supported for sepolicy patching! Exiting!";;
esac

## AnyKernel install
ui_print "   Unpacking boot image..."
ui_print " "
dump_boot

# File list
list="init*.rc sepolicy"

## AnyKernel Slot device support
slot_device

# determine install or uninstall
test "$(grep "ZIndicator" $overlay/init.rc)" && ACTION=Uninstall

# begin ramdisk changes
if [ -z $ACTION ]; then
  ui_print "   Adding init.d support to kernel..."
  # remove old broken init.d support
  ui_print "   Removing existing sysinit init.d logic..."
  for FILE in $overlay/init*.rc; do
    if [ "$(grep -E "init.d|sysinit" $FILE)" ]; then
	    backup_file $FILE
      remove_section_mod $FILE "# Run sysinit"
      remove_line $FILE "start sysinit"
      remove_section_mod $FILE "# sysinit"
      remove_section_mod $FILE "service sysinit"
      remove_section_mod $FILE "# init.d"
      remove_section_mod $FILE "service userinit"
	  fi
  done
  
  [ "$(find /system -name install-recovery.sh)" ] && { ui_print "   Removing init.d logic from install-recovery.sh..."; backup_file $(find /system -name install-recovery.sh); sed -i '/init.d/d' $(find /system -name install-recovery.sh); }
  
  # add proper init.d patch
  backup_file $overlay/init.rc
  ui_print "   Patching init files..."
  append_file $overlay/init.rc "# init.d" init
  
  # replace old broken init.d
  ui_print "   Replacing sysinit..."
  backup_and_remove /system/bin/sysinit
  backup_and_remove /system/xbin/sysinit
  backup_and_remove /system/bin/sepolicy-inject
  backup_and_remove /system/xbin/sepolicy-inject
  backup_and_remove /system/bin/seinfo
  backup_and_remove /system/xbin/seinfo
  backup_and_remove /system/bin/sesearch
  backup_and_remove /system/xbin/sesearch
  cp -f $patch/sysinit /system/bin/sysinit
  chmod 0755 /system/bin/sysinit

  # copy setools
  ui_print "   Installing setools to /sbin..."
  cp -f $SETOOLS/* sbin
  chmod 0755 sbin/*

  # sepolicy patches by CosmicDan @xda-developers
  ui_print "   Injecting sepolicy with init.d permissions..."
  
  backup_file sepolicy
  $SETOOLS/sepolicy-inject -Z sysinit -P $overlay/sepolicy
  $SETOOLS/sepolicy-inject -s init -t sysinit -c process -p transition -P $overlay/sepolicy
  $SETOOLS/sepolicy-inject -s init -t sysinit -c process -p rlimitinh -P $overlay/sepolicy
  $SETOOLS/sepolicy-inject -s init -t sysinit -c process -p siginh -P $overlay/sepolicy
  $SETOOLS/sepolicy-inject -s init -t sysinit -c process -p noatsecure -P $overlay/sepolicy

else
  ui_print "   Removing init.d support to kernel..."
  ui_print "   Removing init.d patches and sepolicy-inject..."
  rm -f sbin/sepolicy-inject sbin/sesearch sbin/seinfo
  ui_print "   Restoring original files..."
  for FILE in $overlay/init*.rc $overlay/sepolicy /system/bin/sysinit /system/xbin/sysinit /system/bin/sepolicy-inject /system/xbin/sepolicy-inject /system/bin/seinfo /system/xbin/seinfo /system/bin/sesearch /system/xbin/sesearch $(find /system -name install-recovery.sh); do
    restore_file $FILE
  done
fi

#end ramdisk changes
ui_print " "
ui_print "   Repacking boot image..."
write_boot

# end install
