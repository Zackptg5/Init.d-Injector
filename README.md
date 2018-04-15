# Init.d Injector
Injects init.d support:
Into rom if using magisk or supersu without modifying boot img.
Into boot.img if rootless or using other root solution (since they don't support boot scripts) using modified Archidroid method by JustArchi @xda-developers and setools by Xmikos (https://github.com/xmikos/setools-android)
Built with Unity installer by Zackptg5 (https://github.com/Zackptg5/Unity) and AnyKernel2 by Osm0sis (https://github.com/osm0sis/AnyKernel2/)
[More details in support thread](https://forum.xda-developers.com/android/software-hacking/mod-universal-init-d-injector-wip-t3692105).

## Change Log
### v1.2 - 4.xx.2018
* Unity v1.5.2 update

### v1.1 - 3.17.2018
* Run all scripts except live boot as late start in magisk due to magisk mount occuring after post-fs-data script

### v1.0 - 3.16.2018
* Initial rerelease

## Source Code
* Module [GitHub](https://github.com/Zackptg5/Init.d-Injector)
