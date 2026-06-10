package com.getup.timer.getup

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetProvider
import android.os.SystemClock

class GetUpWidgetProvider : HomeWidgetProvider() {

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences
    ) {
        for (appWidgetId in appWidgetIds) {
            val views = RemoteViews(context.packageName, R.layout.widget_layout)

            // Setup data from SharedPreferences
            val state = widgetData.getString("widget_state", "PAUSED")
            val nextTask = widgetData.getString("widget_next_task", "")
            val targetTimeStr = widgetData.getString("widget_target_time", "0")
            val targetTime = targetTimeStr?.toLongOrNull() ?: 0L
            val isRunningStr = widgetData.getString("widget_is_running", "false")
            val isRunning = isRunningStr == "true"
            val staticTime = widgetData.getString("widget_time", "00:00")

            val progressMax = widgetData.getInt("widget_progress_max", 100)
            val progressVal = widgetData.getInt("widget_progress_val", 0)

            views.setTextViewText(R.id.widget_state, state)
            views.setTextViewText(R.id.widget_next_task, nextTask)
            
            // Set dynamic icon for Play/Pause button
            if (isRunning) {
                views.setImageViewResource(R.id.widget_btn_play_pause, R.drawable.ic_pause)
            } else {
                views.setImageViewResource(R.id.widget_btn_play_pause, R.drawable.ic_play)
            }

            // Set colors based on state
            val color = when(state) {
                "WORK" -> android.graphics.Color.parseColor("#00E676")
                "EXERCISE" -> android.graphics.Color.parseColor("#FF3D00")
                "WATER" -> android.graphics.Color.parseColor("#00B0FF")
                else -> android.graphics.Color.parseColor("#AAAAAA")
            }
            views.setTextColor(R.id.widget_state, color)

            // Button intent
            val backgroundIntent = es.antonborri.home_widget.HomeWidgetBackgroundIntent.getBroadcast(
                context, 
                android.net.Uri.parse("getupWidget://toggle")
            )
            views.setOnClickPendingIntent(R.id.widget_btn_play_pause, backgroundIntent)

            val resetIntent = es.antonborri.home_widget.HomeWidgetBackgroundIntent.getBroadcast(
                context, 
                android.net.Uri.parse("getupWidget://reset")
            )
            views.setOnClickPendingIntent(R.id.widget_btn_reset, resetIntent)

            // Set progress bar
            views.setProgressBar(R.id.widget_progress, progressMax, progressVal, false)

            // Update chronometer display
            if (isRunning && targetTime > 0L) {
                val currentTime = System.currentTimeMillis()
                val remainingMs = targetTime - currentTime
                val baseTime = SystemClock.elapsedRealtime() + remainingMs

                views.setViewVisibility(R.id.widget_time, android.view.View.VISIBLE)
                views.setViewVisibility(R.id.widget_time_static, android.view.View.GONE)
                views.setChronometer(R.id.widget_time, baseTime, "%s", true)
            } else {
                // Show static time
                views.setViewVisibility(R.id.widget_time, android.view.View.GONE)
                views.setViewVisibility(R.id.widget_time_static, android.view.View.VISIBLE)
                views.setTextViewText(R.id.widget_time_static, staticTime)
                views.setChronometer(R.id.widget_time, SystemClock.elapsedRealtime(), staticTime, false)
            }

            appWidgetManager.updateAppWidget(appWidgetId, views)
        }
    }
}
