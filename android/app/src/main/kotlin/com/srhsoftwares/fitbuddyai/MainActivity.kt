package com.srhsoftwares.fitbuddyai

import android.os.Bundle
import androidx.core.splashscreen.SplashScreen.Companion.installSplashScreen
import io.flutter.embedding.android.FlutterFragmentActivity

class MainActivity : FlutterFragmentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        // Keep the native splash up until Flutter draws its first frame.
        installSplashScreen()
        super.onCreate(savedInstanceState)
    }
}
