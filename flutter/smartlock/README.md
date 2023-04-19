# smartlock

Interact with locks through OpenDDS.

## Build APK for Release

`flutter build apk --split-per-abi --release`

## Unusual Build Error

If you get an error similar to this:

```
No signature of method: build_eni1zyzpknxdbfks3l1oqqqsu.android() is applicable for argument types: (build_eni1zyzpknxdbfks3l1oqqqsu$_run_closure2) values: [build_eni1zyzpknxdbfks3l1oqqqsu$_run_closure2@413960d4]
```

It may mean that something has gone afoul in your `.gradle` directory.  Try running the following and then build again.

```shell
rm -rf ~/.gradle
```

Also, running `flutter clean` in the `flutter/smartlock` and `flutter/smartlock_idl_plugin` directories may help.
