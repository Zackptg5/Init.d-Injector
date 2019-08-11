# Patch boot img if not using root solution that supports boot scripts
if ! $MAGISK; then
  rm -f $TMPDIR/common/post-fs-data.sh $TMPDIR/common/service.sh
  cp -rf $UF/tools/* $TMPDIR/common/AnyKernel3/tools
  cp_ch -i $TMPDIR/common/AnyKernel3/META-INF/com/google/android/update-binary $TMPDIR/ak3/META-INF/com/google/android/update-binary 0755
  cd $TMPDIR/common/AnyKernel3
  zip -qr0 $TMPDIR/ak3 .
  cd /
  $TMPDIR/ak3/META-INF/com/google/android/update-binary 1 $OUTFD $TMPDIR/ak3.zip
fi
