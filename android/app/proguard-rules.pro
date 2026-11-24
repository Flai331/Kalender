# R8 im Release-Build: was hier nicht steht, darf er wegwerfen.
#
# Flutter schaltet die Verkleinerung fuer jeden Release-Build selbst ein
# (FlutterPlugin.kt: `releaseBuildType.isMinifyEnabled = true`) und haengt
# diese Datei automatisch an, sobald es sie gibt — eine Zeile in
# build.gradle.kts braucht es nicht. Im Debug laeuft R8 gar nicht. Darum
# faellt hier nichts auf, was im fertigen APK laengst kaputt ist.

# ── Gson braucht seine generischen Signaturen ───────────────────────────
#
# Das Meldungs-Plugin legt jeden gestellten Wecker als JSON ab und liest ihn
# mit
#     new TypeToken<ArrayList<NotificationDetails>>() {}.getType()
# wieder ein. R8 wirft die generische Signatur dieser anonymen Klasse weg,
# und dann wirft Gson schon beim Anlegen des TypeToken:
#     "TypeToken must be created with a type argument"
#
# Getroffen hat es genau die *geplanten* Meldungen — Serien-Erinnerungen,
# Ortsvorschlaege, die Abfahrt-Erinnerung. Sofortige (`show()`) kommen ohne
# Gson aus und liefen die ganze Zeit weiter. Genau deshalb sah es so lange
# nach einem fehlenden Recht aus: die Testmeldung kam ja.
-keepattributes Signature
-keepattributes *Annotation*
-keepattributes InnerClasses,EnclosingMethod

# Ab R8 3.0 reicht -keepattributes allein nicht mehr: TypeToken und jede
# seiner anonymen Unterklassen muessen ihre Typargumente ausdruecklich
# behalten duerfen.
-keep,allowobfuscation,allowshrinking class com.google.gson.reflect.TypeToken
-keep,allowobfuscation,allowshrinking class * extends com.google.gson.reflect.TypeToken

# Felder, die Gson ueber ihren Namen fuellt, duerfen nicht verschwinden.
-keepclassmembers,allowobfuscation class * {
  @com.google.gson.annotations.SerializedName <fields>;
}
-dontwarn sun.misc.**

# ── Die Modelle des Meldungs-Plugins ────────────────────────────────────
#
# Gson liest und schreibt sie ueber ihre Feldnamen. Umbenannte Felder heissen
# im JSON anders — und was gestern geschrieben wurde, passt dann heute nicht
# mehr. Der Empfaenger, der den Wecker abnimmt, laeuft ueber denselben Weg.
-keep class com.dexterous.** { *; }
