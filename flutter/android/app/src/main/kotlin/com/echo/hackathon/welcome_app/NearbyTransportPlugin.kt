package com.echo.hackathon.welcome_app

// Real Google Nearby Connections (com.google.android.gms.nearby.connection),
// wired to speak the exact same wire protocol as Echo's RN app
// (src/features/messaging/api/transport.ts): the caller passes the same
// literal serviceId ("com.echo.app", RN's Android application id — NOT this
// app's own applicationId) and Strategy.P2P_CLUSTER, so a phone running this
// app and a phone running the RN app discover and connect to each other for
// real. Every invitation is accepted unconditionally on both sides — trust is
// enforced at the app layer (Dart's contacts list), not the transport layer,
// exactly matching RN's own native module. Chunk splitting/reassembly live in
// Dart (mesh_transport.dart); this layer only ever moves whole byte blobs,
// one Payload.fromBytes() per send call, same as RN's.
import android.Manifest
import android.app.Activity
import android.content.pm.PackageManager
import android.os.Build
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import com.google.android.gms.common.ConnectionResult
import com.google.android.gms.common.GoogleApiAvailability
import com.google.android.gms.nearby.Nearby
import com.google.android.gms.nearby.connection.AdvertisingOptions
import com.google.android.gms.nearby.connection.ConnectionInfo
import com.google.android.gms.nearby.connection.ConnectionLifecycleCallback
import com.google.android.gms.nearby.connection.ConnectionResolution
import com.google.android.gms.nearby.connection.ConnectionsClient
import com.google.android.gms.nearby.connection.DiscoveredEndpointInfo
import com.google.android.gms.nearby.connection.DiscoveryOptions
import com.google.android.gms.nearby.connection.EndpointDiscoveryCallback
import com.google.android.gms.nearby.connection.Payload
import com.google.android.gms.nearby.connection.PayloadCallback
import com.google.android.gms.nearby.connection.PayloadTransferUpdate
import com.google.android.gms.nearby.connection.Strategy
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.PluginRegistry

class NearbyTransportPlugin :
    FlutterPlugin,
    ActivityAware,
    MethodChannel.MethodCallHandler,
    EventChannel.StreamHandler,
    PluginRegistry.RequestPermissionsResultListener {

    private lateinit var methodChannel: MethodChannel
    private lateinit var eventChannel: EventChannel
    private var eventSink: EventChannel.EventSink? = null
    private var activity: Activity? = null
    private var connectionsClient: ConnectionsClient? = null
    private var appContext: android.content.Context? = null
    private var pendingPermissionResult: MethodChannel.Result? = null

    companion object {
        private const val METHOD_CHANNEL = "echo.mesh/nearby"
        private const val EVENT_CHANNEL = "echo.mesh/nearby_events"
        private const val PERMISSION_REQUEST_CODE = 8712
    }

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        appContext = binding.applicationContext
        methodChannel = MethodChannel(binding.binaryMessenger, METHOD_CHANNEL)
        methodChannel.setMethodCallHandler(this)
        eventChannel = EventChannel(binding.binaryMessenger, EVENT_CHANNEL)
        eventChannel.setStreamHandler(this)
        connectionsClient = Nearby.getConnectionsClient(binding.applicationContext)
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        methodChannel.setMethodCallHandler(null)
        eventChannel.setStreamHandler(null)
        connectionsClient = null
    }

    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        activity = binding.activity
        binding.addRequestPermissionsResultListener(this)
    }

    override fun onDetachedFromActivityForConfigChanges() {
        activity = null
    }

    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
        activity = binding.activity
        binding.addRequestPermissionsResultListener(this)
    }

    override fun onDetachedFromActivity() {
        activity = null
    }

    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
        eventSink = events
    }

    override fun onCancel(arguments: Any?) {
        eventSink = null
    }

    private fun emit(event: Map<String, Any?>) {
        val sink = eventSink ?: return
        val act = activity
        if (act != null) {
            act.runOnUiThread { sink.success(event) }
        } else {
            sink.success(event)
        }
    }

    private fun requiredPermissions(): Array<String> {
        val perms = mutableListOf(Manifest.permission.ACCESS_FINE_LOCATION)
        if (Build.VERSION.SDK_INT >= 31) {
            perms.add(Manifest.permission.BLUETOOTH_SCAN)
            perms.add(Manifest.permission.BLUETOOTH_ADVERTISE)
            perms.add(Manifest.permission.BLUETOOTH_CONNECT)
        }
        if (Build.VERSION.SDK_INT >= 33) {
            perms.add("android.permission.NEARBY_WIFI_DEVICES")
        }
        return perms.toTypedArray()
    }

    private fun hasAllPermissions(): Boolean {
        val ctx = appContext ?: return false
        return requiredPermissions().all {
            ContextCompat.checkSelfPermission(ctx, it) == PackageManager.PERMISSION_GRANTED
        }
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        val client = connectionsClient
        when (call.method) {
            "requestPermissions" -> {
                val act = activity
                if (act == null) {
                    result.success(false)
                    return
                }
                if (hasAllPermissions()) {
                    result.success(true)
                    return
                }
                pendingPermissionResult = result
                ActivityCompat.requestPermissions(act, requiredPermissions(), PERMISSION_REQUEST_CODE)
            }
            "isAvailable" -> {
                val ctx = appContext
                val available = client != null && ctx != null &&
                    GoogleApiAvailability.getInstance().isGooglePlayServicesAvailable(ctx) == ConnectionResult.SUCCESS
                result.success(available)
            }
            "startAdvertise" -> {
                val name = call.argument<String>("name")!!
                val serviceId = call.argument<String>("serviceId")!!
                val options = AdvertisingOptions.Builder().setStrategy(Strategy.P2P_CLUSTER).build()
                if (client == null) {
                    result.success(false)
                    return
                }
                client.startAdvertising(name, serviceId, connectionLifecycleCallback, options)
                    .addOnSuccessListener { result.success(true) }
                    .addOnFailureListener { e -> result.error("ADVERTISE_FAILED", e.message, null) }
            }
            "startDiscovery" -> {
                val serviceId = call.argument<String>("serviceId")!!
                val options = DiscoveryOptions.Builder().setStrategy(Strategy.P2P_CLUSTER).build()
                if (client == null) {
                    result.success(false)
                    return
                }
                client.startDiscovery(serviceId, endpointDiscoveryCallback, options)
                    .addOnSuccessListener { result.success(true) }
                    .addOnFailureListener { e -> result.error("DISCOVERY_FAILED", e.message, null) }
            }
            "stopAdvertising" -> {
                client?.stopAdvertising()
                result.success(null)
            }
            "stopDiscovery" -> {
                client?.stopDiscovery()
                result.success(null)
            }
            "stopAll" -> {
                client?.stopAllEndpoints()
                result.success(null)
            }
            "requestConnection" -> {
                val name = call.argument<String>("name")!!
                val endpointId = call.argument<String>("endpointId")!!
                if (client == null) {
                    result.success(false)
                    return
                }
                client.requestConnection(name, endpointId, connectionLifecycleCallback)
                    .addOnSuccessListener { result.success(true) }
                    .addOnFailureListener { e -> result.error("CONNECT_FAILED", e.message, null) }
            }
            "disconnect" -> {
                val endpointId = call.argument<String>("endpointId")!!
                client?.disconnectFromEndpoint(endpointId)
                result.success(null)
            }
            "sendBytes" -> {
                val endpointId = call.argument<String>("endpointId")!!
                val bytes = call.argument<ByteArray>("bytes")!!
                if (client == null) {
                    result.success(false)
                    return
                }
                client.sendPayload(endpointId, Payload.fromBytes(bytes))
                    .addOnSuccessListener { result.success(true) }
                    .addOnFailureListener { e -> result.error("SEND_FAILED", e.message, null) }
            }
            else -> result.notImplemented()
        }
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray,
    ): Boolean {
        if (requestCode != PERMISSION_REQUEST_CODE) return false
        val granted = grantResults.isNotEmpty() && grantResults.all { it == PackageManager.PERMISSION_GRANTED }
        pendingPermissionResult?.success(granted)
        pendingPermissionResult = null
        return true
    }

    private val connectionLifecycleCallback = object : ConnectionLifecycleCallback() {
        override fun onConnectionInitiated(endpointId: String, info: ConnectionInfo) {
            // Surface the name here too (as "invited", not "found") — this is
            // the only callback that fires on the *advertiser* side, which
            // never gets an EndpointDiscoveryCallback for the peer that found
            // it. Without this, an advertiser-side connection would have no
            // name to resolve until the far side happened to reconnect later.
            emit(mapOf("type" to "invited", "peerId" to endpointId, "name" to info.endpointName))
            connectionsClient?.acceptConnection(endpointId, payloadCallback)
        }

        override fun onConnectionResult(endpointId: String, result: ConnectionResolution) {
            if (result.status.isSuccess) {
                emit(mapOf("type" to "connected", "peerId" to endpointId))
            } else {
                emit(mapOf("type" to "lost", "peerId" to endpointId))
            }
        }

        override fun onDisconnected(endpointId: String) {
            emit(mapOf("type" to "lost", "peerId" to endpointId))
        }
    }

    private val endpointDiscoveryCallback = object : EndpointDiscoveryCallback() {
        override fun onEndpointFound(endpointId: String, info: DiscoveredEndpointInfo) {
            emit(mapOf("type" to "found", "peerId" to endpointId, "name" to info.endpointName))
        }

        override fun onEndpointLost(endpointId: String) {
            emit(mapOf("type" to "lost", "peerId" to endpointId))
        }
    }

    private val payloadCallback = object : PayloadCallback() {
        override fun onPayloadReceived(endpointId: String, payload: Payload) {
            if (payload.type != Payload.Type.BYTES) return
            val bytes = payload.asBytes() ?: return
            emit(mapOf("type" to "payload", "peerId" to endpointId, "bytes" to bytes))
        }

        override fun onPayloadTransferUpdate(endpointId: String, update: PayloadTransferUpdate) {
            // No progress/resume UI in this app — matches RN's own stub here.
        }
    }
}
