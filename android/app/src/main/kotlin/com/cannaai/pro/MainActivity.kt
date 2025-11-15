package com.cannaai.pro

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import android.os.Bundle
import androidx.annotation.NonNull
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.Manifest
import android.os.Build
import android.os.VibrationEffect
import android.os.Vibrator
import android.widget.Toast
import android.net.Uri
import android.provider.Settings
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import androidx.core.app.NotificationManagerCompat
import androidx.core.content.FileProvider
import java.io.File
import java.io.FileWriter
import java.io.FileReader

class MainActivity: FlutterActivity(), MethodCallHandler {
    private val CHANNEL = "com.cannaai.pro/native"
    private val SENSOR_CHANNEL = "com.cannaai.pro/sensors"
    private val CAMERA_CHANNEL = "com.cannaai.pro/camera"
    private val BLUETOOTH_CHANNEL = "com.cannaai.pro/bluetooth"
    private val STORAGE_CHANNEL = "com.cannaai.pro/storage"
    private val NOTIFICATION_CHANNEL = "com.cannaai.pro/notifications"
    private val BATTERY_CHANNEL = "com.cannaai.pro/battery"
    private val SYSTEM_CHANNEL = "com.cannaai.pro/system"

    private lateinit var nativeChannel: MethodChannel
    private lateinit var sensorChannel: MethodChannel
    private lateinit var cameraChannel: MethodChannel
    private lateinit var bluetoothChannel: MethodChannel
    private lateinit var storageChannel: MethodChannel
    private lateinit var notificationChannel: MethodChannel
    private lateinit var batteryChannel: MethodChannel
    private lateinit var systemChannel: MethodChannel

    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // Initialize method channels
        nativeChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
        sensorChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, SENSOR_CHANNEL)
        cameraChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CAMERA_CHANNEL)
        bluetoothChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, BLUETOOTH_CHANNEL)
        storageChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, STORAGE_CHANNEL)
        notificationChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, NOTIFICATION_CHANNEL)
        batteryChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, BATTERY_CHANNEL)
        systemChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, SYSTEM_CHANNEL)

        // Set up method call handlers
        nativeChannel.setMethodCallHandler(this)
        sensorChannel.setMethodCallHandler { call, result -> handleSensorMethodCall(call, result) }
        cameraChannel.setMethodCallHandler { call, result -> handleCameraMethodCall(call, result) }
        bluetoothChannel.setMethodCallHandler { call, result -> handleBluetoothMethodCall(call, result) }
        storageChannel.setMethodCallHandler { call, result -> handleStorageMethodCall(call, result) }
        notificationChannel.setMethodCallHandler { call, result -> handleNotificationMethodCall(call, result) }
        batteryChannel.setMethodCallHandler { call, result -> handleBatteryMethodCall(call, result) }
        systemChannel.setMethodCallHandler { call, result -> handleSystemMethodCall(call, result) }
    }

    override fun onMethodCall(@NonNull call: MethodCall, @NonNull result: Result) {
        when (call.method) {
            "getPlatformVersion" -> {
                result("Android ${android.os.Build.VERSION.RELEASE}")
            }
            "getDeviceInfo" -> {
                val deviceInfo = mapOf(
                    "model" to android.os.Build.MODEL,
                    "manufacturer" to android.os.Build.MANUFACTURER,
                    "version" to android.os.Build.VERSION.RELEASE,
                    "sdk" to android.os.Build.VERSION.SDK_INT,
                    "brand" to android.os.Build.BRAND,
                    "product" to android.os.Build.PRODUCT,
                    "device" to android.os.Build.DEVICE,
                    "hardware" to android.os.Build.HARDWARE,
                    "serial" to if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                        Build.getSerial()
                    } else {
                        Build.SERIAL
                    }
                )
                result(deviceInfo)
            }
            "checkPermissions" -> {
                val permissions = checkAllPermissions()
                result(permissions)
            }
            "requestPermission" -> {
                val permission = call.argument<String>("permission")
                if (permission != null) {
                    requestPermission(permission) { granted -> result(granted) }
                } else {
                    result(false)
                }
            }
            "openAppSettings" -> {
                openAppSettings()
                result(null)
            }
            "shareText" -> {
                val text = call.argument<String>("text")
                val subject = call.argument<String>("subject")
                shareText(text, subject)
                result(null)
            }
            "shareFile" -> {
                val filePath = call.argument<String>("filePath")
                val subject = call.argument<String>("subject")
                shareFile(filePath, subject)
                result(null)
            }
            "vibrate" -> {
                val duration = call.argument<Int>("duration") ?: 500
                vibrate(duration)
                result(null)
            }
            "showToast" -> {
                val message = call.argument<String>("message")
                val duration = call.argument<Int>("duration") ?: 2
                showToast(message, duration)
                result(null)
            }
            "restartApp" -> {
                restartApp()
                result(null)
            }
            "exitApp" -> {
                finish()
                result(null)
            }
            else -> {
                result.notImplemented()
            }
        }
    }

    private fun handleSensorMethodCall(call: MethodCall, result: Result) {
        when (call.method) {
            "isSensorAvailable" -> {
                val type = call.argument<String>("type")
                result(checkSensorAvailability(type ?: ""))
            }
            "getSensorData" -> {
                val type = call.argument<String>("type")
                result(getSensorData(type ?: ""))
            }
            "startSensorListening" -> {
                val type = call.argument<String>("type")
                val interval = call.argument<Int>("interval") ?: 1000
                startSensorListening(type ?: "", interval)
                result(null)
            }
            "stopSensorListening" -> {
                val type = call.argument<String>("type")
                stopSensorListening(type ?: "")
                result(null)
            }
            else -> result.notImplemented()
        }
    }

    private fun handleCameraMethodCall(call: MethodCall, result: Result) {
        when (call.method) {
            "isCameraAvailable" -> {
                result(checkCameraAvailability())
            }
            "getCameraInfo" -> {
                result(getCameraInfo())
            }
            "captureImage" -> {
                val outputPath = call.argument<String>("outputPath")
                val quality = call.argument<Int>("quality") ?: 90
                captureImage(outputPath, quality) { path -> result(path) }
            }
            "pickImageFromGallery" -> {
                pickImageFromGallery { path -> result(path) }
            }
            else -> result.notImplemented()
        }
    }

    private fun handleBluetoothMethodCall(call: MethodCall, result: Result) {
        when (call.method) {
            "isEnabled" -> {
                result(isBluetoothEnabled())
            }
            "getDevices" -> {
                result(getBluetoothDevices())
            }
            "connect" -> {
                val deviceId = call.argument<String>("deviceId")
                if (deviceId != null) {
                    connectToBluetoothDevice(deviceId) { success -> result(success) }
                } else {
                    result(false)
                }
            }
            "disconnect" -> {
                val deviceId = call.argument<String>("deviceId")
                if (deviceId != null) {
                    disconnectFromBluetoothDevice(deviceId)
                }
                result(null)
            }
            else -> result.notImplemented()
        }
    }

    private fun handleStorageMethodCall(call: MethodCall, result: Result) {
        when (call.method) {
            "getExternalStoragePath" -> {
                result(getExternalStoragePath())
            }
            "createAppDirectory" -> {
                result(createAppDirectory())
            }
            "saveFile" -> {
                val filePath = call.argument<String>("filePath")
                val content = call.argument<String>("content")
                if (filePath != null && content != null) {
                    result(saveFile(filePath, content))
                } else {
                    result(false)
                }
            }
            "readFile" -> {
                val filePath = call.argument<String>("filePath")
                if (filePath != null) {
                    result(readFile(filePath))
                } else {
                    result(null)
                }
            }
            "deleteFile" -> {
                val filePath = call.argument<String>("filePath")
                if (filePath != null) {
                    result(deleteFile(filePath))
                } else {
                    result(false)
                }
            }
            else -> result.notImplemented()
        }
    }

    private fun handleNotificationMethodCall(call: MethodCall, result: Result) {
        when (call.method) {
            "createNotificationChannel" -> {
                val id = call.argument<String>("id")
                val name = call.argument<String>("name")
                val description = call.argument<String>("description")
                val importance = call.argument<Int>("importance") ?: 4
                if (id != null && name != null && description != null) {
                    createNotificationChannel(id, name, description, importance)
                }
                result(null)
            }
            "showNotification" -> {
                val title = call.argument<String>("title")
                val body = call.argument<String>("body")
                val channelId = call.argument<String>("channelId")
                val data = call.argument<Map<String, Any>>("data")
                if (title != null && body != null) {
                    showNotification(title, body, channelId, data)
                }
                result(null)
            }
            else -> result.notImplemented()
        }
    }

    private fun handleBatteryMethodCall(call: MethodCall, result: Result) {
        when (call.method) {
            "getBatteryInfo" -> {
                result(getBatteryInfo())
            }
            "requestBatteryOptimizationExemption" -> {
                result(requestBatteryOptimizationExemption())
            }
            else -> result.notImplemented()
        }
    }

    private fun handleSystemMethodCall(call: MethodCall, result: Result) {
        when (call.method) {
            "configureSystemUI" -> {
                val statusBarColor = call.argument<Int>("statusBarColor")
                val navigationBarColor = call.argument<Int>("navigationBarColor")
                val lightStatusBar = call.argument<Boolean>("lightStatusBar")
                val lightNavigationBar = call.argument<Boolean>("lightNavigationBar")
                val immersiveMode = call.argument<Boolean>("immersiveMode") ?: false

                configureSystemUI(statusBarColor, navigationBarColor, lightStatusBar, lightNavigationBar, immersiveMode)
                result(null)
            }
            "getScreenInfo" -> {
                result(getScreenInfo())
            }
            "setAutoRotate" -> {
                val enabled = call.argument<Boolean>("enabled") ?: false
                setAutoRotate(enabled)
                result(null)
            }
            else -> result.notImplemented()
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        // Configure themes for status/navigation bars
        window.statusBarColor = android.graphics.Color.parseColor("#16a34a")
        window.navigationBarColor = android.graphics.Color.parseColor("#16a34a")

        // Set light status bar (dark icons) for better contrast
        if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.M) {
            window.decorView.systemUiVisibility =
                window.decorView.systemUiVisibility or android.view.View.SYSTEM_UI_FLAG_LIGHT_STATUS_BAR
        }

        // Initialize native services
        initializeNativeServices()
    }

    override fun onResume() {
        super.onResume()
        // Handle app resume events
        notifyFlutterAppResumed()
    }

    override fun onPause() {
        super.onPause()
        // Handle app pause events
        notifyFlutterAppPaused()
    }

    // Implementation methods for all the handlers above
    private fun checkAllPermissions(): Map<String, Boolean> {
        return mapOf(
            "camera" to checkPermission(Manifest.permission.CAMERA),
            "storage" to checkStoragePermission(),
            "location" to checkPermission(Manifest.permission.ACCESS_FINE_LOCATION),
            "bluetooth" to checkPermission(Manifest.permission.BLUETOOTH),
            "notifications" to checkNotificationPermission(),
            "vibrate" to checkPermission(Manifest.permission.VIBRATE)
        )
    }

    private fun checkPermission(permission: String): Boolean {
        return ContextCompat.checkSelfPermission(this, permission) == PackageManager.PERMISSION_GRANTED
    }

    private fun checkStoragePermission(): Boolean {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            checkPermission(Manifest.permission.READ_MEDIA_IMAGES) &&
            checkPermission(Manifest.permission.READ_MEDIA_VIDEO) &&
            checkPermission(Manifest.permission.READ_MEDIA_AUDIO)
        } else {
            checkPermission(Manifest.permission.READ_EXTERNAL_STORAGE) &&
            checkPermission(Manifest.permission.WRITE_EXTERNAL_STORAGE)
        }
    }

    private fun checkNotificationPermission(): Boolean {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            checkPermission(Manifest.permission.POST_NOTIFICATIONS)
        } else {
            true // Notifications are granted by default on older versions
        }
    }

    private fun requestPermission(permission: String, callback: (Boolean) -> Unit) {
        val permissions = when (permission) {
            "storage" -> getStoragePermissions()
            "notifications" -> if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                arrayOf(Manifest.permission.POST_NOTIFICATIONS)
            } else { arrayOf() }
            else -> arrayOf(permission)
        }

        if (permissions.isNotEmpty()) {
            ActivityCompat.requestPermissions(this, permissions, PERMISSION_REQUEST_CODE)
            // In a real implementation, you'd handle the result in onRequestPermissionsResult
            // For now, we'll assume the permission was granted
            callback(true)
        } else {
            callback(true)
        }
    }

    private fun getStoragePermissions(): Array<String> {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            arrayOf(
                Manifest.permission.READ_MEDIA_IMAGES,
                Manifest.permission.READ_MEDIA_VIDEO,
                Manifest.permission.READ_MEDIA_AUDIO
            )
        } else {
            arrayOf(
                Manifest.permission.READ_EXTERNAL_STORAGE,
                Manifest.permission.WRITE_EXTERNAL_STORAGE
            )
        }
    }

    private fun openAppSettings() {
        val intent = Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS).apply {
            data = Uri.fromParts("package", packageName, null)
        }
        startActivity(intent)
    }

    private fun shareText(text: String?, subject: String?) {
        val intent = Intent(Intent.ACTION_SEND).apply {
            type = "text/plain"
            putExtra(Intent.EXTRA_TEXT, text)
            putExtra(Intent.EXTRA_SUBJECT, subject)
        }
        startActivity(Intent.createChooser(intent, "Share via"))
    }

    private fun shareFile(filePath: String?, subject: String?) {
        val file = File(filePath ?: return)
        val uri = FileProvider.getUriForFile(this, "$packageName.fileprovider", file)

        val intent = Intent(Intent.ACTION_SEND).apply {
            type = "image/*"
            putExtra(Intent.EXTRA_STREAM, uri)
            putExtra(Intent.EXTRA_SUBJECT, subject)
            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
        }
        startActivity(Intent.createChooser(intent, "Share via"))
    }

    private fun vibrate(duration: Int) {
        val vibrator = getSystemService(Context.VIBRATOR_SERVICE) as Vibrator
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            vibrator.vibrate(VibrationEffect.createOneShot(duration.toLong(), VibrationEffect.DEFAULT_AMPLITUDE))
        } else {
            @Suppress("DEPRECATION")
            vibrator.vibrate(duration.toLong())
        }
    }

    private fun showToast(message: String?, duration: Int) {
        val durationConstant = if (duration == 1) Toast.LENGTH_SHORT else Toast.LENGTH_LONG
        Toast.makeText(this, message, durationConstant).show()
    }

    private fun restartApp() {
        val intent = packageManager.getLaunchIntentForPackage(packageName)
        intent?.addFlags(Intent.FLAG_ACTIVITY_CLEAR_TOP)
        startActivity(intent)
        finish()
    }

    private fun initializeNativeServices() {
        // Initialize any native services here
        createNotificationChannel("default", "Default", "Default notification channel")
    }

    // Placeholder implementations for sensor, camera, bluetooth, etc.
    private fun checkSensorAvailability(type: String): Boolean {
        // Implementation would check if sensor is available
        return true
    }

    private fun getSensorData(type: String): Map<String, Any> {
        // Implementation would get actual sensor data
        return mapOf("timestamp" to System.currentTimeMillis(), "value" to 0.0)
    }

    private fun startSensorListening(type: String, interval: Int) {
        // Implementation would start listening to sensor
    }

    private fun stopSensorListening(type: String) {
        // Implementation would stop listening to sensor
    }

    private fun checkCameraAvailability(): Boolean {
        return packageManager.hasSystemFeature(PackageManager.FEATURE_CAMERA_ANY)
    }

    private fun getCameraInfo(): Map<String, Any> {
        return mapOf(
            "hasCamera" to checkCameraAvailability(),
            "hasFrontCamera" to packageManager.hasSystemFeature(PackageManager.FEATURE_CAMERA_FRONT),
            "hasFlash" to packageManager.hasSystemFeature(PackageManager.FEATURE_CAMERA_FLASH)
        )
    }

    private fun captureImage(outputPath: String?, quality: Int, callback: (String?) -> Unit) {
        // Implementation would capture image
        callback(null)
    }

    private fun pickImageFromGallery(callback: (String?) -> Unit) {
        // Implementation would pick image from gallery
        callback(null)
    }

    private fun isBluetoothEnabled(): Boolean {
        // Implementation would check Bluetooth status
        return false
    }

    private fun getBluetoothDevices(): List<Map<String, Any>> {
        // Implementation would get paired Bluetooth devices
        return emptyList()
    }

    private fun connectToBluetoothDevice(deviceId: String, callback: (Boolean) -> Unit) {
        // Implementation would connect to Bluetooth device
        callback(false)
    }

    private fun disconnectFromBluetoothDevice(deviceId: String) {
        // Implementation would disconnect from Bluetooth device
    }

    private fun getExternalStoragePath(): String? {
        return getExternalFilesDir(null)?.absolutePath
    }

    private fun createAppDirectory(): String? {
        val appDir = File(getExternalFilesDir(null), "CannaAI")
        return if (appDir.exists() || appDir.mkdirs()) {
            appDir.absolutePath
        } else {
            null
        }
    }

    private fun saveFile(filePath: String, content: String): Boolean {
        return try {
            FileWriter(filePath).use { it.write(content) }
            true
        } catch (e: Exception) {
            false
        }
    }

    private fun readFile(filePath: String): String? {
        return try {
            FileReader(filePath).use { it.readText() }
        } catch (e: Exception) {
            null
        }
    }

    private fun deleteFile(filePath: String): Boolean {
        return try {
            File(filePath).delete()
        } catch (e: Exception) {
            false
        }
    }

    private fun createNotificationChannel(id: String, name: String, description: String, importance: Int = 4) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = android.app.NotificationChannel(
                id,
                name,
                when (importance) {
                    1 -> android.app.NotificationManager.IMPORTANCE_MIN
                    2 -> android.app.NotificationManager.IMPORTANCE_LOW
                    3 -> android.app.NotificationManager.IMPORTANCE_DEFAULT
                    4 -> android.app.NotificationManager.IMPORTANCE_HIGH
                    else -> android.app.NotificationManager.IMPORTANCE_DEFAULT
                }
            ).apply {
                this.description = description
            }

            val notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as android.app.NotificationManager
            notificationManager.createNotificationChannel(channel)
        }
    }

    private fun showNotification(title: String, body: String, channelId: String?, data: Map<String, Any>?) {
        // Implementation would show notification
    }

    private fun getBatteryInfo(): Map<String, Any> {
        val batteryManager = getSystemService(Context.BATTERY_SERVICE) as android.os.BatteryManager
        return mapOf(
            "level" to batteryManager.getIntProperty(android.os.BatteryManager.BATTERY_PROPERTY_CAPACITY),
            "charging" to (batteryManager.getIntProperty(android.os.BatteryManager.BATTERY_PROPERTY_STATUS) == android.os.BatteryManager.BATTERY_STATUS_CHARGING),
            "health" to batteryManager.getIntProperty(android.os.BatteryManager.BATTERY_PROPERTY_HEALTH)
        )
    }

    private fun requestBatteryOptimizationExemption(): Boolean {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            val intent = Intent(Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS).apply {
                data = Uri.parse("package:$packageName")
            }
            startActivity(intent)
            true
        } else {
            false
        }
    }

    private fun configureSystemUI(
        statusBarColor: Int?,
        navigationBarColor: Int?,
        lightStatusBar: Boolean?,
        lightNavigationBar: Boolean?,
        immersiveMode: Boolean
    ) {
        statusBarColor?.let { window.statusBarColor = it }
        navigationBarColor?.let { window.navigationBarColor = it }

        var systemUiVisibility = window.decorView.systemUiVisibility

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M && lightStatusBar == true) {
            systemUiVisibility = systemUiVisibility or android.view.View.SYSTEM_UI_FLAG_LIGHT_STATUS_BAR
        }

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O && lightNavigationBar == true) {
            systemUiVisibility = systemUiVisibility or android.view.View.SYSTEM_UI_FLAG_LIGHT_NAVIGATION_BAR
        }

        if (immersiveMode) {
            systemUiVisibility = systemUiVisibility or
                    android.view.View.SYSTEM_UI_FLAG_HIDE_NAVIGATION or
                    android.view.View.SYSTEM_UI_FLAG_FULLSCREEN or
                    android.view.View.SYSTEM_UI_FLAG_IMMERSIVE_STICKY
        }

        window.decorView.systemUiVisibility = systemUiVisibility
    }

    private fun getScreenInfo(): Map<String, Any> {
        val displayMetrics = resources.displayMetrics
        return mapOf(
            "width" to displayMetrics.widthPixels,
            "height" to displayMetrics.heightPixels,
            "density" to displayMetrics.density,
            "densityDpi" to displayMetrics.densityDpi
        )
    }

    private fun setAutoRotate(enabled: Boolean) {
        Settings.System.putInt(contentResolver, Settings.System.ACCELEROMETER_ROTATION, if (enabled) 1 else 0)
    }

    private fun notifyFlutterAppResumed() {
        nativeChannel.invokeMethod("onAppResumed", null)
    }

    private fun notifyFlutterAppPaused() {
        nativeChannel.invokeMethod("onAppPaused", null)
    }

    companion object {
        private const val PERMISSION_REQUEST_CODE = 1001
    }
}