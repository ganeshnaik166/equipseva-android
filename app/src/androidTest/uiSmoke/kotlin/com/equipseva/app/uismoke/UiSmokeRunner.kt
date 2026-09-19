package com.equipseva.app.uismoke

import android.app.Application
import android.content.Context
import android.os.Bundle
import androidx.test.runner.AndroidJUnitRunner
import dagger.hilt.android.testing.HiltTestApplication

class UiSmokeRunner : AndroidJUnitRunner() {
    override fun newApplication(cl: ClassLoader, className: String, context: Context): Application {
        check(context.packageName == TARGET_PACKAGE) { "Refusing a non-isolated target package" }
        return super.newApplication(cl, HiltTestApplication::class.java.name, context)
    }

    override fun onCreate(arguments: Bundle) {
        val selected = arguments.getString("class")
        check(selected == null || selected.split(',').all { it.startsWith("$TEST_PACKAGE.") }) {
            "Only isolated UI smoke tests may run through this runner"
        }
        val selectedPackage = arguments.getString("package")
        check(selectedPackage == null || selectedPackage == TEST_PACKAGE)
        arguments.putString("package", TEST_PACKAGE)
        super.onCreate(arguments)
    }

    private companion object {
        const val TARGET_PACKAGE = "com.equipseva.app.uismoke"
        const val TEST_PACKAGE = "com.equipseva.app.uismoke"
    }
}
