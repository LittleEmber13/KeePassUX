package com.cinderfall.keepassux

import android.app.Activity
import android.app.assist.AssistStructure
import android.content.Intent
import android.os.Build
import android.service.autofill.Dataset
import android.service.autofill.Field
import android.service.autofill.Presentations
import android.util.Log
import android.view.autofill.AutofillId
import android.view.autofill.AutofillManager
import android.view.autofill.AutofillValue
import android.widget.RemoteViews

object AutofillFiller {

    private const val TAG = "KpuxAutofillFiller"

    const val RESULT_DATASET = "dataset"
    const val RESULT_UNSUPPORTED = "unsupported"

    fun fill(activity: Activity, label: String, username: String, password: String): String {
        val structure = structureFrom(activity.intent)
        if (structure == null) {
            Log.w(TAG, "No assist structure available; cannot fill")
            return RESULT_UNSUPPORTED
        }

        val form = LoginFormInspector(structure).inspect()
        if (form == null || !form.hasPasswordField) {
            Log.w(TAG, "No fillable login form; cannot fill")
            return RESULT_UNSUPPORTED
        }

        val presentation = presentationFor(activity, label, username)
        val builder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            Dataset.Builder(
                Presentations.Builder()
                    .setMenuPresentation(presentation)
                    .setDialogPresentation(presentation)
                    .build()
            )
        } else {
            @Suppress("DEPRECATION")
            Dataset.Builder(presentation)
        }
        form.usernameField?.let { builder.setFieldValue(it, AutofillValue.forText(username)) }
        form.passwordField?.let { builder.setFieldValue(it, AutofillValue.forText(password)) }

        activity.setResult(Activity.RESULT_OK, Intent().apply {
            putExtra(AutofillManager.EXTRA_AUTHENTICATION_RESULT, builder.build())
        })
        return RESULT_DATASET
    }

    private fun structureFrom(intent: Intent?): AssistStructure? {
        if (intent == null) return null
        intent.getBundleExtra(KeepassuxAutofillService.EXTRA_STRUCTURE_BUNDLE)
            ?.getParcelable<AssistStructure>(KeepassuxAutofillService.EXTRA_STRUCTURE_COPY)
            ?.let { return it }
        return intent.extras?.getParcelable(AutofillManager.EXTRA_ASSIST_STRUCTURE)
    }

    private fun Dataset.Builder.setFieldValue(id: AutofillId, value: AutofillValue) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            setField(id, Field.Builder().setValue(value).build())
        } else {
            @Suppress("DEPRECATION")
            setValue(id, value)
        }
    }

    private fun presentationFor(activity: Activity, label: String, username: String): RemoteViews {
        val title = when {
            label.isNotEmpty() && username.isNotEmpty() -> "$label ($username)"
            label.isNotEmpty() -> label
            username.isNotEmpty() -> username
            else -> "KeepassUX"
        }
        return RemoteViews(activity.packageName, android.R.layout.simple_list_item_1).apply {
            setTextViewText(android.R.id.text1, title)
        }
    }
}
