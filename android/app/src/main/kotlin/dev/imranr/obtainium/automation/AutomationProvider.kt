package dev.imranr.obtainium.automation

import android.content.ContentProvider
import android.content.ContentValues
import android.content.Context
import android.database.Cursor
import android.net.Uri
import android.os.Bundle
import android.os.ParcelFileDescriptor

/**
 * The data door: export this app's own state, and put it back, for a caller we
 * can identify.
 *
 * ## Why a provider and not the broadcast receiver next to it
 *
 * Two reasons, and the first is the whole point of the v2 redesign.
 *
 * **A broadcast cannot tell you who sent it.** v1's answer to that was a shared
 * secret, which cannot survive the wipe this feature exists to recover from. A
 * provider gets the caller's identity from the framework for free — see
 * [AutomationCallers] for what is actually checked and why a `shiroikuma.*`
 * prefix would have been strictly weaker than the token it replaced.
 *
 * **A list needs a synchronous answer.** 応用管理 draws a row per installed app
 * before any export exists; a broadcast round trip per app to fill a list is
 * the wrong shape entirely. That is also why the gate consulted here is
 * [SkAutomationGate] — the native mirror of Dart's [SkAutomation] — rather than
 * a Flutter engine boot per call.
 *
 * ## What does NOT happen here
 *
 * The payload. `call()` validates, starts a foreground service and returns. The
 * bytes go through a file descriptor the caller opened, and the terminal answer
 * comes back on the broadcast the family already proved on EMUI.
 *
 * ## Why a descriptor and not a path
 *
 * Because a backup is not a stable directory while it is being assembled.
 * 応用管理 writes into a temporary path and renames on commit; it encrypts and
 * checksums **per file it knows about**. A file this app dropped into that
 * directory itself would be renamed out from under it, would sit in plaintext
 * inside an encrypted backup, and would be unverified rather than
 * verified-and-failing. A descriptor is also a capability that **expires when
 * it is closed**.
 *
 * It also means this app no longer needs `MANAGE_EXTERNAL_STORAGE` to be backed
 * up — that permission is only still declared for the §1 broadcast path, where
 * the caller hands over an absolute `path` extra.
 */
class AutomationProvider : ContentProvider() {

    override fun onCreate(): Boolean = true

    /**
     * Every method answers a [Bundle] with [KEY_RESULT] — `OK…` or `ERROR:…`,
     * the same vocabulary the broadcast contract uses, so a caller has one
     * grammar to parse rather than two.
     *
     * A refusal is returned, never thrown: an exception across a binder reaches
     * the caller as a `RuntimeException` with our stack trace in it, which tells
     * 白い熊 nothing and tells a misbehaving caller rather more than it should.
     */
    override fun call(method: String, arg: String?, extras: Bundle?): Bundle {
        val ctx = context ?: return fail("ERROR:not ready")

        // WHO, before WHAT. A caller we cannot identify gets the same answer
        // whatever it asked for.
        when (val verdict = AutomationCallers.verify(ctx, callingPackage)) {
            is AutomationCallers.Verdict.Refused -> return fail(verdict.why)
            AutomationCallers.Verdict.Allowed -> Unit
        }
        // Then the app's own switches — a token is ignored unless this app asks
        // for one.
        SkAutomationGate.refuse(ctx, extras?.getString(KEY_TOKEN))?.let { return fail(it) }

        return when (method) {
            METHOD_DESCRIBE -> ok(describe(ctx))
            METHOD_EXPORT -> start(ctx, extras, importing = false)
            METHOD_IMPORT -> start(ctx, extras, importing = true)
            METHOD_CANCEL -> {
                val jobId = extras?.getString(KEY_JOB_ID)
                AutomationJobs.cancel(jobId)
                // The work itself is inside a Dart call by now, so the flag
                // above cannot be polled from here — the service relays the
                // stop into its own engine, exactly as the §1 receiver does.
                AutomationDataService.requestCancel(jobId)
                ok("OK:cancelled")
            }
            else -> fail("ERROR:unknown method: $method")
        }
    }

    /**
     * What this app would export, answered without exporting anything.
     *
     * Returned from the call rather than written into the archive,
     * deliberately: 応用管理 must draw a row before an export exists, and at
     * restore must judge compatibility **before** streaming megabytes into an
     * app that would reject them — which it cannot do if the header is buried
     * inside an encrypted archive.
     */
    private fun describe(ctx: Context): String {
        val pkg = ctx.packageManager.getPackageInfo(ctx.packageName, 0)
        val contains = CONTAINS.joinToString(",") { "\"$it\"" }
        return "OK:" + """
            {"app_id":"${ctx.packageName}",
             "version_code":${@Suppress("DEPRECATION") pkg.versionCode},
             "version_name":"${pkg.versionName}",
             "format":$FORMAT,
             "min_format_readable":$MIN_FORMAT_READABLE,
             "requires_launch_first":false,
             "contains":[$contains]}
        """.trimIndent().replace("\n", "")
    }

    /**
     * Hand the descriptor to a foreground service and get out of the way.
     *
     * The descriptor is **duplicated** before it leaves this method. The one in
     * [extras] belongs to the binder transaction and is closed when `call()`
     * returns; a service reading it afterwards would find it shut. That is a
     * bug you only see under load, so it is not left to the service to
     * remember.
     */
    private fun start(ctx: Context, extras: Bundle?, importing: Boolean): Bundle {
        @Suppress("DEPRECATION") // The typed overload is API 33; this works everywhere.
        val fd = extras?.getParcelable<ParcelFileDescriptor>(KEY_FD)
            ?: return fail("ERROR:no descriptor")
        val dup = runCatching { fd.dup() }.getOrNull() ?: return fail("ERROR:descriptor unusable")
        val jobId = AutomationJobs.begin()
        return runCatching {
            AutomationDataService.start(ctx, jobId, dup, importing, extras)
            ok("OK:$jobId")
        }.getOrElse { t ->
            // Nothing will ever close the copy if the service never starts.
            runCatching { dup.close() }
            AutomationJobs.finish(jobId)
            fail("ERROR:${t.message ?: t.javaClass.simpleName}")
        }
    }

    private fun ok(result: String) = Bundle().apply { putString(KEY_RESULT, result) }
    private fun fail(why: String) = Bundle().apply { putString(KEY_RESULT, why) }

    // A provider that is only ever `call()`ed still has to answer these.
    // Refusing loudly beats returning an empty cursor, which reads downstream as
    // "there is no data" rather than "wrong door".
    override fun query(u: Uri, p: Array<String>?, s: String?, a: Array<String>?, o: String?): Cursor? =
        throw UnsupportedOperationException("automation is call() only")
    override fun getType(uri: Uri): String? = null
    override fun insert(uri: Uri, values: ContentValues?): Uri? =
        throw UnsupportedOperationException("automation is call() only")
    override fun delete(uri: Uri, s: String?, a: Array<String>?): Int =
        throw UnsupportedOperationException("automation is call() only")
    override fun update(u: Uri, v: ContentValues?, s: String?, a: Array<String>?): Int =
        throw UnsupportedOperationException("automation is call() only")

    companion object {
        const val METHOD_DESCRIBE = "describe"
        const val METHOD_EXPORT = "export"
        const val METHOD_IMPORT = "import"
        const val METHOD_CANCEL = "cancel"

        const val KEY_RESULT = "result"
        const val KEY_FD = "fd"
        const val KEY_TOKEN = "token"
        const val KEY_JOB_ID = "job_id"
        const val KEY_ITEMS = "items"
        const val KEY_REPLY_ACTION = "reply_action"
        const val KEY_REPLY_PACKAGE = "reply_package"
        const val KEY_PROGRESS_ACTION = "progress_action"

        /**
         * This app's archive format — `skExportVersion` in
         * `lib/components/sk_eximport.dart`. v1 was a single JSON file; v2 is
         * the family ZIP (`manifest.json` plus one `<category id>.json`).
         * Bumped when an older build could no longer read what we write.
         */
        const val FORMAT = 2

        /**
         * The oldest archive this build can still read — v1, which
         * `skReadExportFile` still decodes.
         *
         * Version skew has a direction: old data into a newer app is normally
         * fine, because an app migrates its own storage; newer data into an
         * older app is not. This field is what lets a caller refuse the second
         * case at discovery time, before anything is streamed.
         */
        const val MIN_FORMAT_READABLE = 1

        /**
         * The short human strings 応用管理 renders verbatim on this app's row.
         *
         * These MIRROR `SkExportCat.label` in `lib/components/sk_eximport.dart`
         * — every category, in declaration order — and are duplicated here for
         * one reason: `describe` must answer inside a binder call, and asking
         * Dart would mean booting a Flutter engine per list row. **Add a
         * category there, add its label here.**
         */
        private val CONTAINS = listOf(
            "Sources (tracked apps)",
            "App settings",
            "Source credentials",
            "Categories",
            "白い熊 獲得 UI (colors · fonts · sizes)",
        )
    }
}
