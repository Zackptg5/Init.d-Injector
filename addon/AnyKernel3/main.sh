chmod -R 0755 $TMPDIR/addon/AnyKernel3/tools
mv -f $TMPDIR/addon/AnyKernel3/tools/avb $TMPDIR/addon/AnyKernel3/tools/chromeos $TMPDIR/addon/AnyKernel3/tools/BootSignature_Android.jar $TMPDIR/addon/AnyKernel3/tools/futility $TMPDIR/addon/AnyKernel3/tools/$ARCH32
cp -R $TMPDIR/addon/AnyKernel3/tools $UF 2>/dev/null

ui_print " " "AnyKernel3 by osm0sis @ xda-developers" " " " ";

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

mv -f $TMPDIR/addon/AnyKernel3/uninstall.sh $TMPDIR/addon/AnyKernel3/custom_uninstall.sh
mv -f $TMPDIR/addon/AnyKernel3/scripts/* $TMPDIR/addon/AnyKernel3/
rm -f $TMPDIR/addon/AnyKernel3/ramdisk/placeholder $TMPDIR/addon/AnyKernel3/patch/placeholder

for i in $(sed -n '/^# shell variables/,/^$/p' $TMPDIR/addon/AnyKernel3/anykernel.sh | sed '1d;$d'); do
  eval $i
  sed -i "s|$i|#$i|" $TMPDIR/addon/AnyKernel3/anykernel.sh
done
[ -z $OG_AK ] && OG_AK=false
. $TMPDIR/addon/AnyKernel3/ak3-core.sh
$OG_AK && split_boot || dump_boot
