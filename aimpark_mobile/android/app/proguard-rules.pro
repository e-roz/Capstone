# R8 / ProGuard rules for release builds.
#
# Release is minified by R8, which fails the build outright on a reference to a
# class that is not on the classpath. Everything below names a reference that is
# genuinely unreachable at runtime, so suppressing it is the correct answer
# rather than a workaround.

# ── ML Kit text recognition ─────────────────────────────────────────────────
# ML Kit ships one artifact per script. `pubspec.yaml` depends on the Latin
# recogniser only — that is all the documents in this app are ever written in —
# but the Flutter plugin's `TextRecognizer.initialize` switches over all five
# scripts, so R8 sees hard references to four artifacts that were never
# included and refuses to finish.
#
# Pulling in the other four would put four unused models in the APK to satisfy
# a branch nothing can reach. Suppressing the warning keeps the download small
# and the behaviour identical.
-dontwarn com.google.mlkit.vision.text.chinese.**
-dontwarn com.google.mlkit.vision.text.devanagari.**
-dontwarn com.google.mlkit.vision.text.japanese.**
-dontwarn com.google.mlkit.vision.text.korean.**

# The Latin recogniser itself is loaded reflectively by ML Kit's model manager,
# so it has to survive shrinking.
-keep class com.google.mlkit.vision.text.latin.** { *; }
-keep class com.google.mlkit.vision.text.** { *; }
-keep class com.google.android.gms.internal.mlkit_vision_text_common.** { *; }
