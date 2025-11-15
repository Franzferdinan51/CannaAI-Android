package com.cannaai.pro.services

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.hardware.Sensor
import android.hardware.SensorEvent
import android.hardware.SensorEventListener
import android.hardware.SensorManager
import android.os.Build
import android.os.IBinder
import android.os.PowerManager
import androidx.core.app.NotificationCompat
import com.cannaai.pro.MainActivity
import com.cannaai.pro.R
import io.flutter.plugin.common.MethodChannel
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.dart.DartExecutor
import org.json.JSONObject
import java.util.concurrent.Executors
import java.util.concurrent.ScheduledExecutorService
import java.util.concurrent.TimeUnit

/**
 * Foreground service for continuous sensor monitoring
 * Runs independently of the main app and provides real-time sensor data
 */
class SensorMonitoringService : Service(), SensorEventListener {

    companion object {
        private const val TAG = "SensorMonitoringService"
        private const val NOTIFICATION_ID = 1001
        private const val NOTIFICATION_CHANNEL_ID = "sensor_monitoring_channel"
        private const val NOTIFICATION_CHANNEL_NAME = "Sensor Monitoring"
        private const val NOTIFICATION_CHANNEL_DESCRIPTION = "Continuous environmental monitoring service"

        // Actions
        const val ACTION_START_MONITORING = "com.cannaai.pro.START_MONITORING"
        const val ACTION_STOP_MONITORING = "com.cannaai.pro.STOP_MONITORING"
        const val ACTION_UPDATE_SETTINGS = "com.cannaai.pro.UPDATE_SETTINGS"

        // Service state
        var isRunning = false
        private set

        // Wake lock for reliable sensor monitoring
        private var wakeLock: PowerManager.WakeLock? = null

        // Sensor data cache
        private var latestSensorData = JSONObject()
    }

    private lateinit var notificationManager: NotificationManager
    private lateinit var sensorManager: SensorManager
    private lateinit var powerManager: PowerManager

    // Sensors
    private var lightSensor: Sensor? = null
    private var temperatureSensor: Sensor? = null
    private var humiditySensor: Sensor? = null
    private var pressureSensor: Sensor? = null
    private var accelerometerSensor: Sensor? = null

    // Flutter engine for communication
    private var flutterEngine: FlutterEngine? = null
    private var methodChannel: MethodChannel? = null

    // Scheduled executor for periodic tasks
    private var scheduledExecutor: ScheduledExecutorService? = null

    // Service configuration
    private var monitoringInterval = 5000L // 5 seconds default
    private var enableWakeLock = true
    private var enableBluetoothScanning = false

    override fun onCreate() {
        super.onCreate()

        initializeServices()
        createNotificationChannel()
        setupFlutterEngine()
        discoverSensors()

        isRunning = true
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            ACTION_START_MONITORING -> startMonitoring(intent)
            ACTION_STOP_MONITORING -> stopMonitoring()
            ACTION_UPDATE_SETTINGS -> updateSettings(intent)
            else -> startForegroundWithNotification()
        }

        return START_STICKY // Service will be restarted if killed
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onDestroy() {
        super.onDestroy()

        isRunning = false
        stopSensorListening()
        releaseWakeLock()
        shutdownFlutterEngine()
        scheduledExecutor?.shutdown()

        // Send final status update
        broadcastServiceStatus("stopped")
    }

    private fun initializeServices() {
        notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        sensorManager = getSystemService(Context.SENSOR_SERVICE) as SensorManager
        powerManager = getSystemService(Context.POWER_SERVICE) as PowerManager
        scheduledExecutor = Executors.newScheduledThreadPool(2)
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                NOTIFICATION_CHANNEL_ID,
                NOTIFICATION_CHANNEL_NAME,
                NotificationManager.IMPORTANCE_LOW
            ).apply {
                description = NOTIFICATION_CHANNEL_DESCRIPTION
                setShowBadge(false)
                enableVibration(false)
                setSound(null, null)
            }
            notificationManager.createNotificationChannel(channel)
        }
    }

    private fun startForegroundWithNotification() {
        val notification = createMonitoringNotification()

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            startForeground(
                NOTIFICATION_ID,
                notification,
                ServiceInfo.FOREGROUND_SERVICE_TYPE_DATA_SYNC or ServiceInfo.FOREGROUND_SERVICE_TYPE_LOCATION
            )
        } else {
            startForeground(NOTIFICATION_ID, notification)
        }
    }

    private fun createMonitoringNotification(): Notification {
        val intent = Intent(this, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TASK
        }

        val pendingIntent = PendingIntent.getActivity(
            this, 0, intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        return NotificationCompat.Builder(this, NOTIFICATION_CHANNEL_ID)
            .setContentTitle("CannaAI Monitoring")
            .setContentText("Environmental monitoring active")
            .setSmallIcon(R.drawable.ic_notification_icon)
            .setContentIntent(pendingIntent)
            .setOngoing(true)
            .setSilent(true)
            .setCategory(NotificationCompat.CATEGORY_SERVICE)
            .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
            .build()
    }

    private fun setupFlutterEngine() {
        flutterEngine = FlutterEngine(this)
        flutterEngine?.dartExecutor?.executeDartEntrypoint(
            DartExecutor.DartEntrypoint.createDefault()
        )

        methodChannel = MethodChannel(
            flutterEngine?.dartExecutor?.binaryMessenger!!,
            "com.cannaai.pro/sensor_service"
        )

        // Handle method calls from Flutter
        methodChannel?.setMethodCallHandler { call, result ->
            when (call.method) {
                "getLatestSensorData" -> result.success(latestSensorData.toString())
                "isMonitoring" -> result.success(isRunning)
                "getSensorStatus" -> result.success(getSensorStatus())
                else -> result.notImplemented()
            }
        }
    }

    private fun discoverSensors() {
        // Find available sensors
        lightSensor = sensorManager.getDefaultSensor(Sensor.TYPE_LIGHT)
        temperatureSensor = sensorManager.getDefaultSensor(Sensor.TYPE_AMBIENT_TEMPERATURE)
        humiditySensor = sensorManager.getDefaultSensor(Sensor.TYPE_RELATIVE_HUMIDITY)
        pressureSensor = sensorManager.getDefaultSensor(Sensor.TYPE_PRESSURE)
        accelerometerSensor = sensorManager.getDefaultSensor(Sensor.TYPE_ACCELEROMETER)

        val availableSensors = mutableListOf<String>()
        lightSensor?.let { availableSensors.add("light") }
        temperatureSensor?.let { availableSensors.add("temperature") }
        humiditySensor?.let { availableSensors.add("humidity") }
        pressureSensor?.let { availableSensors.add("pressure") }
        accelerometerSensor?.let { availableSensors.add("accelerometer") }

        // Update sensor data with discovery info
        latestSensorData.put("available_sensors", availableSensors)
        latestSensorData.put("sensor_discovery_time", System.currentTimeMillis())
    }

    private fun startMonitoring(intent: Intent) {
        monitoringInterval = intent.getLongExtra("interval", 5000L)
        enableWakeLock = intent.getBooleanExtra("enableWakeLock", true)
        enableBluetoothScanning = intent.getBooleanExtra("enableBluetooth", false)

        if (enableWakeLock) {
            acquireWakeLock()
        }

        startSensorListening()
        startPeriodicTasks()
        startForegroundWithNotification()

        broadcastServiceStatus("started")
    }

    private fun stopMonitoring() {
        stopSensorListening()
        scheduledExecutor?.shutdownNow()
        releaseWakeLock()

        stopForeground(STOP_FOREGROUND_REMOVE)
        stopSelf()

        broadcastServiceStatus("stopped")
    }

    private fun startSensorListening() {
        val delay = SensorManager.SENSOR_DELAY_NORMAL

        lightSensor?.let { sensorManager.registerListener(this, it, delay) }
        temperatureSensor?.let { sensorManager.registerListener(this, it, delay) }
        humiditySensor?.let { sensorManager.registerListener(this, it, delay) }
        pressureSensor?.let { sensorManager.registerListener(this, it, delay) }
        accelerometerSensor?.let { sensorManager.registerListener(this, it, delay) }
    }

    private fun stopSensorListening() {
        sensorManager.unregisterListener(this)
    }

    private fun startPeriodicTasks() {
        // Periodic data aggregation and storage
        scheduledExecutor?.scheduleWithFixedDelay({
            aggregateAndStoreSensorData()
        }, 1, 1, TimeUnit.MINUTES)

        // Periodic status update
        scheduledExecutor?.scheduleWithFixedDelay({
            updateNotification()
            broadcastSensorData()
        }, 30, 30, TimeUnit.SECONDS)

        // Periodic health check
        scheduledExecutor?.scheduleWithFixedDelay({
            performHealthCheck()
        }, 5, 5, TimeUnit.MINUTES)
    }

    override fun onSensorChanged(event: SensorEvent?) {
        event?.let { sensorEvent ->
            val timestamp = System.currentTimeMillis()

            when (sensorEvent.sensor.type) {
                Sensor.TYPE_LIGHT -> {
                    latestSensorData.put("light", mapOf(
                        "lux" to sensorEvent.values[0],
                        "timestamp" to timestamp,
                        "accuracy" to sensorEvent.accuracy
                    ))
                }
                Sensor.TYPE_AMBIENT_TEMPERATURE -> {
                    latestSensorData.put("temperature", mapOf(
                        "celsius" to sensorEvent.values[0],
                        "fahrenheit" to (sensorEvent.values[0] * 9/5 + 32),
                        "timestamp" to timestamp,
                        "accuracy" to sensorEvent.accuracy
                    ))
                }
                Sensor.TYPE_RELATIVE_HUMIDITY -> {
                    latestSensorData.put("humidity", mapOf(
                        "percent" to sensorEvent.values[0],
                        "timestamp" to timestamp,
                        "accuracy" to sensorEvent.accuracy
                    ))
                }
                Sensor.TYPE_PRESSURE -> {
                    latestSensorData.put("pressure", mapOf(
                        "hPa" to sensorEvent.values[0],
                        "inHg" to (sensorEvent.values[0] * 0.02953),
                        "timestamp" to timestamp,
                        "accuracy" to sensorEvent.accuracy
                    ))
                }
                Sensor.TYPE_ACCELEROMETER -> {
                    val magnitude = Math.sqrt(
                        sensorEvent.values[0].toDouble().pow(2) +
                        sensorEvent.values[1].toDouble().pow(2) +
                        sensorEvent.values[2].toDouble().pow(2)
                    )
                    latestSensorData.put("accelerometer", mapOf(
                        "x" to sensorEvent.values[0],
                        "y" to sensorEvent.values[1],
                        "z" to sensorEvent.values[2],
                        "magnitude" to magnitude,
                        "timestamp" to timestamp,
                        "accuracy" to sensorEvent.accuracy
                    ))
                }
            }

            // Notify Flutter about sensor data update
            methodChannel?.invokeMethod("onSensorDataUpdate", latestSensorData.toString())
        }
    }

    override fun onAccuracyChanged(sensor: Sensor?, accuracy: Int) {
        // Handle sensor accuracy changes
        sensor?.let {
            latestSensorData.put("${it.name}_accuracy", accuracy)
        }
    }

    private fun acquireWakeLock() {
        if (wakeLock == null || !wakeLock!!.isHeld) {
            wakeLock = powerManager.newWakeLock(
                PowerManager.PARTIAL_WAKE_LOCK,
                "CannaAI:SensorMonitoringWakeLock"
            ).apply {
                acquire(10 * 60 * 1000L) // 10 minutes timeout
            }
        }
    }

    private fun releaseWakeLock() {
        wakeLock?.let {
            if (it.isHeld) {
                it.release()
            }
        }
        wakeLock = null
    }

    private fun aggregateAndStoreSensorData() {
        // Create hourly/daily aggregates
        val aggregationData = JSONObject().apply {
            put("timestamp", System.currentTimeMillis())
            put("type", "hourly_aggregate")

            // Add current sensor values
            if (latestSensorData.has("light")) {
                put("light_avg", latestSensorData.getJSONObject("light").getDouble("lux"))
            }
            if (latestSensorData.has("temperature")) {
                put("temp_avg", latestSensorData.getJSONObject("temperature").getDouble("celsius"))
            }
            if (latestSensorData.has("humidity")) {
                put("humidity_avg", latestSensorData.getJSONObject("humidity").getDouble("percent"))
            }
            if (latestSensorData.has("pressure")) {
                put("pressure_avg", latestSensorData.getJSONObject("pressure").getDouble("hPa"))
            }
        }

        // Store in local database (implementation dependent)
        // This would integrate with your local storage solution

        // Notify Flutter about aggregation
        methodChannel?.invokeMethod("onDataAggregated", aggregationData.toString())
    }

    private fun updateNotification() {
        val status = if (latestSensorData.has("temperature")) {
            val temp = latestSensorData.getJSONObject("temperature").getDouble("celsius")
            "Temperature: ${String.format("%.1f", temp)}°C"
        } else {
            "Monitoring active"
        }

        val updatedNotification = createMonitoringNotification().apply {
            // Update notification content if needed
        }

        notificationManager.notify(NOTIFICATION_ID, updatedNotification)
    }

    private fun broadcastSensorData() {
        val intent = Intent("com.cannaai.pro.SENSOR_DATA_UPDATE").apply {
            putExtra("data", latestSensorData.toString())
        }
        sendBroadcast(intent)
    }

    private fun broadcastServiceStatus(status: String) {
        val intent = Intent("com.cannaai.pro.SERVICE_STATUS_UPDATE").apply {
            putExtra("service", "SensorMonitoringService")
            putExtra("status", status)
            putExtra("timestamp", System.currentTimeMillis())
        }
        sendBroadcast(intent)
    }

    private fun getSensorStatus(): JSONObject {
        return JSONObject().apply {
            put("light", lightSensor != null)
            put("temperature", temperatureSensor != null)
            put("humidity", humiditySensor != null)
            put("pressure", pressureSensor != null)
            put("accelerometer", accelerometerSensor != null)
            put("is_listening", isRunning)
            put("wake_lock_active", wakeLock?.isHeld == true)
        }
    }

    private fun performHealthCheck() {
        // Check if service is healthy
        val isHealthy = isRunning && (
            lightSensor != null ||
            temperatureSensor != null ||
            humiditySensor != null ||
            pressureSensor != null
        )

        if (!isHealthy) {
            // Attempt recovery
            discoverSensors()
            if (isRunning) {
                startSensorListening()
            }
        }

        // Broadcast health status
        val healthData = JSONObject().apply {
            put("service", "SensorMonitoringService")
            put("healthy", isHealthy)
            put("timestamp", System.currentTimeMillis())
            put("active_sensors", getSensorStatus())
        }

        methodChannel?.invokeMethod("onHealthCheck", healthData.toString())
    }

    private fun updateSettings(intent: Intent) {
        monitoringInterval = intent.getLongExtra("interval", monitoringInterval)
        enableWakeLock = intent.getBooleanExtra("enableWakeLock", enableWakeLock)

        if (enableWakeLock && wakeLock?.isHeld != true) {
            acquireWakeLock()
        } else if (!enableWakeLock && wakeLock?.isHeld == true) {
            releaseWakeLock()
        }

        // Restart periodic tasks with new interval
        scheduledExecutor?.shutdownNow()
        scheduledExecutor = Executors.newScheduledThreadPool(2)
        if (isRunning) {
            startPeriodicTasks()
        }
    }

    private fun shutdownFlutterEngine() {
        flutterEngine?.destroy()
        flutterEngine = null
        methodChannel = null
    }
}