ui_print() { echo -e "ui_print $1\nui_print" >> /proc/self/fd/$OUTFD; }

toupper() {
  echo "$@" | tr '[:lower:]' '[:upper:]'
}

grep_cmdline() {
  local REGEX="s/^$1=//p"
  cat /proc/cmdline | tr '[:space:]' '\n' | sed -n "$REGEX" 2>/dev/null
}

grep_prop() {
  local REGEX="s/^$1=//p"
  shift
  local FILES=$@
  [ -z "$FILES" ] && FILES='/system/build.prop'
  sed -n "$REGEX" $FILES 2>/dev/null | head -n 1
}

is_mounted() {
  grep -q " `readlink -f $1` " /proc/mounts 2>/dev/null
  return $?
}

abort() {
  ui_print "$1"
  recovery_cleanup
  exit 1
}

setup_flashable() {
  OLD_PATH=$PATH
  BOOTDIR=$TMPDIR/unitytools
  chmod 755 $BOOTDIR/busybox
  $BOOTDIR/busybox --install -s $BOOTDIR
  echo $PATH | grep -q "^$BOOTDIR" || export PATH=$BOOTDIR:$PATH
}

recovery_actions() {
  # Make sure random don't get blocked
  mount -o bind /dev/urandom /dev/random
  # Unset library paths
  OLD_LD_LIB=$LD_LIBRARY_PATH
  OLD_LD_PRE=$LD_PRELOAD
  OLD_LD_CFG=$LD_CONFIG_FILE
  unset LD_LIBRARY_PATH
  unset LD_PRELOAD
  unset LD_CONFIG_FILE
  # Force our own busybox path to be in the front
  # and do not use anything in recovery's sbin
  export PATH=$BOOTDIR:/system/bin:/vendor/bin
}

recovery_cleanup() {
  [ -z $OLD_PATH ] || export PATH=$OLD_PATH
  [ -z $OLD_LD_LIB ] || export LD_LIBRARY_PATH=$OLD_LD_LIB
  [ -z $OLD_LD_PRE ] || export LD_PRELOAD=$OLD_LD_PRE
  [ -z $OLD_LD_CFG ] || export LD_CONFIG_FILE=$OLD_LD_CFG
  umount -l /dev/random 2>/dev/null
}

find_block() {
  for BLOCK in "$@"; do
    DEVICE=`find /dev/block -type l -iname $BLOCK | head -n 1` 2>/dev/null
    if [ ! -z $DEVICE ]; then
      readlink -f $DEVICE
      return 0
    fi
  done
  # Fallback by parsing sysfs uevents
  for uevent in /sys/dev/block/*/uevent; do
    local DEVNAME=`grep_prop DEVNAME $uevent`
    local PARTNAME=`grep_prop PARTNAME $uevent`
    for BLOCK in "$@"; do
      if [ "`toupper $BLOCK`" = "`toupper $PARTNAME`" ]; then
        echo /dev/block/$DEVNAME
        return 0
      fi
    done
  done
  return 1
}

cp_ch() {
  local OPT=`getopt -o inr -- "$@"` BAK=true UBAK=true REST=true BAKFILE=$INFORD FOL=false
  eval set -- "$OPT"
  while true; do
    case "$1" in
      -i) UBAK=false; REST=false; shift;;
      -n) UBAK=false; shift;;
      -r) FOL=true; shift;;
      --) shift; break;;
    esac
  done
  local SRC="$1" DEST="$2" OFILES="$1"
  $FOL && OFILES=$(find $SRC -type f 2>/dev/null)
  [ -z $3 ] && PERM=0644 || PERM=$3
  for OFILE in ${OFILES}; do
    if $FOL; then
      if [ "$(basename $SRC)" == "$(basename $DEST)" ]; then
        local FILE=$(echo $OFILE | sed "s|$SRC|$DEST|")
      else
        local FILE=$(echo $OFILE | sed "s|$SRC|$DEST/$(basename $SRC)|")
      fi
    else
      [ -d "$DEST" ] && local FILE="$DEST/$(basename $SRC)" || local FILE="$DEST"
    fi
    if $BAK; then
      if $UBAK && $REST; then
        [ ! "$(grep "$FILE$" $BAKFILE 2>/dev/null)" ] && echo "$FILE" >> $BAKFILE
        [ -f "$FILE" -a ! -f "$FILE~" ] && { cp -af $FILE $FILE~; echo "$FILE~" >> $BAKFILE; }
      elif ! $UBAK && $REST; then
        [ ! "$(grep "$FILE$" $BAKFILE 2>/dev/null)" ] && echo "$FILE" >> $BAKFILE
      elif ! $UBAK && ! $REST; then
        [ ! "$(grep "$FILE\NORESTORE$" $BAKFILE 2>/dev/null)" ] && echo "$FILE\NORESTORE" >> $BAKFILE
      fi
    fi
    install -D -m $PERM "$OFILE" "$FILE"
  done
}

mount_part() {
  local PART=$1
  local POINT=/${PART}
  [ -L $POINT ] && rm -f $POINT
  mkdir $POINT 2>/dev/null
  is_mounted $POINT && return
  ui_print "   Mounting $PART"
  mount -o rw $POINT 2>/dev/null
  if ! is_mounted $POINT; then
    local BLOCK=`find_block $PART$SLOT`
    mount -o rw $BLOCK $POINT
  fi
  is_mounted $POINT || abort "   ! Cannot mount $POINT"
}

api_level_arch_detect() {
  API=`getprop ro.build.version.sdk`
  ABI=`getprop ro.product.cpu.abi | cut -c-3`
  ABI2=`getprop ro.product.cpu.abi2 | cut -c-3`
  ABILONG=`getprop ro.product.cpu.abi`

  ARCH=arm
  ARCH32=arm
  IS64BIT=false
  if [ "$ABI" = "x86" ]; then ARCH=x86; ARCH32=x86; fi;
  if [ "$ABI2" = "x86" ]; then ARCH=x86; ARCH32=x86; fi;
  if [ "$ABILONG" = "arm64-v8a" ]; then ARCH=arm64; ARCH32=arm; IS64BIT=true; fi;
  if [ "$ABILONG" = "x86_64" ]; then ARCH=x64; ARCH32=x86; IS64BIT=true; fi;
}

if [ ! "$(getprop 2>/dev/null)" ]; then
  getprop() {
    local propval="$(grep_prop $1 /default.prop 2>/dev/null)";
    test "$propval" || local propval="$(grep_prop $1 2>/dev/null)";
    test "$propval" && echo "$propval" || echo "";
  }
elif [ ! "$(getprop ro.product.device 2>/dev/null)" -a ! "$(getprop ro.build.product 2>/dev/null)" ]; then
  getprop() {
    ($(which getprop) | grep "$1" | cut -d[ -f3 | cut -d] -f1) 2>/dev/null;
  }
fi;

while [ "$(ps | grep -E 'magisk/addon.d.sh|/addon.d/99-flashaft' | grep -v 'grep')" ]; do
  sleep 1
done
TMPDIR=/dev/unitytmp; RD=$TMPDIR/unitytools/ramdisk; OUTFD=
mkdir -p $(dirname $RD)
setup_flashable
ui_print " "
ui_print "- Unity Ramdisk Addon Restore"
recovery_actions
api_level_arch_detect
COUNT=0
for i in $TMPDIR/*-unityak; do
  COUNT=$((COUNT + 1))
  MODID="$(echo $(basename $i) | sed "s/-unityak//")"; INFORD="$RD/$MODID-files"; RESET=false
  ui_print "   Restoring $MODID modifications..."
  for j in $(sed -n '/^# shell variables/,/^$/p' $i | sed '1d;$d'); do
    j=$(echo $j | sed "s|^#||")
    j1=$(echo $j | sed "s|=.*||")
    j2=$(echo $j | sed "s|.*=||")
    if [ -z $j1 ]; then
      eval $j
    elif [ "$(eval echo \$$j1)" != "$j2" ]; then
      RESET=true
    fi
  done
  
  [ $COUNT -eq 1 ] && { . $TMPDIR/ak3-core; dump_boot; }
  $RESET && { write_boot; reset_ak; dump_boot; }
  
  echo "#$MODID-UnityIndicator" >> $RD/init.rc
  [ -d $TMPDIR/$MODID-unityakfiles ] && { mkdir $home/rdtmp; cp -af $TMPDIR/$MODID-unityakfiles/* $home/rdtmp; }
  . $i
  [ ! -s $INFORD ] && rm -f $INFORD
done
write_boot
recovery_cleanup
rm -rf $TMPDIR
ui_print "   Done!"
exit 0
