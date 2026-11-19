package com.example.udm_frontend

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.scer.pdfx.PdfxPlugin

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // Some cached Flutter engines skip the generated registration step.
        // Register pdfx here when it was not attached by the normal registrant.
        if (!flutterEngine.plugins.has(PdfxPlugin::class.java)) {
            flutterEngine.plugins.add(PdfxPlugin())
        }
    }
}
