# R8 full mode strips the generated Room database constructor that
# WorkManager (pulled in by the ads SDK) needs at startup, causing:
# "Failed to create an instance of androidx.work.impl.WorkDatabase"
-keep class * extends androidx.room.RoomDatabase { <init>(); }
-keep class androidx.work.impl.WorkDatabase_Impl { <init>(); }
