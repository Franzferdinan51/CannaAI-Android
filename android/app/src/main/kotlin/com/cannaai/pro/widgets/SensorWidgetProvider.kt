package com.cannaai.pro.widgets

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.content.Intent
import android.os.Build
import android.view.View
import android.widget.RemoteViews
import com.cannaai.pro.MainActivity
import com.cannaai.pro.R
import com.cannaai.pro.services.SensorMonitoringService
import org.json.JSONObject
import kotlin.math.roundToInt

/**
 * Home screen widget for displaying real-time sensor data
 * Shows temperature, humidity, light levels, and plant health status
 */
class SensorWidgetProvider : AppWidgetProvider() {

    companion object {
        private const val ACTION_UPDATE_WIDGET = "com.cannaai.pro.UPDATE_WIDGET"
        private const val ACTION_TOGGLE_MONITORING = "com.cannaai.pro.TOGGLE_MONITORING"
        private const val ACTION_REFRESH_DATA = "com.cannaai.pro.REFRESH_DATA"
    }

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray
    ) {
        for (appWidgetId in appWidgetIds) {
            updateAppWidget(context, appWidgetManager, appWidgetId)
        }
    }

    override fun onEnabled(context: Context) {
        // Start service if widget is added
        val intent = Intent(context, SensorMonitoringService::class.java).apply {
            action = SensorMonitoringService.ACTION_START_MONITORING
        }
        context.startService(intent)
    }

    override fun onDisabled(context: Context) {
        // Stop service if all widgets are removed
        val intent = Intent(context, SensorMonitoringService::class.java).apply {
            action = SensorMonitoringService.ACTION_STOP_MONITORING
        }
        context.startService(intent)
    }

    override fun onReceive(context: Context, intent: Intent) {
        super.onReceive(context, intent)

        when (intent.action) {
            ACTION_UPDATE_WIDGET,
            AppWidgetManager.ACTION_APPWIDGET_UPDATE -> {
                val appWidgetManager = AppWidgetManager.getInstance(context)
                val appWidgetIds = intent.getIntArrayExtra(AppWidgetManager.EXTRA_APPWIDGET_IDS)
                appWidgetIds?.forEach { appWidgetId ->
                    updateAppWidget(context, appWidgetManager, appWidgetId)
                }
            }
            ACTION_TOGGLE_MONITORING -> {
                toggleMonitoringService(context)
            }
            ACTION_REFRESH_DATA -> {
                refreshSensorData(context)
            }
        }
    }

    private fun updateAppWidget(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetId: Int
    ) {
        val views = RemoteViews(context.packageName, R.layout.sensor_widget_layout)

        // Get latest sensor data
        val sensorData = getLatestSensorData(context)

        // Update widget with sensor data
        updateWidgetViews(views, sensorData)

        // Set up click listeners
        setupClickListeners(context, views, appWidgetId)

        // Update the widget
        appWidgetManager.updateAppWidget(appWidgetId, views)
    }

    private fun updateWidgetViews(views: RemoteViews, sensorData: JSONObject) {
        // Temperature
        if (sensorData.has("temperature")) {
            val tempObj = sensorData.getJSONObject("temperature")
            val tempC = tempObj.getDouble("celsius")
            val tempF = tempObj.getDouble("fahrenheit")

            views.setTextViewText(R.id.widget_temperature_text, "${tempC.roundToInt()}°C")
            views.setTextViewText(R.id.widget_temperature_fahrenheit_text, "${tempF.roundToInt()}°F")
            views.setViewVisibility(R.id.widget_temperature_container, View.VISIBLE)
            views.setViewVisibility(R.id.widget_temperature_placeholder, View.GONE)
        } else {
            views.setViewVisibility(R.id.widget_temperature_container, View.GONE)
            views.setViewVisibility(R.id.widget_temperature_placeholder, View.VISIBLE)
        }

        // Humidity
        if (sensorData.has("humidity")) {
            val humidityObj = sensorData.getJSONObject("humidity")
            val humidity = humidityObj.getDouble("percent")

            views.setTextViewText(R.id.widget_humidity_text, "${humidity.roundToInt()}%")
            views.setViewVisibility(R.id.widget_humidity_container, View.VISIBLE)
            views.setViewVisibility(R.id.widget_humidity_placeholder, View.GONE)
        } else {
            views.setViewVisibility(R.id.widget_humidity_container, View.GONE)
            views.setViewVisibility(R.id.widget_humidity_placeholder, View.VISIBLE)
        }

        // Light
        if (sensorData.has("light")) {
            val lightObj = sensorData.getJSONObject("light")
            val lux = lightObj.getDouble("lux")

            views.setTextViewText(R.id.widget_light_text, "${lux.roundToInt()} lux")
            views.setViewVisibility(R.id.widget_light_container, View.VISIBLE)
            views.setViewVisibility(R.id.widget_light_placeholder, View.GONE)
        } else {
            views.setViewVisibility(R.id.widget_light_container, View.GONE)
            views.setViewVisibility(R.id.widget_light_placeholder, View.VISIBLE)
        }

        // Pressure
        if (sensorData.has("pressure")) {
            val pressureObj = sensorData.getJSONObject("pressure")
            val pressure = pressureObj.getDouble("hPa")

            views.setTextViewText(R.id.widget_pressure_text, "${pressure.roundToInt()} hPa")
            views.setViewVisibility(R.id.widget_pressure_container, View.VISIBLE)
            views.setViewVisibility(R.id.widget_pressure_placeholder, View.GONE)
        } else {
            views.setViewVisibility(R.id.widget_pressure_container, View.GONE)
            views.setViewVisibility(R.id.widget_pressure_placeholder, View.VISIBLE)
        }

        // Service status
        val isMonitoring = SensorMonitoringService.isRunning
        val statusText = if (isMonitoring) "Monitoring Active" else "Monitoring Inactive"
        val statusColor = if (isMonitoring) R.color.widget_status_active else R.color.widget_status_inactive

        views.setTextViewText(R.id.widget_status_text, statusText)
        views.setTextColor(R.id.widget_status_text, context.getColor(statusColor))

        // Last update time
        val lastUpdate = if (sensorData.has("last_update")) {
            val timestamp = sensorData.getLong("last_update")
            formatTimestamp(timestamp)
        } else {
            "Never"
        }
        views.setTextViewText(R.id.widget_last_update_text, "Updated: $lastUpdate")

        // Plant health indicator
        val healthStatus = calculatePlantHealth(sensorData)
        updatePlantHealthIndicator(views, healthStatus)
    }

    private fun updatePlantHealthIndicator(views: RemoteViews, healthStatus: PlantHealthStatus) {
        views.setTextViewText(R.id.widget_plant_health_text, healthStatus.displayName)
        views.setTextColor(R.id.widget_plant_health_text, healthStatus.color)

        // Update health icon
        views.setImageViewResource(R.id.widget_plant_health_icon, healthStatus.icon)

        // Update health description
        views.setTextViewText(R.id.widget_plant_health_description, healthStatus.description)
    }

    private fun calculatePlantHealth(sensorData: JSONObject): PlantHealthStatus {
        var temperature = 22.0 // Default optimal temperature
        var humidity = 50.0 // Default optimal humidity
        var light = 500.0 // Default moderate light

        if (sensorData.has("temperature")) {
            temperature = sensorData.getJSONObject("temperature").getDouble("celsius")
        }
        if (sensorData.has("humidity")) {
            humidity = sensorData.getJSONObject("humidity").getDouble("percent")
        }
        if (sensorData.has("light")) {
            light = sensorData.getJSONObject("light").getDouble("lux")
        }

        // Calculate health score based on optimal ranges
        var healthScore = 100

        // Temperature factor (optimal: 20-25°C)
        if (temperature < 18 || temperature > 28) {
            healthScore -= 30
        } else if (temperature < 20 || temperature > 25) {
            healthScore -= 15
        }

        // Humidity factor (optimal: 40-60%)
        if (humidity < 30 || humidity > 70) {
            healthScore -= 30
        } else if (humidity < 40 || humidity > 60) {
            healthScore -= 15
        }

        // Light factor (optimal: 300-800 lux for vegetative, 500-1000 for flowering)
        if (light < 100 || light > 1500) {
            healthScore -= 30
        } else if (light < 300 || light > 1000) {
            healthScore -= 15
        }

        return when {
            healthScore >= 85 -> PlantHealthStatus.EXCELLENT
            healthScore >= 70 -> PlantHealthStatus.GOOD
            healthScore >= 50 -> PlantHealthStatus.FAIR
            healthScore >= 30 -> PlantHealthStatus.POOR
            else -> PlantHealthStatus.CRITICAL
        }
    }

    private fun setupClickListeners(context: Context, views: RemoteViews, appWidgetId: Int) {
        // Main app launch
        val mainIntent = Intent(context, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TASK
        }
        val mainPendingIntent = PendingIntent.getActivity(
            context, 0, mainIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        views.setOnClickPendingIntent(R.id.widget_main_container, mainPendingIntent)

        // Toggle monitoring button
        val toggleIntent = Intent(context, SensorWidgetProvider::class.java).apply {
            action = ACTION_TOGGLE_MONITORING
            putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, appWidgetId)
        }
        val togglePendingIntent = PendingIntent.getBroadcast(
            context, 1, toggleIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        views.setOnClickPendingIntent(R.id.widget_toggle_button, togglePendingIntent)

        // Refresh button
        val refreshIntent = Intent(context, SensorWidgetProvider::class.java).apply {
            action = ACTION_REFRESH_DATA
            putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, appWidgetId)
        }
        val refreshPendingIntent = PendingIntent.getBroadcast(
            context, 2, refreshIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        views.setOnClickPendingIntent(R.id.widget_refresh_button, refreshPendingIntent)
    }

    private fun getLatestSensorData(context: Context): JSONObject {
        // In a real implementation, this would read from a database or service
        // For now, return mock data or cached data
        return try {
            val prefs = context.getSharedPreferences("SensorWidget", Context.MODE_PRIVATE)
            val dataString = prefs.getString("latest_sensor_data", "{}")
            JSONObject(dataString)
        } catch (e: Exception) {
            JSONObject()
        }
    }

    private fun toggleMonitoringService(context: Context) {
        val intent = Intent(context, SensorMonitoringService::class.java)
        if (SensorMonitoringService.isRunning) {
            intent.action = SensorMonitoringService.ACTION_STOP_MONITORING
        } else {
            intent.action = SensorMonitoringService.ACTION_START_MONITORING
        }
        context.startService(intent)

        // Update widget after a short delay
        val updateIntent = Intent(context, SensorWidgetProvider::class.java).apply {
            action = ACTION_UPDATE_WIDGET
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            context.getMainExecutor().execute {
                Thread.sleep(1000) // Wait for service to start/stop
                context.sendBroadcast(updateIntent)
            }
        } else {
            Thread {
                Thread.sleep(1000)
                context.sendBroadcast(updateIntent)
            }.start()
        }
    }

    private fun refreshSensorData(context: Context) {
        // Request immediate data refresh from monitoring service
        val intent = Intent("com.cannaai.pro.REQUEST_SENSOR_UPDATE")
        context.sendBroadcast(intent)
    }

    private fun formatTimestamp(timestamp: Long): String {
        val now = System.currentTimeMillis()
        val diff = now - timestamp

        return when {
            diff < 60000 -> "Just now"
            diff < 3600000 -> "${diff / 60000}m ago"
            diff < 86400000 -> "${diff / 3600000}h ago"
            else -> "${diff / 86400000}d ago"
        }
    }
}

/**
 * Plant health status enumeration
 */
enum class PlantHealthStatus(
    val displayName: String,
    val description: String,
    val icon: Int,
    val color: Int
) {
    EXCELLENT(
        "Excellent",
        "All environmental factors are optimal for plant growth",
        R.drawable.ic_plant_excellent,
        R.color.health_excellent
    ),
    GOOD(
        "Good",
        "Environmental conditions are suitable for healthy growth",
        R.drawable.ic_plant_good,
        R.color.health_good
    ),
    FAIR(
        "Fair",
        "Some environmental factors need attention",
        R.drawable.ic_plant_fair,
        R.color.health_fair
    ),
    POOR(
        "Poor",
        "Multiple environmental factors are outside optimal ranges",
        R.drawable.ic_plant_poor,
        R.color.health_poor
    ),
    CRITICAL(
        "Critical",
        "Environmental conditions require immediate attention",
        R.drawable.ic_plant_critical,
        R.color.health_critical
    )
}