# F2: Android Homescreen Widget

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Android homescreen widget showing today's scheduled todos by category. Todos can be checked off without opening the app. "+" opens the app on the new-todo screen.

**Architecture:** `home_widget` Flutter package for cross-platform widget data sharing. Android widget built with Jetpack Glance (Kotlin). Flutter side writes todo data to SharedPreferences via `home_widget`, Kotlin side reads and renders. Checkbox tap sends callback to Flutter via `home_widget` interactivity.

**Tech Stack:** Flutter, `home_widget` ^0.6.0, Jetpack Glance (Android), Kotlin, Supabase (existing)

---

## Files

- Modify: `pubspec.yaml` — add home_widget dependency
- Modify: `lib/services/widget_service.dart` — rewrite to use home_widget
- Modify: `lib/week/week_screen.dart` — call WidgetService.update() when todos change
- Create: `android/app/src/main/kotlin/com/example/kalender/TodoWidgetReceiver.kt`
- Create: `android/app/src/main/kotlin/com/example/kalender/TodoWidget.kt`
- Create: `android/app/src/main/res/xml/todo_widget_info.xml`
- Modify: `android/app/src/main/AndroidManifest.xml` — register widget

---

## Task 1: Add home_widget dependency

**Files:**
- Modify: `pubspec.yaml`

- [ ] **Step 1: Add dependency**

In `pubspec.yaml` under `dependencies:`:
```yaml
home_widget: ^0.6.0
```

- [ ] **Step 2: Install**

```
flutter pub get
```

- [ ] **Step 3: Commit**

```
git add pubspec.yaml pubspec.lock
git commit -m "feat: add home_widget dependency"
```

---

## Task 2: Flutter WidgetService rewrite

**Files:**
- Modify: `lib/services/widget_service.dart`

- [ ] **Step 1: Rewrite WidgetService**

```dart
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:home_widget/home_widget.dart';
import '../models/todo.dart';

class WidgetService {
  static const _appGroupId = 'group.com.example.kalender';
  static const _iOSWidgetName = 'TodoWidget'; // unused on Android but required
  static const _androidWidgetName = 'TodoWidgetReceiver';

  static Future<void> init() async {
    await HomeWidget.setAppGroupId(_appGroupId);
  }

  /// Writes today's todos to shared storage and triggers widget redraw.
  static Future<void> update({required List<Todo> todayTodos}) async {
    if (kIsWeb) return;

    // Group by category, only scheduled + not completed
    final grouped = <String, List<Map<String, dynamic>>>{};
    for (final t in todayTodos) {
      if (t.isCompleted) continue;
      grouped.putIfAbsent(t.category, () => []).add({
        'id': t.id,
        'title': t.title,
        'isDone': t.status == TodoStatus.done,
        'estimatedMinutes': t.estimatedMinutes,
      });
    }

    await HomeWidget.saveWidgetData('todos_json', jsonEncode(grouped));
    await HomeWidget.updateWidget(
      androidName: _androidWidgetName,
      iOSName: _iOSWidgetName,
    );
  }

  /// Called when user taps a checkbox on the widget.
  /// Registered in main.dart via HomeWidget.widgetClicked.
  static Future<String?> getClickedTodoId() async {
    final uri = await HomeWidget.initiallyLaunchedFromHomeWidget();
    return uri?.queryParameters['todoId'];
  }
}
```

- [ ] **Step 2: Run analyzer**

```
flutter analyze lib/services/widget_service.dart
```
Expected: no issues.

- [ ] **Step 3: Commit**

```
git add lib/services/widget_service.dart
git commit -m "feat: rewrite WidgetService to use home_widget package"
```

---

## Task 3: Android Glance widget

**Files:**
- Create: `android/app/src/main/kotlin/com/example/kalender/TodoWidget.kt`
- Create: `android/app/src/main/kotlin/com/example/kalender/TodoWidgetReceiver.kt`
- Create: `android/app/src/main/res/xml/todo_widget_info.xml`

- [ ] **Step 1: Create widget info XML**

`android/app/src/main/res/xml/todo_widget_info.xml`:
```xml
<?xml version="1.0" encoding="utf-8"?>
<appwidget-provider xmlns:android="http://schemas.android.com/apk/res/android"
    android:minWidth="250dp"
    android:minHeight="150dp"
    android:targetCellWidth="3"
    android:targetCellHeight="2"
    android:updatePeriodMillis="1800000"
    android:description="@string/app_name"
    android:previewImage="@mipmap/ic_launcher"
    android:widgetCategory="home_screen"
    android:widgetFeatures="reconfigurable" />
```

- [ ] **Step 2: Create TodoWidgetReceiver**

`android/app/src/main/kotlin/com/example/kalender/TodoWidgetReceiver.kt`:
```kotlin
package com.example.kalender

import androidx.glance.appwidget.GlanceAppWidget
import androidx.glance.appwidget.GlanceAppWidgetReceiver

class TodoWidgetReceiver : GlanceAppWidgetReceiver() {
    override val glanceAppWidget: GlanceAppWidget = TodoWidget()
}
```

- [ ] **Step 3: Create TodoWidget using Glance**

`android/app/src/main/kotlin/com/example/kalender/TodoWidget.kt`:
```kotlin
package com.example.kalender

import android.content.Context
import android.content.Intent
import android.net.Uri
import androidx.compose.runtime.Composable
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.glance.*
import androidx.glance.action.ActionParameters
import androidx.glance.action.clickable
import androidx.glance.appwidget.GlanceAppWidget
import androidx.glance.appwidget.action.ActionCallback
import androidx.glance.appwidget.action.actionRunCallback
import androidx.glance.appwidget.provideContent
import androidx.glance.layout.*
import androidx.glance.text.*
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
        val obj = JSONObject(json)
        obj.keys().forEach { category ->
            val arr = obj.getJSONArray(category)
            val items = mutableListOf<TodoItem>()
            for (i in 0 until arr.length()) {
                val t = arr.getJSONObject(i)
                items.add(TodoItem(
                    id = t.getString("id"),
                    title = t.getString("title"),
                    isDone = t.getBoolean("isDone"),
                    estimatedMinutes = t.getInt("estimatedMinutes"),
                ))
            }
            result[category] = items
        }
        return result
    }
}

data class TodoItem(val id: String, val title: String, val isDone: Boolean, val estimatedMinutes: Int)

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
            style = TextStyle(color = ColorProvider(Color.White), fontSize = 14.sp, fontWeight = FontWeight.Bold),
        )
        Spacer(modifier = GlanceModifier.height(8.dp))
        if (grouped.isEmpty()) {
            Text("Keine Todos heute", style = TextStyle(color = ColorProvider(Color(0xFF888888)), fontSize = 12.sp))
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
                        Image(
                            provider = ImageProvider(
                                if (todo.isDone) android.R.drawable.checkbox_on_background
                                else android.R.drawable.checkbox_off_background
                            ),
                            contentDescription = null,
                            modifier = GlanceModifier.size(20.dp).clickable(
                                actionRunCallback<ToggleTodoAction>(
                                    parameters = actionParametersOf(todoIdKey to todo.id)
                                )
                            )
                        )
                        Spacer(modifier = GlanceModifier.width(6.dp))
                        Text(
                            text = todo.title,
                            style = TextStyle(
                                color = ColorProvider(if (todo.isDone) Color(0xFF888888) else Color.White),
                                fontSize = 13.sp,
                            ),
                            maxLines = 1,
                        )
                    }
                }
                Spacer(modifier = GlanceModifier.height(4.dp))
            }
        }
        Spacer(modifier = GlanceModifier.defaultWeight())
        // "+" button opens app
        Text(
            text = "+ Todo hinzufügen",
            style = TextStyle(color = ColorProvider(Color(0xFF7C6AF7)), fontSize = 12.sp),
            modifier = GlanceModifier.clickable(
                androidx.glance.appwidget.action.actionStartActivity(
                    Intent(context, MainActivity::class.java).apply {
                        action = Intent.ACTION_VIEW
                        data = Uri.parse("kalender://new-todo")
                        flags = Intent.FLAG_ACTIVITY_NEW_TASK
                    }
                )
            )
        )
    }
}

val todoIdKey = ActionParameters.Key<String>("todoId")

class ToggleTodoAction : ActionCallback {
    override suspend fun onAction(context: Context, glanceId: GlanceId, parameters: ActionParameters) {
        val todoId = parameters[todoIdKey] ?: return
        // Launch app with deep link to toggle todo
        val intent = Intent(context, MainActivity::class.java).apply {
            action = Intent.ACTION_VIEW
            data = Uri.parse("kalender://toggle-todo?todoId=$todoId")
            flags = Intent.FLAG_ACTIVITY_NEW_TASK
        }
        context.startActivity(intent)
    }
}
```

- [ ] **Step 4: Commit**

```
git add android/app/src/main/kotlin/com/example/kalender/TodoWidget.kt
git add android/app/src/main/kotlin/com/example/kalender/TodoWidgetReceiver.kt
git add android/app/src/main/res/xml/todo_widget_info.xml
git commit -m "feat: add Glance Android homescreen widget"
```

---

## Task 4: Register widget in AndroidManifest + handle deep links

**Files:**
- Modify: `android/app/src/main/AndroidManifest.xml`
- Modify: `lib/main.dart`

- [ ] **Step 0: Call WidgetService.init() in main()**

In `lib/main.dart`, after `WidgetsFlutterBinding.ensureInitialized()`:
```dart
await WidgetService.init();
```
Add import: `import 'services/widget_service.dart';`

Check `home_widget` latest version on pub.dev before adding to pubspec — use the current stable version (≥0.5.0).

- [ ] **Step 1: Add receiver to AndroidManifest**

Inside `<application>` tag:
```xml
<receiver
    android:name=".TodoWidgetReceiver"
    android:exported="true">
    <intent-filter>
        <action android:name="android.appwidget.action.APPWIDGET_UPDATE" />
    </intent-filter>
    <meta-data
        android:name="android.appwidget.provider"
        android:resource="@xml/todo_widget_info" />
</receiver>
```

- [ ] **Step 2: Add deep link intent-filter to MainActivity**

In the `<activity android:name=".MainActivity">` block:
```xml
<intent-filter>
    <action android:name="android.intent.action.VIEW" />
    <category android:name="android.intent.category.DEFAULT" />
    <data android:scheme="kalender" />
</intent-filter>
```

- [ ] **Step 3: Handle deep links in main.dart**

In `initState` of main widget (or root navigator), add:
```dart
HomeWidget.widgetClicked.listen((uri) {
  if (uri == null) return;
  if (uri.host == 'toggle-todo') {
    final todoId = uri.queryParameters['todoId'];
    if (todoId != null) _handleWidgetToggle(todoId);
  } else if (uri.host == 'new-todo') {
    Navigator.push(context, MaterialPageRoute(builder: (_) => const TodoEditScreen()));
  }
});
```

`_handleWidgetToggle(String id)`: fetch todo by id, toggle status pending↔done, save, call `WidgetService.update()`.

- [ ] **Step 4: Trigger WidgetService.update() when week stream emits**

In `week_screen.dart` where `_todosStream` emits, call:
```dart
WidgetService.update(todayTodos: todayScheduledTodos);
```

- [ ] **Step 5: Run analyzer**

```
flutter analyze lib/
```
Expected: no issues.

- [ ] **Step 6: Commit**

```
git add android/app/src/main/AndroidManifest.xml lib/main.dart lib/week/week_screen.dart
git commit -m "feat: register widget in manifest and handle deep link callbacks"
```
