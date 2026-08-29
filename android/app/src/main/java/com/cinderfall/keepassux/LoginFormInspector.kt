package com.cinderfall.keepassux

import android.app.assist.AssistStructure
import android.os.Build
import android.text.InputType
import android.util.Log
import android.view.View
import android.view.autofill.AutofillId
import java.util.Locale

class LoginForm(
    val appPackage: String?,
    val webDomain: String?,
    val webScheme: String?,
    val usernameField: AutofillId?,
    val passwordField: AutofillId?,
    val usernameText: String?,
    val passwordText: String?,
) {
    val hasPasswordField: Boolean get() = passwordField != null

    fun fillTargets(): Array<AutofillId> =
        listOfNotNull(usernameField, passwordField).toTypedArray()
}

class LoginFormInspector(private val structure: AssistStructure) {

    private enum class Role { USERNAME, USERNAME_GUESS, VISIBLE_PASSWORD, PASSWORD, OTP, NONE }

    private class Candidate(
        val id: AutofillId,
        val role: Role,
        val order: Int,
        val text: String?,
    )

    private val candidates = mutableListOf<Candidate>()
    private var appPackage: String? = null
    private var webDomain: String? = null
    private var webScheme: String? = null
    private var captureText = false

    fun inspect(captureText: Boolean = false): LoginForm? {
        this.captureText = captureText
        return try {
            for (i in 0 until structure.windowNodeCount) {
                val window = structure.getWindowNodeAt(i)
                val title = window.title?.toString().orEmpty()
                if (title.contains(POPUP_WINDOW_MARKER)) continue
                if (appPackage == null) {
                    appPackage = title.substringBefore('/').takeIf { it.isNotEmpty() }
                }
                visit(window.rootViewNode)
            }
            assemble()
        } catch (e: Exception) {
            Log.e(TAG, "Could not inspect assist structure", e)
            null
        }
    }

    private fun visit(node: AssistStructure.ViewNode) {
        if (webDomain == null) {
            node.webDomain?.takeIf { it.isNotEmpty() }?.let { webDomain = it }
        }
        if (webScheme == null && Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
            node.webScheme?.takeIf { it.isNotEmpty() }?.let { webScheme = it }
        }

        if (node.visibility != View.VISIBLE) return

        val id = node.autofillId
        if (id != null) {
            val role = classify(node)
            if (role != Role.NONE && role != Role.OTP) {
                candidates += Candidate(id, role, candidates.size, textValueOf(node))
            }
        }
        for (i in 0 until node.childCount) {
            visit(node.getChildAt(i))
        }
    }

    private fun classify(node: AssistStructure.ViewNode): Role {
        val hints = node.autofillHints
            ?.filterNotNull()
            ?.map { it.lowercase(Locale.ROOT) }
            .orEmpty()
        val html = htmlInputAttributes(node)

        if (hints.any { hint -> OTP_HINT_FRAGMENTS.any { it in hint } }) return Role.OTP
        if (html != null && isOtpWebField(html)) return Role.OTP

        if (hints.any { "password" in it }) return Role.PASSWORD
        if (html?.get("type") == "password") return Role.PASSWORD
        if (matchesInput(node, InputType.TYPE_CLASS_TEXT,
                InputType.TYPE_TEXT_VARIATION_PASSWORD,
                InputType.TYPE_TEXT_VARIATION_WEB_PASSWORD)
        ) return Role.PASSWORD
        if (matchesInput(node, InputType.TYPE_CLASS_NUMBER,
                InputType.TYPE_NUMBER_VARIATION_PASSWORD)
        ) return Role.PASSWORD

        if (hints.any { hint -> USERNAME_HINT_FRAGMENTS.any { it in hint } }) return Role.USERNAME
        if (html?.get("type") == "email" || html?.get("type") == "tel") return Role.USERNAME
        if (matchesInput(node, InputType.TYPE_CLASS_TEXT,
                InputType.TYPE_TEXT_VARIATION_EMAIL_ADDRESS,
                InputType.TYPE_TEXT_VARIATION_WEB_EMAIL_ADDRESS)
        ) return Role.USERNAME

        if (matchesInput(node, InputType.TYPE_CLASS_TEXT,
                InputType.TYPE_TEXT_VARIATION_VISIBLE_PASSWORD)
        ) return Role.VISIBLE_PASSWORD

        if (hints.any { "phone" in it }) return Role.USERNAME_GUESS
        if (html?.get("type") == "text") return Role.USERNAME_GUESS
        if (matchesInput(node, InputType.TYPE_CLASS_TEXT,
                InputType.TYPE_TEXT_VARIATION_NORMAL,
                InputType.TYPE_TEXT_VARIATION_PERSON_NAME,
                InputType.TYPE_TEXT_VARIATION_WEB_EDIT_TEXT)
        ) return Role.USERNAME_GUESS
        if (matchesInput(node, InputType.TYPE_CLASS_NUMBER,
                InputType.TYPE_NUMBER_VARIATION_NORMAL)
        ) return Role.USERNAME_GUESS
        if (node.inputType and InputType.TYPE_MASK_CLASS == InputType.TYPE_NULL
            && node.className == "android.widget.EditText"
        ) return Role.USERNAME_GUESS

        return Role.NONE
    }

    private fun assemble(): LoginForm {
        var password = candidates.firstOrNull { it.role == Role.PASSWORD }
        var visibleAsUsername: Candidate? = null

        if (password == null) {
            val visible = candidates.filter { it.role == Role.VISIBLE_PASSWORD }
            when {
                visible.size >= 2 -> {
                    visibleAsUsername = visible[0]
                    password = visible[1]
                }
                visible.size == 1 -> {
                    val hasTextFieldBefore = candidates.any {
                        it.order < visible[0].order &&
                                (it.role == Role.USERNAME || it.role == Role.USERNAME_GUESS)
                    }
                    if (hasTextFieldBefore) password = visible[0]
                }
            }
        }

        val username = if (password == null) {
            candidates.lastOrNull { it.role == Role.USERNAME }
        } else {
            candidates.lastOrNull { it.role == Role.USERNAME && it.order < password.order }
                ?: visibleAsUsername
                ?: candidates.lastOrNull { it.role == Role.USERNAME_GUESS && it.order < password.order }
                ?: candidates.firstOrNull { it.role == Role.USERNAME }
        }

        return LoginForm(
            appPackage = appPackage,
            webDomain = webDomain,
            webScheme = webScheme,
            usernameField = username?.id,
            passwordField = password?.id,
            usernameText = username?.text,
            passwordText = password?.text,
        )
    }

    private fun htmlInputAttributes(node: AssistStructure.ViewNode): Map<String, String>? {
        val info = node.htmlInfo ?: return null
        if (!info.tag.equals("input", ignoreCase = true)) return null
        return info.attributes?.associate {
            it.first.lowercase(Locale.ROOT) to (it.second ?: "").lowercase(Locale.ROOT)
        }
    }

    private fun isOtpWebField(attributes: Map<String, String>): Boolean =
        listOfNotNull(attributes["id"], attributes["name"]).any { value ->
            OTP_TOKEN_FRAGMENTS.any { it in value } || value in OTP_EXACT_TOKENS
        }

    private fun matchesInput(
        node: AssistStructure.ViewNode,
        inputClass: Int,
        vararg variations: Int,
    ): Boolean {
        val type = node.inputType
        if (type and InputType.TYPE_MASK_CLASS != inputClass) return false
        val variation = type and InputType.TYPE_MASK_VARIATION
        return variations.any { it == variation }
    }

    private fun textValueOf(node: AssistStructure.ViewNode): String? {
        if (!captureText) return null
        val value = node.autofillValue ?: return null
        return if (value.isText) value.textValue.toString() else null
    }

    companion object {
        private const val TAG = "KpuxFormInspector"

        const val POPUP_WINDOW_MARKER = "PopupWindow:"

        private val OTP_HINT_FRAGMENTS = setOf("otp", "one-time")
        private val USERNAME_HINT_FRAGMENTS = setOf("username", "email", "login")
        private val OTP_TOKEN_FRAGMENTS =
            setOf("otp", "2fa", "mfa", "twofa", "twofactor", "two-factor")
        private val OTP_EXACT_TOKENS =
            setOf("auth", "challenge", "code", "token", "idvpin", "verification_pin", "2fpin")
    }
}
