# AnyKernel2 Ramdisk Mod Script
# osm0sis @ xda-developers

## AnyKernel setup
# begin properties
properties() {
kernel.string=Kernel Init.d Injector
do.devicecheck=0
do.modules=0
do.cleanup=1
do.cleanuponabort=1
device.name1=
device.name2=
device.name3=
device.name4=
device.name5=			 
} # end properties

# shell variables
ramdisk_compression=auto                        
# determine the location of the boot partition
if [ -e /dev/block/platform/*/by-name/boot ]; then
  block=/dev/block/platform/*/by-name/boot
elif [ -e /dev/block/platform/*/*/by-name/boot ]; then
  block=/dev/block/platform/*/*/by-name/boot
elif [ -e /dev/block/platform/sdhci-tegra.3/by-name/LNX ]; then
  block=/dev/block/platform/sdhci-tegra.3/by-name/LNX
fi

# force expansion of the path so we can use it
block=`echo -n $block`;

## AnyKernel methods (DO NOT CHANGE)
# import patching functions/variables - see for reference
. /tmp/anykernel/tools/ak2-core.sh

## AnyKernel file attributes
# set permissions/ownership for included ramdisk files
chmod -R 750 $ramdisk/*
chown -R root:root $ramdisk/*

# detect setools (binaries by xmikos @github)
case $(grep_prop ro.product.cpu.abi) in
  arm64*) SETOOLS=/tmp/anykernel/tools/setools-android/arm64-v8a;;
  armeabi-v7a*) SETOOLS=/tmp/anykernel/tools/setools-android/armeabi-v7a;;
  arm*) SETOOLS=/tmp/anykernel/tools/setools-android/armeabi;;
  x86_64*) SETOOLS=/tmp/anykernel/tools/setools-android/x86_64;;
  x86*) SETOOLS=/tmp/anykernel/tools/setools-android/x86;;
  mips64*) SETOOLS=/tmp/anykernel/tools/setools-android/mips64;;
  mips*) SETOOLS=/tmp/anykernel/tools/setools-android/mips;;
  *) ui_print " "; abort " ! CPU Type not supported for sepolicy patching! Exiting!";;
esac

## AnyKernel install
ui_print "Unpacking boot image..."
ui_print " "
dump_boot

# File list
list="init*.rc sepolicy"

# LG Bump Boot img support (credits to Drgravy @xda-developers)
bump=false
if [ "$(grep_prop ro.product.brand)" = "lge" ] || [ "$(grep_prop ro.product.brand)" = "LGE" ]; then 
  case $(grep_prop ro.product.device) in
    d800|d801|d802|d803|ls980|vs980|101f|d850|d852|d855|ls990|vs985|f400) bump=true; ui_print "Bump device detected! Using bump exploit...";;
	*) ;;
  esac
fi

# Slot device support
if [ ! -z $slot ]; then            
  if [ -d $ramdisk/.subackup -o -d $ramdisk/.backup ]; then                                                                                                                                                                
    patch_cmdline "skip_override" "skip_override"
  else
    patch_cmdline "skip_override" ""
  fi
  # Overlay stuff
  if [ -d $ramdisk/.backup ]; then
    overlay=$ramdisk/overlay
  elif [ -d $ramdisk/.subackup ]; then
    overlay=$ramdisk/boot
  fi
  for rdfile in $list; do
    rddir=$(dirname $rdfile)
    mkdir -p $overlay/$rddir
    test ! -f $overlay/$rdfile && cp -rp /system/$rdfile $overlay/$rddir/
  done
else
  overlay=$ramdisk
fi

# Detect if boot.img is signed - credits to chainfire @xda-developers
unset LD_LIBRARY_PATH
BOOTSIGNATURE="/system/bin/dalvikvm -Xbootclasspath:/system/framework/core-oj.jar:/system/framework/core-libart.jar:/system/framework/conscrypt.jar:/system/framework/bouncycastle.jar -Xnodex2oat -Xnoimage-dex2oat -cp $bin/avb-signing/BootSignature_Android.jar com.android.verity.BootSignature"
if [ ! -f "/system/bin/dalvikvm" ]; then
  # if we don't have dalvikvm, we want the same behavior as boot.art/oat not found
  RET="initialize runtime"
else
  RET=$($BOOTSIGNATURE -verify /tmp/anykernel/boot.img 2>&1)
fi
test ! -z $slot && RET=$($BOOTSIGNATURE -verify /tmp/anykernel/boot.img 2>&1)
if (`echo $RET | grep "VALID" >/dev/null 2>&1`); then
  ui_print "Signed boot img detected!"
  mv -f $bin/avb-signing/avb $bin/avb-signing/BootSignature_Android.jar $bin
fi

# determine install or uninstall
test "$(grep "ZIndicator" $overlay/init.rc)" && ACTION=Uninstall

# begin ramdisk changes
if [ -z $ACTION ]; then
  # remove old broken init.d support
  ui_print "Removing existing init.d logic..."
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
  
  test -e $(find /system -name install-recovery.sh) && { backup_file $(find /system -name install-recovery.sh); sed -i '/init.d/d' $(find /system -name install-recovery.sh); }
  
  # create init.d directory
  test ! -d /system/etc/init.d && { test -f /system/etc/init.d && rm -f /system/etc/init.d; mkdir /system/etc/init.d; }
  
  # add proper init.d patch
  backup_file $overlay/init.rc
  ui_print "Patching init files..."
  append_file $overlay/init.rc "# init.d" init
  
  # replace old broken init.d
  ui_print "Replacing sysinit..."
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
  ui_print "Installing setools to /sbin..."
  cp -f $SETOOLS/* sbin
  chmod 0755 sbin/*

  # sepolicy patches by CosmicDan @xda-developers
  ui_print "Injecting sepolicy with init.d permissions..."
  
  backup_file sepolicy
  $SETOOLS/sepolicy-inject -z sysinit -P $overlay/sepolicy
  $SETOOLS/sepolicy-inject -Z sysinit -P $overlay/sepolicy
  $SETOOLS/sepolicy-inject -s init -t sysinit -c process -p transition -P $overlay/sepolicy
  $SETOOLS/sepolicy-inject -s init -t sysinit -c process -p rlimitinh -P $overlay/sepolicy
  $SETOOLS/sepolicy-inject -s init -t sysinit -c process -p siginh -P $overlay/sepolicy
  $SETOOLS/sepolicy-inject -s init -t sysinit -c process -p noatsecure -P $overlay/sepolicy
  $SETOOLS/sepolicy-inject -s sysinit -t sysinit -c dir -p search,read -P $overlay/sepolicy
  $SETOOLS/sepolicy-inject -s sysinit -t sysinit -c file -p read,write,open -P $overlay/sepolicy
  $SETOOLS/sepolicy-inject -s sysinit -t sysinit -c unix_dgram_socket -p create,connect,write,setopt -P $overlay/sepolicy
  $SETOOLS/sepolicy-inject -s sysinit -t sysinit -c lnk_file -p read -P $overlay/sepolicy
  $SETOOLS/sepolicy-inject -s sysinit -t sysinit -c process -p fork,sigchld -P $overlay/sepolicy
  $SETOOLS/sepolicy-inject -s sysinit -t sysinit -c capability -p dac_override -P $overlay/sepolicy
  $SETOOLS/sepolicy-inject -s sysinit -t system_file -c file -p entrypoint,execute_no_trans -P $overlay/sepolicy
  $SETOOLS/sepolicy-inject -s sysinit -t devpts -c chr_file -p read,write,open,getattr,ioctl -P $overlay/sepolicy
  $SETOOLS/sepolicy-inject -s sysinit -t rootfs -c file -p execute,read,open,execute_no_trans,getattr -P $overlay/sepolicy
  $SETOOLS/sepolicy-inject -s sysinit -t shell_exec -c file -p execute,read,open,execute_no_trans,getattr -P $overlay/sepolicy
  $SETOOLS/sepolicy-inject -s sysinit -t zygote_exec -c file -p execute,read,open,execute_no_trans,getattr -P $overlay/sepolicy
  $SETOOLS/sepolicy-inject -s sysinit -t toolbox_exec -c file -p getattr,open,read,ioctl,lock,getattr,execute,execute_no_trans,entrypoint -P $overlay/sepolicy

else
  ui_print "Removing init.d patches and sepolicy-inject..."
  rm -f sbin/sepolicy-inject sbin/sesearch sbin/seinfo
  for FILE in $overlay/init*.rc $overlay/sepolicy /system/bin/sysinit /system/xbin/sysinit /system/bin/sepolicy-inject /system/xbin/sepolicy-inject /system/bin/seinfo /system/xbin/seinfo /system/bin/sesearch /system/xbin/sesearch $(find /system -name install-recovery.sh); do
    restore_file $FILE
  done
fi

#end ramdisk changes
ui_print " "
ui_print "Repacking boot image..."
write_boot

# end install
