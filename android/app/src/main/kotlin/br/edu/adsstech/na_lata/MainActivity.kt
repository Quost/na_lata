package br.edu.adsstech.na_lata

import android.content.Intent
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val methodChannelName = "br.edu.adsstech.na_lata/deep_links"
    private val eventChannelName = "br.edu.adsstech.na_lata/deep_link_events"
    private var initialLink: String? = null
    private var pendingLink: String? = null
    private var eventSink: EventChannel.EventSink? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        if (initialLink == null) initialLink = intent?.dataString

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            methodChannelName,
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "getInitialLink" -> {
                    result.success(initialLink)
                    initialLink = null
                }
                "share" -> {
                    val text = call.argument<String>("text")
                    if (text.isNullOrBlank()) {
                        result.error("invalid_share_text", "Share text is required.", null)
                    } else {
                        try {
                            val intent = Intent(Intent.ACTION_SEND).apply {
                                type = "text/plain"
                                putExtra(Intent.EXTRA_TEXT, text)
                            }
                            startActivity(Intent.createChooser(intent, "Compartilhar link"))
                            result.success(null)
                        } catch (error: android.content.ActivityNotFoundException) {
                            result.error("share_unavailable", "No share target is available.", null)
                        }
                    }
                }
                else -> result.notImplemented()
            }
        }

        EventChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            eventChannelName,
        ).setStreamHandler(object : EventChannel.StreamHandler {
            override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                eventSink = events
                pendingLink?.let {
                    events?.success(it)
                    pendingLink = null
                }
            }

            override fun onCancel(arguments: Any?) {
                eventSink = null
            }
        })
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        val link = intent.dataString ?: return
        val sink = eventSink
        if (sink == null) pendingLink = link else sink.success(link)
    }
}
