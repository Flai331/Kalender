package com.example.kalender

import android.content.Context
import android.content.Intent
import android.net.Uri
import androidx.compose.runtime.Composable
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.glance.GlanceId
import androidx.glance.GlanceModifier
import androidx.glance.action.ActionParameters
import androidx.glance.action.actionParametersOf
import androidx.glance.action.clickable
import androidx.glance.appwidget.GlanceAppWidget
import androidx.glance.appwidget.action.ActionCallback
import androidx.glance.appwidget.action.actionRunCallback
import androidx.glance.appwidget.action.actionStartActivity
import androidx.glance.appwidget.provideContent
import androidx.glance.background
import androidx.glance.layout.Alignment
import androidx.glance.layout.Column
import androidx.glance.layout.Row
import androidx.glance.layout.Spacer
import androidx.glance.layout.fillMaxSize
import androidx.glance.layout.fillMaxWidth
import androidx.glance.layout.height
import androidx.glance.layout.padding
import androidx.glance.layout.size
import androidx.glance.layout.width
import androidx.glance.layout.wrapContentSize
import androidx.glance.text.FontWeight
import androidx.glance.text.Text
import androidx.glance.text.TextStyle
import androidx.glance.unit.ColorProvider
import es.antonborri.home_widget.HomeWidgetPlugin
import org.json.JSONObject

class TodoWidget : GlanceAppWidget() {

    override suspend fun provideGlance(context: Context, id: GlanceId) {
        val prefs = HomeWidgetPlugin.getData(context)
        val todosJson = prefs.getString("todos_json", "{}") ?: "{}"
        val grouped = parseGrouped(todosJson)

        provideContent {
            WidgetContent(context, grouped)
        }
    }

    private fun parseGrouped(json: String): Map<String, List<TodoItem>> {
        val result = mutableMapOf<String, List<TodoItem>>()
        return try {
            val obj = JSONObject(json)
            obj.keys().forEach { category ->
                val arr = obj.getJSONArray(category)
                val items = mutableListOf<TodoItem>()
                for (i in 0 until arr.length()) {
                    val t = arr.getJSONObject(i)
                    items.add(
                        TodoItem(
                            id = t.getString("id"),
                            title = t.getString("title"),
                            isDone = t.getBoolean("isDone"),
                        )
                    )
                }
                result[category] = items
            }
            result
        } catch (e: Exception) {
            result
        }
    }
}

data class TodoItem(val id: String, val title: String, val isDone: Boolean)

val todoIdKey = ActionParameters.Key<String>("todoId")

@Composable
fun WidgetContent(context: Context, grouped: Map<String, List<TodoItem>>) {
    Column(
        modifier = GlanceModifier
            .fillMaxSize()
            .background(Color(0xFF1E1E2E))
            .padding(12.dp)
    ) {
        Text(
            text = "Heute",
            style = TextStyle(
                color = ColorProvider(Color.White),
                fontSize = 14.sp,
                fontWeight = FontWeight.Bold,
            ),
        )
        Spacer(modifier = GlanceModifier.height(6.dp))
        if (grouped.isEmpty()) {
            Text(
                "Keine Todos heute",
                style = TextStyle(color = ColorProvider(Color(0xFF888888)), fontSize = 12.sp),
            )
        } else {
            grouped.forEach { (category, todos) ->
                Text(
                    text = category.uppercase(),
                    style = TextStyle(color = ColorProvider(Color(0xFF888888)), fontSize = 10.sp),
                )
                todos.forEach { todo ->
                    Row(
                        modifier = GlanceModifier.fillMaxWidth().padding(vertical = 2.dp),
                        verticalAlignment = Alignment.CenterVertically,
                    ) {
                        Text(
                            text = if (todo.isDone) "✓" else "○",
                            style = TextStyle(
                                color = ColorProvider(
                                    if (todo.isDone) Color(0xFF7C6AF7) else Color(0xFF888888)
                                ),
                                fontSize = 14.sp,
                            ),
                            modifier = GlanceModifier
                                .wrapContentSize()
                                .clickable(
                                    actionRunCallback<ToggleTodoAction>(
                                        parameters = actionParametersOf(todoIdKey to todo.id)
                                    )
                                ),
                        )
                        Spacer(modifier = GlanceModifier.width(6.dp))
                        Text(
                            text = todo.title,
                            style = TextStyle(
                                color = ColorProvider(
                                    if (todo.isDone) Color(0xFF666666) else Color.White
                                ),
                                fontSize = 13.sp,
                            ),
                            maxLines = 1,
                        )
                    }
                }
                Spacer(modifier = GlanceModifier.height(4.dp))
            }
        }
        Spacer(modifier = GlanceModifier.height(8.dp))
        Text(
            text = "+ Todo hinzufügen",
            style = TextStyle(color = ColorProvider(Color(0xFF7C6AF7)), fontSize = 12.sp),
            modifier = GlanceModifier.clickable(
                actionStartActivity(
                    Intent(context, MainActivity::class.java).apply {
                        action = Intent.ACTION_VIEW
                        data = Uri.parse("kalender://new-todo")
                        flags = Intent.FLAG_ACTIVITY_NEW_TASK
                    }
                )
            ),
        )
    }
}

class ToggleTodoAction : ActionCallback {
    override suspend fun onAction(
        context: Context,
        glanceId: GlanceId,
        parameters: ActionParameters,
    ) {
        val todoId = parameters[todoIdKey] ?: return
        val intent = Intent(context, MainActivity::class.java).apply {
            action = Intent.ACTION_VIEW
            data = Uri.parse("kalender://toggle-todo?todoId=$todoId")
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP
        }
        context.startActivity(intent)
    }
}
