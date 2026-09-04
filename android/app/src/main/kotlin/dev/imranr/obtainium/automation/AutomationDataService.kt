package dev.imranr.obtainium.automation

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.Service
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.os.ParcelFileDescriptor
import android.util.Log
import dev.imranr.obtainium.R
import io.flutter.FlutterInjector
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.dart.DartExecutor
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.util.concurrent.ConcurrentHashMap
import java.util.concurrent.atomic.AtomicBoolean

/**
 * Where a data export or import actually runs.
 *
 * ## Why a foreground service and not the provider call
 *
 * The call returns in milliseconds; this can run far longer. Two hard reasons
 * it cannot be done anywhere cheaper:
 *
 * - **A binder call holds the caller.** 応用管理 is drawing a list; a
 *   multi-second synchronous call would freeze its UI, report no progress and
 *   refuse cancellation.
 * - **A backgrounded app writing for minutes is frozen mid-stream on this
 *   phone**, which yields a truncated archive underneath a success reply — the
 *   worst possible failure, because it is indistinguishable from a good backup
 *   until the day it is restored.
 *
 * ## Why there is a Flutter engine in here
 *
 * This app is Flutter, and the export core — `skBuildExportZip` — is Dart, as
 * is the import. The service therefore does what `StateExportReceiver` does for
 * the §1 broadcast path: boots the app's Dart code headlessly (no Activity) and
 * calls into it. It uses its **own** channel and entrypoint rather than sharing
 * the receiver's, so the EMUI-proven broadcast path is not disturbed by this
 * one; the two never contend in practice, and two engines in a process are
 * cheap next to the risk of touching what already works.
 *
 * ## The descriptor
 *
 * Already duplicated by [AutomationProvider] before it got here, because the
 * original belongs to the binder transaction and is closed the moment `call()`
 * returns. This service owns the copy and closes it in a `finally` — leaking one
 * would hold the caller's file open indefinitely, and a caller cannot checksum
 * or encrypt a file that is still open.
 */
class AutomationDataService : Service() {

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        // FOREGROUND FIRST — before any decision that can return, INCLUDING the
        // decision to do nothing.
        //
        // `startForegroundService` has already promised the platform that this
        // service goes foreground inside its window, and that promise is not
        // conditional on our finding work to do: return without keeping it and
        // the process is killed with ForegroundServiceDidNotStartInTimeException.
        // So a caller retrying with a stale job id would CRASH the app it is
        // backing up rather than be harmlessly ignored.
        //
        // Reading `importing` for the notification BEFORE the job id is the
        // whole trick. Hoisting the job-id read above this line is the natural
        // way to write it, and is exactly how the crash comes back.
        val importing = intent?.getBooleanExtra(EXTRA_IMPORTING, false) ?: false
        val wentForeground = runCatching {
            startForeground(NOTIFICATION_ID, notification(importing))
        }.onFailure { Log.w(TAG, "Could not go foreground", it) }.isSuccess

        val jobId = intent?.getStringExtra(EXTRA_JOB) ?: return stop(startId)
        val fd = HANDOVER.remove(jobId) ?: return stop(startId)

        val job = Job(
            id = jobId,
            fd = fd,
            importing = importing,
            items = intent.getStringExtra(AutomationProvider.KEY_ITEMS),
            replyAction = intent.getStringExtra(AutomationProvider.KEY_REPLY_ACTION),
            replyPackage = intent.getStringExtra(AutomationProvider.KEY_REPLY_PACKAGE),
            progressAction = intent.getStringExtra(AutomationProvider.KEY_PROGRESS_ACTION),
            startId = startId,
        )

        // The descriptor has left HANDOVER by now, so if the promotion was
        // refused nothing else would ever close it — and the caller is holding
        // an `OK:<job_id>` for work that cannot safely run. Answer rather than
        // press on: a service the platform refused to promote is one it may
        // starve or kill mid-write, which yields a truncated archive underneath
        // a success reply. That failure only appears on a phone WITHOUT the
        // battery-optimisation exemption — precisely the clean-phone case this
        // whole contract exists for.
        if (!wentForeground) {
            finish(job, "ERROR:cannot go foreground")
            return START_NOT_STICKY
        }

        // One at a time. Two jobs would share one Dart isolate and one set of
        // providers; the second is refused rather than allowed to corrupt the
        // first, and refusing it does NOT disturb the one already running (its
        // own startId keeps the service alive).
        synchronized(lock) {
            if (active != null) {
                finish(job, "ERROR:automation job already running")
                return START_NOT_STICKY
            }
            active = job
        }

        Log.i(TAG, "${if (importing) "import" else "export"} job $jobId")
        job.watchdog = Runnable { finish(job, "ERROR:timed out") }
        mainHandler.postDelayed(job.watchdog!!, WATCHDOG_MS)
        // The engine outlives a single service instance, so the handler is
        // re-pointed at the instance that is actually running this job. Left
        // pointing at a destroyed one, a `stopSelf` for THIS job's startId would
        // land on a dead object and the live service would never stop.
        channel?.setMethodCallHandler { call, result -> onDartCall(call, result) }
        if (engine == null) startEngine(job) else dispatch(job)
        return START_NOT_STICKY
    }

    /**
     * One request through the data door, and everything it must unwind.
     *
     * Deliberately NOT an inner class: [active] is static, and a static field
     * holding an inner instance would pin a destroyed Service for as long as the
     * job lived. The watchdog is installed by whichever instance is live, and
     * removed on the one terminal answer.
     */
    private class Job(
        val id: String,
        val fd: ParcelFileDescriptor,
        val importing: Boolean,
        val items: String?,
        val replyAction: String?,
        val replyPackage: String?,
        val progressAction: String?,
        val startId: Int,
    ) {
        val replied = AtomicBoolean(false)
        var watchdog: Runnable? = null
    }

    /**
     * The one terminal answer for [job], whatever path got here.
     *
     * Guarded by an `AtomicBoolean` so a synchronous failure and an
     * asynchronous success can never both fire — the same guard the broadcast
     * contract has carried since the first sister app. Closing the descriptor
     * lives here too: a leaked one holds the caller's file open, and the caller
     * cannot checksum or encrypt a file that is still open.
     */
    private fun finish(job: Job, result: String) {
        if (!job.replied.compareAndSet(false, true)) return
        job.watchdog?.let { mainHandler.removeCallbacks(it) }
        // `active` is only ours to clear if it is ours — a job refused because
        // another was already running must not clear the running one's slot.
        // The foreground state is the same question: dropping it here while
        // another job is mid-write would demote the service EMUI is tolerating
        // BECAUSE it is foreground. Only the last one out turns it off.
        val idle = synchronized(lock) {
            if (active === job) active = null
            active == null
        }
        AutomationJobs.finish(job.id)
        runCatching { job.fd.close() }
        Log.i(TAG, "${job.id} <- $result")
        val action = job.replyAction
        val pkg = job.replyPackage
        if (!action.isNullOrEmpty() && !pkg.isNullOrEmpty()) {
            runCatching {
                sendBroadcast(
                    Intent(action).apply {
                        setPackage(pkg)
                        // Without this a caller that has been backgrounded never
                        // hears the answer, and on a clean phone the caller may
                        // not have been launched at all.
                        addFlags(Intent.FLAG_INCLUDE_STOPPED_PACKAGES)
                        putExtra(AutomationProvider.KEY_JOB_ID, job.id)
                        // Callers written against the §1 broadcast contract key
                        // on `reply_id`; the data door's correlation id is the
                        // job id. Send both, same value, so either reads.
                        putExtra("reply_id", job.id)
                        putExtra(AutomationProvider.KEY_RESULT, result)
                    },
                )
            }.onFailure { Log.e(TAG, "Reply broadcast failed", it) }
        }
        if (idle) runCatching { stopForeground(STOP_FOREGROUND_REMOVE) }
        stopSelf(job.startId)
    }

    /** Boots the app's Dart code without an Activity. */
    private fun startEngine(job: Job) {
        try {
            val loader = FlutterInjector.instance().flutterLoader()
            loader.startInitialization(applicationContext)
            loader.ensureInitializationComplete(applicationContext, null)
            val newEngine = FlutterEngine(applicationContext)
            val newChannel = MethodChannel(newEngine.dartExecutor.binaryMessenger, CHANNEL)
            newChannel.setMethodCallHandler { call, result -> onDartCall(call, result) }
            engine = newEngine
            channel = newChannel
            newEngine.dartExecutor.executeDartEntrypoint(
                DartExecutor.DartEntrypoint(
                    loader.findAppBundlePath(),
                    ENTRYPOINT_LIBRARY,
                    ENTRYPOINT_FUNCTION,
                ),
            )
        } catch (t: Throwable) {
            Log.e(TAG, "Could not start the headless Flutter engine", t)
            finish(job, "ERROR:engine start failed: ${t.message}")
        }
    }

    private fun onDartCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "ready" -> {
                dartReady = true
                result.success(true)
                synchronized(lock) { active }?.let { dispatch(it) }
            }
            "progress" -> {
                sendProgress(call.arguments)
                result.success(true)
            }
            else -> result.notImplemented()
        }
    }

    /**
     * Real numbers, never a percentage — the same shape the §1 progress
     * broadcasts carry, so a caller has one parser.
     */
    private fun sendProgress(arguments: Any?) {
        val map = arguments as? Map<*, *> ?: return
        val job = synchronized(lock) { active } ?: return
        if (map["job_id"] != job.id) return
        val action = job.progressAction
        if (action.isNullOrEmpty() || job.replyPackage.isNullOrEmpty()) return
        runCatching {
            sendBroadcast(
                Intent(action).apply {
                    setPackage(job.replyPackage)
                    addFlags(Intent.FLAG_INCLUDE_STOPPED_PACKAGES)
                    putExtra(AutomationProvider.KEY_JOB_ID, job.id)
                    putExtra("reply_id", job.id)
                    putExtra("app", map["app"] as? String ?: "")
                    putExtra("item", map["item"] as? String ?: "")
                    putExtra("text", map["text"] as? String ?: "")
                    putExtra("current", (map["current"] as? Number)?.toLong() ?: 0L)
                    putExtra("total", (map["total"] as? Number)?.toLong() ?: 0L)
                    putExtra("unit", map["unit"] as? String ?: "")
                },
            )
        }.onFailure { Log.w(TAG, "Progress broadcast failed", it) }
    }

    private fun dispatch(job: Job) {
        val active = channel ?: return
        if (!dartReady) return
        if (job.importing) readThenImport(active, job) else exportThenWrite(active, job)
    }

    /**
     * Export: Dart builds the whole ZIP, then the bytes go into the caller's
     * descriptor.
     *
     * The archive is built in memory (as the §1 path already does — this app's
     * backup is settings and rows, not a media corpus) and written in one pass,
     * which is what makes cancellation clean here: a cancelled export never
     * writes a byte into the caller's file, so there is no partial archive to
     * sweep up and nothing for a later restore to find.
     */
    private fun exportThenWrite(channel: MethodChannel, job: Job) {
        channel.invokeMethod(
            "export",
            mapOf("job_id" to job.id, "items" to job.items),
            object : MethodChannel.Result {
                override fun success(result: Any?) {
                    val map = result as? Map<*, *>
                        ?: return finish(job, "ERROR:empty result")
                    (map["error"] as? String)?.let { return finish(job, "ERROR:$it") }
                    val bytes = map["bytes"] as? ByteArray
                        ?: return finish(job, "ERROR:export produced nothing")
                    val cats = (map["categories"] as? Number)?.toInt() ?: 0
                    if (AutomationJobs.isCancelled(job.id)) {
                        return finish(job, "ERROR:cancelled")
                    }
                    Thread {
                        val outcome = runCatching {
                            ParcelFileDescriptor.AutoCloseOutputStream(job.fd).use { out ->
                                out.write(bytes)
                                out.flush()
                            }
                            "OK:${bytes.size}|$cats categories"
                        }.getOrElse { "ERROR:${it.message ?: it.javaClass.simpleName}" }
                        mainHandler.post { finish(job, outcome) }
                    }.start()
                }

                override fun error(code: String, message: String?, details: Any?) =
                    finish(job, "ERROR:$code" + if (message.isNullOrEmpty()) "" else " $message")

                override fun notImplemented() = finish(job, "ERROR:handler not implemented")
            },
        )
    }

    /**
     * Import: read the whole archive before touching anything.
     *
     * A partial read that failed halfway would otherwise import half an
     * archive, and a half-restored app is worse than one that refused.
     */
    private fun readThenImport(channel: MethodChannel, job: Job) {
        Thread {
            val bytes = runCatching {
                ParcelFileDescriptor.AutoCloseInputStream(job.fd).use { it.readBytes() }
            }.getOrElse {
                mainHandler.post {
                    finish(job, "ERROR:${it.message ?: it.javaClass.simpleName}")
                }
                return@Thread
            }
            mainHandler.post {
                if (bytes.isEmpty()) return@post finish(job, "ERROR:empty archive")
                if (AutomationJobs.isCancelled(job.id)) return@post finish(job, "ERROR:cancelled")
                channel.invokeMethod(
                    "import",
                    mapOf("job_id" to job.id, "bytes" to bytes),
                    object : MethodChannel.Result {
                        override fun success(result: Any?) {
                            val map = result as? Map<*, *>
                                ?: return finish(job, "ERROR:empty result")
                            (map["error"] as? String)?.let { return finish(job, "ERROR:$it") }
                            val n = (map["restored"] as? Number)?.toInt() ?: 0
                            // 応用管理 force-stops us straight after this. That
                            // is deliberate and belongs on its side: a running
                            // process writes its cached preferences back out at
                            // orderly shutdown and would silently undo the
                            // import that just happened.
                            finish(job, "OK:$n restored")
                        }

                        override fun error(code: String, message: String?, details: Any?) =
                            finish(
                                job,
                                "ERROR:$code" + if (message.isNullOrEmpty()) "" else " $message",
                            )

                        override fun notImplemented() =
                            finish(job, "ERROR:handler not implemented")
                    },
                )
            }
        }.start()
    }

    private fun notification(importing: Boolean): Notification {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            getSystemService(NotificationManager::class.java)?.createNotificationChannel(
                NotificationChannel(CHANNEL_ID, "自動化データ", NotificationManager.IMPORTANCE_LOW),
            )
        }
        return Notification.Builder(this, CHANNEL_ID)
            .setContentTitle(
                if (importing) "データを戻しています" else "データを書き出しています",
            )
            .setSmallIcon(R.drawable.ic_notification)
            .setOngoing(true)
            .build()
    }

    /**
     * The early-out: we went foreground before discovering there was nothing to
     * do (a null intent, or a job id whose descriptor has already been taken).
     *
     * Foreground is given up only when no job is left running — see [finish].
     */
    private fun stop(startId: Int): Int {
        if (synchronized(lock) { active == null }) {
            runCatching { stopForeground(STOP_FOREGROUND_REMOVE) }
        }
        stopSelf(startId)
        return START_NOT_STICKY
    }

    companion object {
        private const val TAG = "SkAutomationData"
        private const val CHANNEL_ID = "automation_data"
        private const val NOTIFICATION_ID = 9714
        private const val EXTRA_JOB = "job"
        private const val EXTRA_IMPORTING = "importing"

        /** Its own channel and entrypoint — see the class doc. */
        private const val CHANNEL = "dev.imranr.obtainium/sk_automation_data"
        private const val ENTRYPOINT_LIBRARY = "package:obtainium/providers/sk_automation.dart"
        private const val ENTRYPOINT_FUNCTION = "skAutomationDataMain"

        /** The caller must get an answer even if Dart never produces one. */
        private const val WATCHDOG_MS = 4L * 60L * 1000L

        private val mainHandler = Handler(Looper.getMainLooper())
        private val lock = Any()

        /** One headless engine for the process lifetime, reused by later jobs. */
        private var engine: FlutterEngine? = null
        private var channel: MethodChannel? = null

        @Volatile
        private var dartReady = false

        private var active: Job? = null

        /**
         * The descriptor's way across, because an Intent is the wrong vehicle
         * for one.
         *
         * A `ParcelFileDescriptor` in an Intent extra is duplicated by the
         * system on delivery and the copy's lifetime stops being ours to reason
         * about. Handing it through a map keyed by the job id keeps exactly one
         * open descriptor with exactly one owner — the service, which closes it
         * on its single terminal answer.
         */
        private val HANDOVER = ConcurrentHashMap<String, ParcelFileDescriptor>()

        fun start(
            context: Context,
            jobId: String,
            fd: ParcelFileDescriptor,
            importing: Boolean,
            extras: Bundle?,
        ) {
            HANDOVER[jobId] = fd
            try {
                context.startForegroundService(
                    Intent(context, AutomationDataService::class.java).apply {
                        putExtra(EXTRA_JOB, jobId)
                        putExtra(EXTRA_IMPORTING, importing)
                        putExtra(
                            AutomationProvider.KEY_ITEMS,
                            extras?.getString(AutomationProvider.KEY_ITEMS),
                        )
                        putExtra(
                            AutomationProvider.KEY_REPLY_ACTION,
                            extras?.getString(AutomationProvider.KEY_REPLY_ACTION),
                        )
                        putExtra(
                            AutomationProvider.KEY_REPLY_PACKAGE,
                            extras?.getString(AutomationProvider.KEY_REPLY_PACKAGE),
                        )
                        putExtra(
                            AutomationProvider.KEY_PROGRESS_ACTION,
                            extras?.getString(AutomationProvider.KEY_PROGRESS_ACTION),
                        )
                    },
                )
            } catch (t: Throwable) {
                // The service never started, so nothing will ever take the
                // descriptor out of the handover map.
                HANDOVER.remove(jobId)
                throw t
            }
        }

        /**
         * Relay a `cancel` into the running job's Dart isolate.
         *
         * [AutomationJobs] holds the flag, but by the time a cancel arrives the
         * work is inside a Dart call and nothing native is looping to poll it.
         * So the stop is pushed the way the §1 receiver pushes its own: over the
         * channel, on the main thread, where the export reads it at its next
         * entry boundary — never mid-write.
         *
         * Safe at any time. Nothing running, an id for another run, or a job
         * that already finished are all silent no-ops.
         */
        fun requestCancel(jobId: String?) {
            val target = synchronized(lock) { active } ?: return
            if (!jobId.isNullOrEmpty() && jobId != target.id) return
            val open = channel ?: return
            mainHandler.post {
                runCatching { open.invokeMethod("cancel", mapOf("job_id" to target.id)) }
                    .onFailure { Log.w(TAG, "Cancel could not be delivered", it) }
            }
        }
    }
}
