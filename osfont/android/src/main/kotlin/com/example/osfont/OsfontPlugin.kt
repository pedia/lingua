package com.example.osfont

import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import android.os.Build
import java.io.File

/** OsfontPlugin */
class OsfontPlugin :
    FlutterPlugin,
    MethodCallHandler {
    // The MethodChannel that will the communication between Flutter and native Android
    //
    // This local reference serves to register the plugin with the Flutter Engine and unregister it
    // when the Flutter Engine is detached from the Activity
    private lateinit var channel: MethodChannel

    override fun onAttachedToEngine(flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
        channel = MethodChannel(flutterPluginBinding.binaryMessenger, "osfont")
        channel.setMethodCallHandler(this)
    }

    override fun onMethodCall(
        call: MethodCall,
        result: Result
    ) {
        if (call.method == "getPlatformVersion") {
            result.success("Android ${android.os.Build.VERSION.RELEASE}")
        }
        else if (call.method == "getAvailableFonts") {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                result.success(getSystemFontsApi29())
            } else {
                // Fallback for Android 9 and below
                result.success(getSystemFontsLegacy())
            }
        } else {
            result.notImplemented()
        }
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
    }

    // ---------- API 29+ ----------
    @androidx.annotation.RequiresApi(Build.VERSION_CODES.Q)
    private fun getSystemFontsApi29(): List<Map<String, Any?>> {
        val fonts = android.graphics.fonts.SystemFonts.getAvailableFonts()
        return fonts.map { font ->
            mapOf(
                "path" to (font.file?.absolutePath ?: ""),
                "weight" to font.style.weight,
                "slant" to font.style.slant,          // 0 = normal, 1 = italic
                "ttcIndex" to font.ttcIndex,
                "axes" to (font.axes?.map { axis ->
                    mapOf(
                        "tag" to axis.tag,
                        "styleValue" to axis.styleValue
                    )
                } ?: emptyList<Map<String, Any?>>())
            )
        }
    }

    // ---------- Legacy fallback (Android 9 and below) ----------
    private fun getSystemFontsLegacy(): List<Map<String, Any?>> {
        val candidates = listOf(
            "/system/fonts",
            "/system/font",
            "/data/fonts",
            "/product/fonts",
            "/system/product/fonts"
        )

        val result = mutableListOf<Map<String, Any?>>()

        for (dirPath in candidates) {
            val dir = File(dirPath)
            if (!dir.exists() || !dir.isDirectory) continue

            dir.listFiles()?.forEach { file ->
                if (file.isFile &&
                    (file.name.endsWith(".ttf", true) ||
                     file.name.endsWith(".otf", true) ||
                     file.name.endsWith(".ttc", true))) {

                    result.add(
                        mapOf(
                            "path" to file.absolutePath,
                            "weight" to 400,
                            "slant" to 0,
                            "ttcIndex" to 0,
                            "axes" to emptyList<Map<String, Any>>()
                        )
                    )
                }
            }
        }
        return result
    }    
}
