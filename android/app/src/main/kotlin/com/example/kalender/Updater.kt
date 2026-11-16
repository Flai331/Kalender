package com.example.kalender

import android.app.Activity
import android.content.ActivityNotFoundException
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.provider.Settings
import androidx.core.content.FileProvider
import androidx.core.content.pm.PackageInfoCompat
import java.io.File

// Selbst-Update der App, nach dem Muster aus RHS Einsatz (suchgebiet_karten).
//
// Unterschied: dort läuft alles native und meldet an eine WebView. Hier liegt
// der Download in Dart (Fortschritt lässt sich dort leichter anzeigen), und
// native bleibt nur, was native sein MUSS:
//   - der tatsächlich installierte versionCode
//   - die Prüfung der geladenen Datei vor dem Installieren
//   - der Installer-Aufruf über FileProvider
//
// Android zeigt zum Schluss immer sein eigenes "Aktualisieren?"-Fenster. Eine
// App ohne Systemrechte kann sich nicht still selbst installieren.
object Updater {

    /// Der versionCode der laufenden Installation.
    fun versionCode(context: Context): Long {
        val pm = context.packageManager
        val info = pm.getPackageInfo(context.packageName, 0)
        return PackageInfoCompat.getLongVersionCode(info)
    }

    fun versionName(context: Context): String =
        context.packageManager.getPackageInfo(context.packageName, 0).versionName ?: ""

    /// Darf die App Pakete installieren? Vor Android 8 gilt eine globale
    /// Einstellung, danach eine je App.
    fun canInstall(context: Context): Boolean =
        Build.VERSION.SDK_INT < Build.VERSION_CODES.O ||
            context.packageManager.canRequestPackageInstalls()

    /// Öffnet "Unbekannte Apps installieren" für diese App.
    fun openInstallSettings(activity: Activity) {
        val settings = Intent(
            Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES,
            Uri.parse("package:${activity.packageName}"),
        )
        activity.startActivity(settings)
    }

    /// Prüft die geladene Datei, bevor sie dem Installer übergeben wird:
    /// gültiges Paket, derselbe Paketname, höherer versionCode.
    ///
    /// Wirft IllegalStateException mit einem für den Nutzer lesbaren Text.
    @Suppress("DEPRECATION")
    fun verifyApk(context: Context, path: String): Map<String, Any> {
        val file = File(path)
        if (!file.exists() || file.length() == 0L) {
            throw IllegalStateException("Die geladene Datei fehlt oder ist leer")
        }
        val info = context.packageManager.getPackageArchiveInfo(path, 0)
            ?: throw IllegalStateException("Die geladene Datei ist keine gültige App")
        if (info.packageName != context.packageName) {
            throw IllegalStateException("Die geladene App passt nicht zum Kalender")
        }
        val code = PackageInfoCompat.getLongVersionCode(info)
        if (code <= versionCode(context)) {
            throw IllegalStateException(
                "Die geladene Version ist nicht neuer als die installierte",
            )
        }
        return mapOf(
            "packageName" to info.packageName,
            "versionCode" to code,
            "versionName" to (info.versionName ?: ""),
        )
    }

    /// Übergibt die Datei an den Android-Installer.
    ///
    /// Rückgabe: "installer" (Installer gestartet), "settings" (Erlaubnis
    /// fehlte, Einstellung geöffnet) oder "error".
    fun install(activity: Activity, path: String): String {
        val file = File(path)
        if (!file.exists()) return "error"
        return try {
            if (!canInstall(activity)) {
                openInstallSettings(activity)
                "settings"
            } else {
                val uri = FileProvider.getUriForFile(
                    activity,
                    "${activity.packageName}.files",
                    file,
                )
                val intent = Intent(Intent.ACTION_VIEW).apply {
                    setDataAndType(uri, "application/vnd.android.package-archive")
                    addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                    addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                }
                activity.startActivity(intent)
                "installer"
            }
        } catch (e: ActivityNotFoundException) {
            "error"
        } catch (e: Exception) {
            "error"
        }
    }
}
