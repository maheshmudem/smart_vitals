package com.example.algoritam

import android.app.NotificationManager
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.media.AudioDeviceCallback
import android.media.AudioDeviceInfo
import android.media.AudioManager
import android.os.BatteryManager
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.util.DisplayMetrics
import io.flutter.plugin.common.EventChannel
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private var audioEvents: EventChannel.EventSink? = null
    private var deviceCallback: AudioDeviceCallback? = null

    // Numeric AudioDeviceInfo types so older compile targets still build:
    // 3 wired headset, 4 wired headphones, 5/6 line, 7 BT SCO, 8 BT A2DP,
    // 11 USB device, 12 USB accessory, 19 aux line, 22 USB headset,
    // 23 hearing aid, 26 BLE headset, 27 BLE speaker, 30 BLE broadcast.
    private fun earphoneType(am: AudioManager): String {
        var type = "none"
        try {
            val outs = am.getDevices(AudioManager.GET_DEVICES_OUTPUTS)
            for (d in outs) {
                when (d.type) {
                    3, 4, 5, 6, 19 -> return "wired"
                    11, 12, 22 -> type = "usb"
                    7, 8, 23, 26, 27, 30 -> if (type == "none") type = "bluetooth"
                    else -> {}
                }
            }
        } catch (e: Exception) {
            // fall through to the legacy flags
        }
        if (type == "none") {
            // Legacy flags: some OEM builds (MIUI) report the headset here first.
            ("DEPRECATION")
            if (am.isWiredHeadsetOn) return "wired"
            ("DEPRECATION")
            if (am.isBluetoothA2dpOn || am.isBluetoothScoOn) return "bluetooth"
        }
        return type
    }

    private fun deviceTypes(am: AudioManager): List<Int> = try {
        am.getDevices(AudioManager.GET_DEVICES_OUTPUTS).map { it.type }
    } catch (e: Exception) {
        emptyList()
    }

    private fun audioState(am: AudioManager): Map<String, Any> = mapOf(
        "earphoneType" to earphoneType(am),
        "deviceTypes" to deviceTypes(am),
        "volume" to am.getStreamVolume(AudioManager.STREAM_MUSIC),
        "maxVolume" to am.getStreamMaxVolume(AudioManager.STREAM_MUSIC),
    )

    // Sleep setup (Spec §8 AUD-07, G-30): charger state from the sticky
    // battery broadcast — no permission needed.
    private fun batteryState(): Map<String, Any> {
        return try {
            val intent = registerReceiver(null, IntentFilter(Intent.ACTION_BATTERY_CHANGED))
            val status = intent?.getIntExtra(BatteryManager.EXTRA_STATUS, -1) ?: -1
            val plugged = intent?.getIntExtra(BatteryManager.EXTRA_PLUGGED, 0) ?: 0
            val level = intent?.getIntExtra(BatteryManager.EXTRA_LEVEL, -1) ?: -1
            val scale = intent?.getIntExtra(BatteryManager.EXTRA_SCALE, 100) ?: 100
            val charging = status == BatteryManager.BATTERY_STATUS_CHARGING ||
                status == BatteryManager.BATTERY_STATUS_FULL || plugged != 0
            val pct = if (level < 0 || scale <= 0) -1 else (level * 100 / scale)
            mapOf("charging" to charging, "level" to pct, "plugged" to plugged)
        } catch (e: Exception) {
            mapOf("charging" to false, "level" to -1, "plugged" to 0)
        }
    }

    // Do-not-disturb: any interruption filter other than "all".
    private fun dndActive(): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.M) return false
        return try {
            val nm = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            val f = nm.currentInterruptionFilter
            f != NotificationManager.INTERRUPTION_FILTER_ALL &&
                f != NotificationManager.INTERRUPTION_FILTER_UNKNOWN
        } catch (e: Exception) {
            false
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        // Hearing screen (Spec §8 AUD-09, G-19): output route, media volume
        // and connect / disconnect events.
        val am = getSystemService(Context.AUDIO_SERVICE) as AudioManager
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "vitalsmirror/audio")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "outputs" -> result.success(audioState(am))
                    "setMaxVolume" -> {
                        try {
                            am.setStreamVolume(
                                AudioManager.STREAM_MUSIC,
                                am.getStreamMaxVolume(AudioManager.STREAM_MUSIC),
                                0,
                            )
                            result.success(true)
                        } catch (e: Exception) {
                            result.success(false)
                        }
                    }
                    "setVolumeFraction" -> {
                        try {
                            val frac = (call.argument<Double>("fraction") ?: 0.7).coerceIn(0.0, 1.0)
                            val max = am.getStreamMaxVolume(AudioManager.STREAM_MUSIC)
                            am.setStreamVolume(
                                AudioManager.STREAM_MUSIC,
                                Math.round(max * frac).toInt().coerceIn(0, max),
                                0,
                            )
                            result.success(true)
                        } catch (e: Exception) {
                            result.success(false)
                        }
                    }
                    else -> result.notImplemented()
                }
            }
        EventChannel(flutterEngine.dartExecutor.binaryMessenger, "vitalsmirror/audio/events")
            .setStreamHandler(object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    audioEvents = events
                    val cb = object : AudioDeviceCallback() {
                        override fun onAudioDevicesAdded(added: Array<out AudioDeviceInfo>?) {
                            audioEvents?.success(audioState(am))
                        }
                        override fun onAudioDevicesRemoved(removed: Array<out AudioDeviceInfo>?) {
                            audioEvents?.success(audioState(am))
                        }
                    }
                    deviceCallback = cb
                    am.registerAudioDeviceCallback(cb, Handler(Looper.getMainLooper()))
                }

                override fun onCancel(arguments: Any?) {
                    deviceCallback?.let { am.unregisterAudioDeviceCallback(it) }
                    deviceCallback = null
                    audioEvents = null
                }
            })
        // Overnight sleep (Spec §8 AUD-07, G-30, FR-232): charger state,
        // Do-not-disturb and the microphone keep-alive foreground service.
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "vitalsmirror/sleep")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "battery" -> result.success(batteryState())
                    "dnd" -> result.success(dndActive())
                    "keepAliveStart" -> {
                        val title = call.argument<String>("title") ?: "Sleep monitoring running"
                        val text = call.argument<String>("text") ?: "Phone on the bedside table"
                        result.success(SleepKeepAliveService.start(this, title, text))
                    }
                    "keepAliveStop" -> result.success(SleepKeepAliveService.stop(this))
                    else -> result.notImplemented()
                }
            }
        // Physical screen density for the vision tests (Spec §9 MOV-10 DPI,
        // MOV-11 10 cm Amsler grid). Flutter only exposes the density bucket.
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "vitalsmirror/display")
            .setMethodCallHandler { call, result ->
                if (call.method == "metrics") {
                    val dm = DisplayMetrics()
                    @Suppress("DEPRECATION")
                    windowManager.defaultDisplay.getRealMetrics(dm)
                    result.success(
                        mapOf(
                            "xdpi" to dm.xdpi.toDouble(),
                            "ydpi" to dm.ydpi.toDouble(),
                            "density" to dm.density.toDouble(),
                            "widthPx" to dm.widthPixels,
                            "heightPx" to dm.heightPixels,
                        )
                    )
                } else {
                    result.notImplemented()
                }
            }
    }
}
