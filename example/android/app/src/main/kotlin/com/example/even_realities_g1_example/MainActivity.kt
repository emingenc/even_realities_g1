package com.example.even_realities_g1_example

import android.os.Bundle
import androidx.annotation.NonNull
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import com.example.even_realities_g1_example.cpp.Cpp

class MainActivity: FlutterActivity() {
	private val channelName = "dev.even.g1/lc3"

	override fun onCreate(savedInstanceState: Bundle?) {
		super.onCreate(savedInstanceState)
		Cpp.init()
	}

	override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
		super.configureFlutterEngine(flutterEngine)

		MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
			.setMethodCallHandler { call, result ->
				when (call.method) {
					"decodeLC3" -> {
						val data = call.argument<ByteArray>("data")
						if (data == null) {
							result.error("invalid_argument", "data is null", null)
						} else {
							try {
								val pcm = Cpp.decodeLC3(data)
								result.success(pcm)
							} catch (e: Exception) {
								result.error("lc3_error", e.message, null)
							}
						}
					}
					else -> result.notImplemented()
				}
			}
	}
}
