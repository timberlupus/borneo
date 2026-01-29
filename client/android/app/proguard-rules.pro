# Keep OkHttp classes for UCrop (used by image_cropper)
-keep class okhttp3.** { *; }
-dontwarn okhttp3.**
-keep class com.yalantis.ucrop.** { *; }
-dontwarn com.yalantis.ucrop.**

# Keep Espressif provisioning classes for BLE provisioning
-keep class com.espressif.provisioning.** { *; }
-dontwarn com.espressif.provisioning.**

# Keep EventBus classes
-keep class org.greenrobot.eventbus.** { *; }
-dontwarn org.greenrobot.eventbus.**

# Keep Flutter plugin classes
-keep class how.virc.flutter_esp_ble_prov.** { *; }
-dontwarn how.virc.flutter_esp_ble_prov.**
