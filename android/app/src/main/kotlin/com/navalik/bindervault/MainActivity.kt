package com.navalik.bindervault

import android.os.Build
import android.os.Bundle
import androidx.activity.enableEdgeToEdge
import io.flutter.embedding.android.FlutterFragmentActivity

class MainActivity : FlutterFragmentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        enableEdgeToEdge()
        // Avoid restoring a stale Android activity state after process death.
        // External auth/billing activities can otherwise be relaunched with
        // incomplete state, causing native crashes inside Play services libs.
        super.onCreate(null)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            window.isNavigationBarContrastEnforced = false
        }
    }
}
