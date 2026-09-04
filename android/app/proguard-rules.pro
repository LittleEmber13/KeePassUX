# KeepassUX release ProGuard/R8 rules.
# The 8 warnings below come from third-party libraries and are safe to suppress.
-dontwarn androidx.window.**
-dontwarn ch.qos.logback.**
-dontwarn org.tinylog.**
-dontwarn javax.naming.**
-dontwarn java.lang.management.**
-dontwarn java.lang.ProcessHandle.**
-dontwarn sun.reflect.**
-dontwarn dalvik.system.**
