package com.srhsoftwares.mycaloriepal

import android.app.Activity
import android.os.Bundle
import androidx.activity.result.ActivityResultLauncher
import androidx.activity.result.IntentSenderRequest
import androidx.activity.result.contract.ActivityResultContracts
import androidx.core.splashscreen.SplashScreen.Companion.installSplashScreen
import com.google.android.gms.auth.api.identity.GetPhoneNumberHintIntentRequest
import com.google.android.gms.auth.api.identity.Identity
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterFragmentActivity() {
    private val phoneHintChannel = "com.srhsoftwares.mycaloriepal/phone_hint"
    private var pendingPhoneHintResult: MethodChannel.Result? = null
    private lateinit var phoneHintLauncher: ActivityResultLauncher<IntentSenderRequest>

    override fun onCreate(savedInstanceState: Bundle?) {
        phoneHintLauncher = registerForActivityResult(
            ActivityResultContracts.StartIntentSenderForResult(),
        ) { activityResult ->
            val result = pendingPhoneHintResult
            pendingPhoneHintResult = null
            if (result == null) return@registerForActivityResult

            if (activityResult.resultCode != Activity.RESULT_OK) {
                result.success(null)
                return@registerForActivityResult
            }

            try {
                val phoneNumber = Identity.getSignInClient(this)
                    .getPhoneNumberFromIntent(activityResult.data)
                result.success(phoneNumber)
            } catch (_: Exception) {
                result.success(null)
            }
        }

        installSplashScreen()
        super.onCreate(savedInstanceState)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, phoneHintChannel)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "requestHint" -> requestPhoneNumberHint(result)
                    else -> result.notImplemented()
                }
            }
    }

    private fun requestPhoneNumberHint(result: MethodChannel.Result) {
        if (pendingPhoneHintResult != null) {
            result.error("busy", "Phone hint already in progress", null)
            return
        }

        pendingPhoneHintResult = result
        val request = GetPhoneNumberHintIntentRequest.builder().build()

        Identity.getSignInClient(this)
            .getPhoneNumberHintIntent(request)
            .addOnSuccessListener { pendingIntent ->
                try {
                    phoneHintLauncher.launch(
                        IntentSenderRequest.Builder(pendingIntent).build(),
                    )
                } catch (_: Exception) {
                    pendingPhoneHintResult = null
                    result.success(null)
                }
            }
            .addOnFailureListener {
                pendingPhoneHintResult = null
                result.success(null)
            }
    }
}
