# AnyKernel2 Ramdisk Mod Script
# osm0sis @ xda-developers

## AnyKernel setup
# begin properties
properties() {
kernel.string=Kernel Audio Modification Library Injector Add-on
do.devicecheck=0
do.modules=0
do.cleanup=1
do.cleanuponabort=1
} # end properties

# shell variables
# determine the location of the boot partition
if [ -e /dev/block/platform/*/by-name/boot ]; then
  block=/dev/block/platform/*/by-name/boot;
elif [ -e /dev/block/platform/*/*/by-name/boot ]; then
  block=/dev/block/platform/*/*/by-name/boot;
fi;

# force expansion of the path so we can use it
block=`echo -n $block`;
# enables detection of the suffix for the active boot partition on slot-based devices
is_slot_device=0;


## AnyKernel methods (DO NOT CHANGE)
# import patching functions/variables - see for reference
. /tmp/anykernel/tools/ak2-core.sh;


## AnyKernel file attributes
# set permissions/ownership for included ramdisk files
chmod -R 750 $ramdisk/*;
chown -R root:root $ramdisk/*;


## AnyKernel install
dump_boot;

# begin ramdisk changes

ui_print "Patching init files..."
# remove old broken init.d
remove_section_mod() {
  sed -i "/${2//\//\\/}/,/^$/d" $1;
}

for FILE in init*.rc; do
  backup_file $FILE
  remove_section_mod $FILE "# Run sysinit"
  remove_line $FILE "start sysinit"
  remove_section_mod $FILE "# sysinit"
  remove_section_mod $FILE "service sysinit"
  remove_section_mod $FILE "# init.d"
  remove_section_mod $FILE "service userinit"
done
rm -f /system/xbin/sysinit
rm -f /system/bin/sysinit
# add new init.d
append_file init.rc "# init.d" init
cp -f $patch/sysinit sbin/sysinit
chmod 0755 sbin/sysinit

grep_prop() {
  REGEX="s/^$1=//p"
  shift
  FILES=$@
  [ -z "$FILES" ] && FILES='/system/build.prop'
  sed -n "$REGEX" $FILES 2>/dev/null | head -n 1
}

ABILONG=`grep_prop ro.product.cpu.abi`

case $ABILONG in
  arm64*) SEINJECT=/tmp/anykernel/tools/setools-android/arm64-v8a/sepolicy-inject;;
  armeabi-v7a*) SEINJECT=/tmp/anykernel/tools/setools-android/armeabi-v7a/sepolicy-inject;;
  arm*) SEINJECT=/tmp/anykernel/tools/setools-android/armeabi/sepolicy-inject;;
  x86_64*) SEINJECT=/tmp/anykernel/tools/setools-android/x86_64/sepolicy-inject;;
  x86*) SEINJECT=/tmp/anykernel/tools/setools-android/x86/sepolicy-inject;;
  mips64*) SEINJECT=/tmp/anykernel/tools/setools-android/mips64/sepolicy-inject;;
  mips*) SEINJECT=/tmp/anykernel/tools/setools-android/mips/sepolicy-inject;;
  *) ui_print "   ! CPU Type not supported for sepolicy patching! Will set to permissive!";;
esac

ui_print "Injecting sepolicy with init.d-related permissions..."
backup_file sepolicy;
$SEINJECT -z sysinit -P sepolicy
$SEINJECT -Z sysinit -P sepolicy
$SEINJECT -s init -t sysinit -c process -p transition -P sepolicy
$SEINJECT -s init -t sysinit -c process -p rlimitinh -P sepolicy
$SEINJECT -s init -t sysinit -c process -p siginh -P sepolicy
$SEINJECT -s init -t sysinit -c process -p noatsecure -P sepolicy
$SEINJECT -s sysinit -t sysinit -c dir -p search,read -P sepolicy
$SEINJECT -s sysinit -t sysinit -c file -p read,write,open -P sepolicy
$SEINJECT -s sysinit -t sysinit -c unix_dgram_socket -p create,connect,write,setopt -P sepolicy
$SEINJECT -s sysinit -t sysinit -c lnk_file -p read -P sepolicy
$SEINJECT -s sysinit -t sysinit -c process -p fork,sigchld -P sepolicy
$SEINJECT -s sysinit -t sysinit -c capability -p dac_override -P sepolicy
$SEINJECT -s sysinit -t system_file -c file -p entrypoint,execute_no_trans -P sepolicy
$SEINJECT -s sysinit -t devpts -c chr_file -p read,write,open,getattr,ioctl -P sepolicy
$SEINJECT -s sysinit -t rootfs -c file -p execute,read,open,execute_no_trans,getattr -P sepolicy
$SEINJECT -s sysinit -t shell_exec -c file -p execute,read,open,execute_no_trans,getattr -P sepolicy
$SEINJECT -s sysinit -t zygote_exec -c file -p execute,read,open,execute_no_trans,getattr -P sepolicy
$SEINJECT -s sysinit -t toolbox_exec -c file -p getattr,open,read,ioctl,lock,getattr,execute,execute_no_trans,entrypoint -P sepolicy

# Uninstall
# remove_line init.rc "import /init.aml.rc"
# rm -f init.aml.rc

# end ramdisk changes

write_boot;

## end install

