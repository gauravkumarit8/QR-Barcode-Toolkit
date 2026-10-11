# R8 full mode strips the generated Room database constructor that
# WorkManager (pulled in by the ads SDK) needs at startup, causing:
# "Failed to create an instance of androidx.work.impl.WorkDatabase"
-keep class * extends androidx.room.RoomDatabase { <init>(); }
-keep class androidx.work.impl.WorkDatabase_Impl { <init>(); }

# mobile_scanner 5.x: R8 strips/obfuscates the ML Kit barcode classes in release
# builds, so the camera shows an error icon and nothing scans (debug works).
# Same rules the package added itself in later versions (7.2.1 / 7.4.1).
-keep class com.google.mlkit.** { *; }
-keep class com.google.android.gms.internal.mlkit_vision_barcode.** { *; }
-keep class com.google.android.gms.internal.mlkit_vision_common.** { *; }
-dontwarn com.google.mlkit.**
