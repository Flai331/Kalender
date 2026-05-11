package com.example.kalender

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.content.Intent
import android.widget.RemoteViews
import android.content.SharedPreferences
import org.json.JSONArray

class KalenderWidget : AppWidgetProvider() {

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray
    ) {
        for (appWidgetId in appWidgetIds) {
            updateWidget(context, appWidgetManager, appWidgetId)
        }
    }

    companion object {
        fun updateWidget(
            context: Context,
            appWidgetManager: AppWidgetManager,
            appWidgetId: Int
        ) {
            val views = RemoteViews(context.packageName, R.layout.kalender_widget)

            // Tap → App öffnen
            val intent = Intent(context, MainActivity::class.java).apply {
                putExtra("from_widget", true)
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
            }
            val pendingIntent = PendingIntent.getActivity(
                context, 0, intent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
            views.setOnClickPendingIntent(R.id.widget_container, pendingIntent)

            // Heute's Todos aus SharedPreferences lesen (werden von Flutter geschrieben)
            val prefs: SharedPreferences =
                context.getSharedPreferences("kalender_widget_data", Context.MODE_PRIVATE)

            val todayTodos = prefs.getString("today_todos", "[]") ?: "[]"
            val activeTask = prefs.getString("active_task", "") ?: ""
            val activeTimer = prefs.getString("active_timer", "") ?: ""

            // Aktiver Task anzeigen
            if (activeTask.isNotEmpty()) {
                views.setTextViewText(R.id.widget_active_task, "▶ $activeTask")
                views.setTextViewText(R.id.widget_timer, activeTimer)
            } else {
                views.setTextViewText(R.id.widget_active_task, "Kein aktiver Termin")
                views.setTextViewText(R.id.widget_timer, "")
            }

            // Todos auflisten (max. 4)
            try {
                val todos = JSONArray(todayTodos)
                val sb = StringBuilder()
                val count = minOf(todos.length(), 4)
                for (i in 0 until count) {
                    val todo = todos.getJSONObject(i)
                    val done = todo.optBoolean("done", false)
                    val title = todo.optString("title", "")
                    sb.appendLine("${if (done) "✓" else "○"} $title")
                }
                if (todos.length() > 4) sb.append("+ ${todos.length() - 4} weitere...")
                views.setTextViewText(R.id.widget_todos, sb.toString().trimEnd())
            } catch (e: Exception) {
                views.setTextViewText(R.id.widget_todos, "Heute keine Todos")
            }

            appWidgetManager.updateAppWidget(appWidgetId, views)
        }
    }
}
