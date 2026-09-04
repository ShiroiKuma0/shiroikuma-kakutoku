package dev.imranr.obtainium.automation

import android.content.Context
import android.util.Log
import java.security.MessageDigest

/**
 * The v2 gate — a switch that is ON, and a token that is OFF — read natively.
 *
 * ## Why this exists at all in an app whose gate lives in Dart
 *
 * This app is Flutter. The authoritative gate is [SkAutomation.refuse] in
 * `lib/providers/sk_automation.dart`: that is where the two flags are written
 * (the Export/Import rows on the 白い熊 獲得 UI page) and where the broadcast
 * receiver's requests are judged, after booting Dart anyway to run the export.
 *
 * The data door of §2a cannot wait for that. `AutomationProvider.call()` must
 * answer **synchronously and in milliseconds** — 応用管理 draws one list row
 * per installed app, and a Flutter engine boot per `describe` would turn a
 * 42-app list into three-quarters of a minute of frozen UI. So the provider
 * asks this object instead, which reads **the very same three preferences from
 * the very same file** the Dart side reads.
 *
 * That is a mirror, not a second gate: one set of keys, one set of defaults,
 * one meaning. `shared_preferences`' legacy API — the one this app uses
 * throughout — stores into `FlutterSharedPreferences` with every key prefixed
 * `flutter.`, booleans as real booleans and strings raw (only lists get an
 * encoding prefix), so the values below are exactly what Dart wrote. **If the
 * keys or defaults change on one side they must change on the other**; both
 * files say so.
 *
 * ## The v2 rules, which are the point of the whole change
 *
 * - `automation_enabled` defaults **true**. Every app answers automation out
 *   of the box, because the case this family exists to serve is a *wiped*
 *   phone where nobody has configured anything yet.
 * - `automation_require_token` defaults **false**, and is the only thing that
 *   makes a token matter.
 * - **A token sent to an app that does not require one is IGNORED, never an
 *   error.** Tokens outlive the settings they were pasted for; refusing one
 *   would turn "白い熊 turned a switch off" into "half the batch mysteriously
 *   fails", which is precisely the friction the switch exists to remove.
 */
object SkAutomationGate {

    private const val TAG = "SkAutomationGate"

    /** Flutter's own preference file, and Flutter's own key prefix. */
    private const val PREFS = "FlutterSharedPreferences"
    private const val KEY_ENABLED = "flutter.skAutomationEnabled"
    private const val KEY_REQUIRE_TOKEN = "flutter.skAutomationRequireToken"
    private const val KEY_TOKEN = "flutter.skAutomationToken"

    /** Mirrors `SkAutomation.isEnabled` — v2 default ON. */
    fun isEnabled(context: Context): Boolean =
        readBool(context, KEY_ENABLED, default = true)

    /** Mirrors `SkAutomation.requiresToken` — v2 default OFF. */
    fun requiresToken(context: Context): Boolean =
        readBool(context, KEY_REQUIRE_TOKEN, default = false)

    /**
     * null = proceed. Otherwise the exact `ERROR:` string to answer with.
     *
     * One function, both checks, exactly as the contract asks: two checks
     * written out at each entry point is how "disabled" and "bad token" drift
     * apart across forty-two apps. The two stay distinct as answers because
     * they debug differently.
     */
    fun refuse(context: Context, candidate: String?): String? {
        if (!isEnabled(context)) return "ERROR:automation disabled"
        // The token is only ever consulted when this app asks for one. Anything
        // the caller sent otherwise is simply not looked at.
        if (!requiresToken(context)) return null
        val stored = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            .getString(KEY_TOKEN, null)
        if (stored.isNullOrEmpty() || candidate.isNullOrEmpty()) return "ERROR:bad token"
        // Constant-time, like the Dart side — no early exit on the first
        // differing byte.
        return if (MessageDigest.isEqual(candidate.toByteArray(), stored.toByteArray())) {
            null
        } else {
            "ERROR:bad token"
        }
    }

    /**
     * A missing key is the default; a key of the wrong TYPE is also the default
     * rather than a crash.
     *
     * `getBoolean` on a value Dart happened to store as something else throws
     * `ClassCastException`, and a provider that throws hands the caller our
     * stack trace instead of an answer. The door failing open on its own
     * default is the correct reading of "the switch ships ON".
     */
    private fun readBool(context: Context, key: String, default: Boolean): Boolean = try {
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).getBoolean(key, default)
    } catch (t: Throwable) {
        Log.w(TAG, "$key was not a boolean — using the default ($default)", t)
        default
    }
}
