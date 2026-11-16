package com.example.kalender

import android.appwidget.AppWidgetManager
import android.content.ComponentName
import android.content.Context
import android.content.SharedPreferences
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    private val CHANNEL = "com.example.kalender/widget"
    private val UPDATE_CHANNEL = "com.example.kalender/updater"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "updateWidgetData" -> {
                        val todayTodos = call.argument<String>("today_todos") ?: "[]"
                        val activeTask = call.argument<String>("active_task") ?: ""
                        val activeTimer = call.argument<String>("active_timer") ?: ""

                        val prefs: SharedPreferences = getSharedPreferences(
                            "kalender_widget_data", Context.MODE_PRIVATE
                        )
                        prefs.edit()
                            .putString("today_todos", todayTodos)
                            .putString("active_task", activeTask)
                            .putString("active_timer", activeTimer)
                            .apply()

                        // Widget neu zeichnen
                        val manager = AppWidgetManager.getInstance(this)
                        val ids = manager.getAppWidgetIds(
                            ComponentName(this, KalenderWidget::class.java)
                        )
                        for (id in ids) {
                            KalenderWidget.updateWidget(this, manager, id)
                        }

                        result.success(true)
                    }
                    else -> result.notImplemented()
                }
            }

        // Selbst-Update: nur was native sein muss (installierte Version,
        // Prüfung der geladenen Datei, Installer-Aufruf). Der Download läuft
        // in Dart.
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, UPDATE_CHANNEL)
            .setMethodCallHandler { call, result ->
                try {
                    when (call.method) {
                        "versionCode" -> result.success(Updater.versionCode(this))
                        "versionName" -> result.success(Updater.versionName(this))
                        "canInstall" -> result.success(Updater.canInstall(this))
                        "openInstallSettings" -> {
                            Updater.openInstallSettings(this)
                            result.success(true)
                        }
                        "verifyApk" -> {
                            val path = call.argument<String>("path")
                            if (path == null) {
                                result.error("ARG", "path fehlt", null)
                            } else {
                                result.success(Updater.verifyApk(this, path))
                            }
                        }
                        "install" -> {
                            val path = call.argument<String>("path")
                            if (path == null) {
                                result.error("ARG", "path fehlt", null)
                            } else {
                                result.success(Updater.install(this, path))
                            }
                        }
                        else -> result.notImplemented()
                    }
                } catch (e: Exception) {
                    // Die Meldung ist für den Nutzer gedacht (siehe verifyApk).
                    result.error("UPDATER", e.message ?: "Unbekannter Fehler", null)
                }
            }
    }
}
