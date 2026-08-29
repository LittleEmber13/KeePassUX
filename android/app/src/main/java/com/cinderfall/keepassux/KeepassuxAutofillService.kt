package com.cinderfall.keepassux

import android.annotation.SuppressLint
import android.app.PendingIntent
import android.app.assist.AssistStructure
import android.content.ComponentName
import android.content.Intent
import android.content.IntentSender
import android.content.pm.PackageManager
import android.os.Build
import android.os.Bundle
import android.os.CancellationSignal
import android.service.autofill.AutofillService
import android.service.autofill.Dataset
import android.service.autofill.FillCallback
import android.service.autofill.FillRequest
import android.service.autofill.FillRequest.FLAG_COMPATIBILITY_MODE_REQUEST
import android.service.autofill.FillResponse
import android.service.autofill.InlinePresentation
import android.service.autofill.Presentations
import android.service.autofill.SaveCallback
import android.service.autofill.SaveInfo
import android.service.autofill.SaveRequest
import android.util.Log
import android.view.autofill.AutofillId
import com.keevault.flutter_autofill_service.AutofillPreferenceStore
import com.keevault.flutter_autofill_service.InlinePresentationHelper
import com.keevault.flutter_autofill_service.IntentHelpers
import com.keevault.flutter_autofill_service.RemoteViewsHelper
import com.keevault.flutter_autofill_service.SaveInfoMetadata
import com.keevault.flutter_autofill_service.WebDomain
import kotlin.random.Random

class KeepassuxAutofillService : AutofillService() {

    companion object {
        private const val TAG = "KpuxAutofill"
        private const val STATE_COMPAT_MODE = "isCompatMode"

        const val EXTRA_STRUCTURE_BUNDLE = "com.cinderfall.keepassux.autofill.BUNDLE"
        const val EXTRA_STRUCTURE_COPY = "com.cinderfall.keepassux.autofill.ASSIST_STRUCTURE"
    }

    private val excludedPackages = listOf(
        "com.cinderfall.keepassux",
        "android",
        "com.android.settings",
        "com.oneplus.applocker",
    )

    private lateinit var preferenceStore: AutofillPreferenceStore
    private var unlockLabel = "KeepassUX"
    private var unlockDrawableId = 0

    override fun onCreate() {
        super.onCreate()
        preferenceStore = AutofillPreferenceStore.getInstance(applicationContext)
        unlockLabel = getString(R.string.autofill_unlock_label)
    }

    override fun onConnected() {
        super.onConnected()
        val metaData = packageManager.getServiceInfo(
            ComponentName(this, javaClass), PackageManager.GET_META_DATA
        ).metaData
        metaData.getString("com.keevault.flutter_autofill_service.unlock_label")?.let {
            unlockLabel = it
        }
        metaData.getString("com.keevault.flutter_autofill_service.unlock_drawable_name")?.let {
            unlockDrawableId = resources.getIdentifier(it, "drawable", packageName)
        }
    }

    override fun onFillRequest(
        request: FillRequest,
        cancellationSignal: CancellationSignal,
        callback: FillCallback,
    ) {
        cancellationSignal.setOnCancelListener { Log.w(TAG, "Fill request cancelled") }

        val structure = request.fillContexts.last().structure
        val form = LoginFormInspector(structure).inspect()
        if (form == null || !form.hasPasswordField || !isFillablePackage(form.appPackage)) {
            callback.onSuccess(null)
            return
        }
        Log.i(TAG, "Login form found: app=${form.appPackage} domain=${form.webDomain}")

        val intentSender = selectionIntentSender(form, structure)
        if (intentSender == null) {
            callback.onFailure("Could not prepare the credential picker")
            return
        }

        val compatMode = request.flags and FLAG_COMPATIBILITY_MODE_REQUEST != 0
        val responseBuilder = FillResponse.Builder()
            .setClientState(Bundle().apply { putBoolean(STATE_COMPAT_MODE, compatMode) })
        saveInfoFor(form)?.let { responseBuilder.setSaveInfo(it) }
        responseBuilder.addDataset(unlockDataset(request, form.fillTargets(), intentSender))

        try {
            callback.onSuccess(responseBuilder.build())
        } catch (e: Exception) {
            Log.e(TAG, "Could not deliver fill response", e)
            callback.onSuccess(null)
        }
    }

    override fun onSaveRequest(request: SaveRequest, callback: SaveCallback) {
        var username: String? = null
        var password: String? = null
        var appPackage: String? = null
        var domain: String? = null
        var scheme: String? = null

        for (context in request.fillContexts.asReversed()) {
            val form = LoginFormInspector(context.structure)
                .inspect(captureText = true) ?: continue
            username = username ?: form.usernameText
            password = password ?: form.passwordText
            appPackage = appPackage ?: form.appPackage
            domain = domain ?: form.webDomain
            scheme = scheme ?: form.webScheme
            if (username != null && password != null) break
        }

        if ((username == null && password == null) || !isFillablePackage(appPackage)) {
            callback.onFailure("Saving form values is not allowed")
            return
        }

        val clientState = request.clientState ?: Bundle()
        val saveIntent = IntentHelpers.getStartIntent(
            activityName(),
            setOfNotNull(appPackage),
            domain?.let { setOf(WebDomain(scheme, it)) } ?: setOf(),
            applicationContext,
            "/autofill_save",
            SaveInfoMetadata(
                username,
                password,
                if (clientState.containsKey(STATE_COMPAT_MODE)) {
                    clientState.getBoolean(STATE_COMPAT_MODE)
                } else {
                    null
                }
            )
        )
        saveIntent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        startActivity(saveIntent)

        callback.onSuccess()
    }

    private fun saveInfoFor(form: LoginForm): SaveInfo? {
        if (!preferenceStore.autofillPreferences.enableSaving) return null
        val passwordId = form.passwordField ?: return null

        var types = SaveInfo.SAVE_DATA_TYPE_GENERIC or SaveInfo.SAVE_DATA_TYPE_PASSWORD
        val requiredIds = mutableListOf<AutofillId>()
        form.usernameField?.let {
            types = types or SaveInfo.SAVE_DATA_TYPE_USERNAME
            requiredIds.add(it)
        }
        requiredIds.add(passwordId)
        return SaveInfo.Builder(types, requiredIds.toTypedArray()).build()
    }

    private fun unlockDataset(
        request: FillRequest,
        fillTargets: Array<AutofillId>,
        intentSender: IntentSender,
    ): Dataset {
        val menuPresentation = RemoteViewsHelper.viewsWithAuth(
            packageName, unlockLabel, unlockDrawableId
        )
        val inlinePresentation = inlinePresentationFor(request)

        val builder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            Dataset.Builder(
                Presentations.Builder()
                    .setMenuPresentation(menuPresentation)
                    .setDialogPresentation(menuPresentation)
                    .also { presentations ->
                        inlinePresentation?.let { presentations.setInlinePresentation(it) }
                    }
                    .build()
            )
        } else {
            @Suppress("DEPRECATION")
            Dataset.Builder(menuPresentation).also { datasetBuilder ->
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                    inlinePresentation?.let { datasetBuilder.setInlinePresentation(it) }
                }
            }
        }

        // Null values: the dataset only declares which fields it will fill; the
        // real values arrive later through EXTRA_AUTHENTICATION_RESULT.
        fillTargets.forEach { id ->
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                builder.setField(id, null)
            } else {
                @Suppress("DEPRECATION")
                builder.setValue(id, null)
            }
        }
        builder.setAuthentication(intentSender)
        return builder.build()
    }

    private fun inlinePresentationFor(request: FillRequest): InlinePresentation? {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.S) return null
        if (!preferenceStore.autofillPreferences.enableIMERequests) return null
        val inlineRequest = request.inlineSuggestionsRequest ?: return null
        if (inlineRequest.maxSuggestionCount < 1) return null
        return InlinePresentationHelper.viewsWithAuth(
            unlockLabel,
            inlineRequest.inlinePresentationSpecs.first(),
            null,
            this,
            unlockDrawableId,
            false
        )
    }

    private fun selectionIntentSender(
        form: LoginForm,
        structure: AssistStructure,
    ): IntentSender? {
        val baseIntent = IntentHelpers.getStartIntent(
            activityName(),
            setOfNotNull(form.appPackage),
            form.webDomain?.let { setOf(WebDomain(form.webScheme, it)) } ?: setOf(),
            applicationContext,
            "/autofill",
            null
        )
        // PendingIntent creation can fail when the structure parcel is too large
        // (huge web pages); retry without our copy — the platform still delivers
        // its own EXTRA_ASSIST_STRUCTURE to the activity.
        val withStructure = Intent(baseIntent).putExtra(
            EXTRA_STRUCTURE_BUNDLE,
            Bundle().apply { putParcelable(EXTRA_STRUCTURE_COPY, structure) }
        )
        for (intent in listOf(withStructure, baseIntent)) {
            try {
                return activityPendingIntent(intent).intentSender
            } catch (e: RuntimeException) {
                Log.w(TAG, "Selection intent rejected, retrying without structure copy", e)
            }
        }
        return null
    }

    @SuppressLint("UnspecifiedImmutableFlag")
    private fun activityPendingIntent(intent: Intent): PendingIntent {
        // Must stay mutable: the platform appends the authentication extras.
        val flags = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            PendingIntent.FLAG_CANCEL_CURRENT or PendingIntent.FLAG_MUTABLE
        } else {
            PendingIntent.FLAG_CANCEL_CURRENT
        }
        return PendingIntent.getActivity(this, Random.nextInt(0, Int.MAX_VALUE), intent, flags)
    }

    private fun activityName(): String =
        packageManager.getApplicationInfo(packageName, PackageManager.GET_META_DATA)
            .metaData.getString("com.keevault.flutter_autofill_service.ACTIVITY_NAME")
            ?: "com.cinderfall.keepassux.AutofillActivity"

    private fun isFillablePackage(packageName: String?): Boolean =
        packageName == null || packageName !in excludedPackages
}
