mkdir -p $INSTALLER/system/etc/init.d
cp -f $INSTALLER/common/ak2/patch/0000InitdinjectorTest $INSTALLER/system/etc/init.d/0000InitdinjectorTest
if $MAGISK; then
  cp -f $INSTALLER/common/unityfiles/modid.sh $INSTALLER/common/unityfiles/post-fs-data.sh
  sed -i -e "s/<MODID>/$MODID/" -e "/# CUSTOM USER SCRIPT/ r $INSTALLER/common/post-fs-data-magisk.sh" -e '/# CUSTOM USER SCRIPT/d' $INSTALLER/common/unityfiles/post-fs-data.sh
  mv -f $INSTALLER/common/unityfiles/post-fs-data.sh $INSTALLER/common/post-fs-data.sh
  LATESTARTSERVICE=true
fi
