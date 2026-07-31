package dev.imranr.obtainium

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Handler
import android.os.Looper
import android.util.Log
import io.flutter.FlutterInjector
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.dart.DartExecutor
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.util.ArrayDeque
import java.util.concurrent.atomic.AtomicBoolean

/**
 * 保存復元 — the token-gated state-export contract 白い熊's 自由作業盤 fires at
 * every sister app to back them all up in one run.
 *
 * `<pkg>.action.EXPORT_STATE` runs this app's own export headlessly (no
 * Activity, no user interaction), `<pkg>.action.LIST_CATEGORIES` answers with
 * the exportable categories, and `<pkg>.action.CANCEL_EXPORT` stops a running
 * export. None of them reimplements anything: all boot the app's Dart code in
 * a plain FlutterEngine and call into `lib/providers/sk_automation.dart`,
 * which drives the one export core.
 *
 * Hard-won constraints, verified on 白い熊's Mate XT (EMUI), 2026-07-23 — do
 * not "improve" these:
 *  - the reply is a FRESH BROADCAST. No ResultReceiver, no PendingIntent, no
 *    Messenger: EMUI will not reliably carry a live Binder into another app's
 *    manifest receiver, and a broadcast carrying one may be dropped outright.
 *  - FLAG_INCLUDE_STOPPED_PACKAGES matters — without it a backgrounded or
 *    stopped caller never hears the reply.
 *  - the ordered-broadcast result is set too (correct AOSP behaviour) but is
 *    never relied on: EMUI severs that channel between third-party apps.
 *
 * Exactly one terminal reply per request, guarded by an AtomicBoolean, so an
 * async success and a synchronous error can never both fire.
 */
class StateExportReceiver : BroadcastReceiver() {

    private class Request(
        val kind: String,
        val token: String?,
        val path: String?,
        val items: String?,
        val progressAction: String?,
        val replyAction: String,
        val replyPackage: String,
        val replyId: String,
        val ordered: Boolean,
        val pendingResult: PendingResult,
    ) {
        val replied = AtomicBoolean(false)
    }

    private companion object {
        const val TAG = "SkStateExport"
        const val CHANNEL = "dev.imranr.obtainium/sk_automation"
        const val ENTRYPOINT_LIBRARY = "package:obtainium/providers/sk_automation.dart"
        const val ENTRYPOINT_FUNCTION = "skAutomationMain"

        /** The caller must get an answer even if Dart never produces one. */
        const val WATCHDOG_MS = 4L * 60L * 1000L

        /**
         * How long a cancel may hold its broadcast open waiting for Dart to
         * acknowledge. The flag is set the moment Dart's event loop turns, but
         * the export it stops may be inside a long synchronous stretch, and a
         * fire-and-forget action must never sit on a receiver until Android
         * complains.
         */
        const val CANCEL_ACK_MS = 5L * 1000L

        val lock = Any()
        val mainHandler = Handler(Looper.getMainLooper())
        val queued = ArrayDeque<Request>()
        val inFlight = HashMap<String, Request>()

        /**
         * One headless engine for the process lifetime, reused by later
         * requests. Requests are dispatched one at a time.
         */
        var engine: FlutterEngine? = null
        var channel: MethodChannel? = null

        @Volatile
        var dartReady = false
    }

    override fun onReceive(context: Context, intent: Intent) {
        val action = intent.action ?: return
        if (action == "${context.packageName}.action.CANCEL_EXPORT") {
            cancelExport(intent)
            return
        }
        val kind = when (action) {
            "${context.packageName}.action.EXPORT_STATE" -> "export"
            "${context.packageName}.action.LIST_CATEGORIES" -> "categories"
            else -> return
        }
        val replyAction = intent.getStringExtra("reply_action")
        val replyPackage = intent.getStringExtra("reply_package")
        val replyId = intent.getStringExtra("reply_id")
        if (replyAction.isNullOrEmpty() ||
            replyPackage.isNullOrEmpty() ||
            replyId.isNullOrEmpty()
        ) {
            Log.w(TAG, "$action without reply_action/reply_package/reply_id — nowhere to reply")
            return
        }

        // Read the ordered hint BEFORE goAsync() hands the result off.
        val ordered = isOrderedBroadcast
        val appContext = context.applicationContext
        val request = Request(
            kind = kind,
            token = intent.getStringExtra("token"),
            path = intent.getStringExtra("path"),
            items = intent.getStringExtra("items"),
            progressAction = intent.getStringExtra("progress_action"),
            replyAction = replyAction,
            replyPackage = replyPackage,
            replyId = replyId,
            ordered = ordered,
            pendingResult = goAsync(),
        )
        Log.i(TAG, "$kind request $replyId (items=${request.items ?: "*"}, path=${request.path ?: "-"})")
        synchronized(lock) { queued.add(request) }
        mainHandler.postDelayed({ reply(appContext, request, "ERROR:timed out") }, WATCHDOG_MS)

        if (engine == null) startEngine(appContext) else drain(appContext)
    }

    /**
     * `<pkg>.action.CANCEL_EXPORT` — stop the export that is running.
     *
     * Fire-and-forget: this action sends NO reply of its own. The terminal
     * `ERROR:cancelled` belongs to the original `EXPORT_STATE` request and
     * goes out through [reply], under the same one-reply-per-request guard, so
     * a cancel and a success can never both fire.
     *
     * Safe to send at any time. Nothing running, an already-finished export,
     * a token that does not match, an id for some other run — every one of
     * them is a silent no-op: no error, no reply, no crash.
     *
     * Two deliberate bypasses. It comes in through this EXPORTED receiver
     * because the stop path lives in Dart and no third-party caller can reach
     * a non-exported component of this app; and it skips the one-at-a-time
     * request queue on both sides, because a cancel that waited its turn
     * behind the export it is meant to stop would never arrive.
     */
    private fun cancelExport(intent: Intent) {
        val activeChannel = channel
        if (activeChannel == null || !dartReady) {
            // No engine, no export — there is nothing this could stop.
            Log.i(TAG, "CANCEL_EXPORT with nothing running — ignored")
            return
        }
        val pending = goAsync()
        val finished = AtomicBoolean(false)
        val release = {
            if (finished.compareAndSet(false, true)) {
                try {
                    pending.finish()
                } catch (t: Throwable) {
                    Log.w(TAG, "Could not finish the cancel broadcast", t)
                }
            }
        }
        mainHandler.postDelayed({ release() }, CANCEL_ACK_MS)
        try {
            // The token is verified in Dart, next to the prefs that hold it.
            activeChannel.invokeMethod(
                "cancel",
                mapOf(
                    "token" to intent.getStringExtra("token"),
                    "reply_id" to intent.getStringExtra("reply_id"),
                ),
                object : MethodChannel.Result {
                    override fun success(result: Any?) {
                        Log.i(TAG, "CANCEL_EXPORT accepted=${result == true}")
                        release()
                    }

                    override fun error(code: String, message: String?, details: Any?) {
                        Log.w(TAG, "CANCEL_EXPORT rejected: $code ${message ?: ""}")
                        release()
                    }

                    override fun notImplemented() = release()
                },
            )
        } catch (t: Throwable) {
            Log.w(TAG, "CANCEL_EXPORT could not be delivered", t)
            release()
        }
    }

    /** Boots the app's Dart code without an Activity. */
    private fun startEngine(context: Context) {
        try {
            val loader = FlutterInjector.instance().flutterLoader()
            loader.startInitialization(context)
            loader.ensureInitializationComplete(context, null)
            val newEngine = FlutterEngine(context)
            val newChannel = MethodChannel(newEngine.dartExecutor.binaryMessenger, CHANNEL)
            newChannel.setMethodCallHandler { call, result -> onDartCall(context, call, result) }
            engine = newEngine
            channel = newChannel
            newEngine.dartExecutor.executeDartEntrypoint(
                DartExecutor.DartEntrypoint(
                    loader.findAppBundlePath(),
                    ENTRYPOINT_LIBRARY,
                    ENTRYPOINT_FUNCTION,
                )
            )
        } catch (t: Throwable) {
            Log.e(TAG, "Could not start the headless Flutter engine", t)
            failAll(context, "ERROR:engine start failed: ${t.message}")
        }
    }

    private fun onDartCall(context: Context, call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "ready" -> {
                dartReady = true
                result.success(true)
                drain(context)
            }
            "progress" -> {
                sendProgress(context, call.arguments)
                result.success(true)
            }
            else -> result.notImplemented()
        }
    }

    /** Dispatches the next queued request — one at a time, in arrival order. */
    private fun drain(context: Context) {
        val activeChannel = channel ?: return
        val request = synchronized(lock) {
            if (!dartReady || inFlight.isNotEmpty()) return
            val next = queued.pollFirst() ?: return
            inFlight[next.replyId] = next
            next
        }
        activeChannel.invokeMethod(
            "handle",
            mapOf(
                "action" to request.kind,
                "token" to request.token,
                "path" to request.path,
                "items" to request.items,
                "reply_id" to request.replyId,
            ),
            object : MethodChannel.Result {
                override fun success(result: Any?) =
                    reply(context, request, result as? String ?: "ERROR:empty result")

                override fun error(code: String, message: String?, details: Any?) =
                    reply(
                        context,
                        request,
                        "ERROR:$code" + if (message.isNullOrEmpty()) "" else " $message",
                    )

                override fun notImplemented() =
                    reply(context, request, "ERROR:handler not implemented")
            },
        )
    }

    /**
     * Real numbers, never a percentage: `current`/`total`/`unit` travel
     * alongside the display line so 自由作業盤 can render a bar later.
     */
    private fun sendProgress(context: Context, arguments: Any?) {
        val map = arguments as? Map<*, *> ?: return
        val replyId = map["reply_id"] as? String ?: return
        val request = synchronized(lock) { inFlight[replyId] } ?: return
        val progressAction = request.progressAction
        if (progressAction.isNullOrEmpty()) return
        try {
            context.sendBroadcast(
                Intent(progressAction).apply {
                    setPackage(request.replyPackage)
                    addFlags(Intent.FLAG_INCLUDE_STOPPED_PACKAGES)
                    putExtra("reply_id", replyId)
                    putExtra("app", map["app"] as? String ?: "")
                    putExtra("text", map["text"] as? String ?: "")
                    putExtra("current", (map["current"] as? Number)?.toLong() ?: 0L)
                    putExtra("total", (map["total"] as? Number)?.toLong() ?: 0L)
                    putExtra("unit", map["unit"] as? String ?: "")
                }
            )
        } catch (t: Throwable) {
            Log.w(TAG, "Progress broadcast failed", t)
        }
    }

    /** The one terminal reply for [request]. Later calls are no-ops. */
    private fun reply(context: Context, request: Request, result: String) {
        if (!request.replied.compareAndSet(false, true)) return
        synchronized(lock) { inFlight.remove(request.replyId) }
        Log.i(TAG, "${request.replyId} <- ${result.substringBefore('\n')}")
        try {
            context.sendBroadcast(
                Intent(request.replyAction).apply {
                    setPackage(request.replyPackage)
                    addFlags(Intent.FLAG_INCLUDE_STOPPED_PACKAGES)
                    putExtra("reply_id", request.replyId)
                    putExtra("result", result)
                }
            )
        } catch (t: Throwable) {
            Log.e(TAG, "Reply broadcast failed", t)
        }
        try {
            if (request.ordered) request.pendingResult.setResultData(result)
            request.pendingResult.finish()
        } catch (t: Throwable) {
            Log.w(TAG, "Could not finish the broadcast", t)
        }
        drain(context)
    }

    private fun failAll(context: Context, result: String) {
        while (true) {
            val request = synchronized(lock) { queued.pollFirst() } ?: break
            reply(context, request, result)
        }
        val stuck = synchronized(lock) { inFlight.values.toList() }
        for (request in stuck) reply(context, request, result)
    }
}
