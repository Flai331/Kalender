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
    }
}
