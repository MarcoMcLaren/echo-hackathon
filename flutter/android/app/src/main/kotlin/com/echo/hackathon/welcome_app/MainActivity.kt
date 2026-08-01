package com.echo.hackathon.welcome_app

// local_auth needs a FragmentActivity host to show the BiometricPrompt.
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine

class MainActivity : FlutterFragmentActivity() {
    // NearbyTransportPlugin is app-local Kotlin, not a pub.dev package, so it
    // isn't picked up by GeneratedPluginRegistrant — it has to be added here.
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        flutterEngine.plugins.add(NearbyTransportPlugin())
    }
}
