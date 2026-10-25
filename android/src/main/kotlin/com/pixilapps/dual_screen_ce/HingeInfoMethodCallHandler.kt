/**
 * Copyright (c) Microsoft Corporation.
 * Licensed under the MIT License.
 */

package com.pixilapps.dual_screen_ce

import android.content.Context
import android.content.pm.PackageManager
import android.hardware.SensorManager
import android.os.Build
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/**
 * Responds to method calls about the hinge sensor. For now it can tell the caller if the device is
 * equipped with a hinge sensor.
 */
class HingeInfoMethodCallHandler(
    private val context: Context,
    private val sensorManager: SensorManager,
) : MethodChannel.MethodCallHandler {
    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "hasHingeAngleSensor" -> result.success(hasHingeAngleSensor())
            else -> result.notImplemented()
        }
    }

    // Samsung One UI exposes a TYPE_HINGE_ANGLE sensor on non-foldable phones (e.g. S24),
    // so relying on getDefaultSensor alone misreports those devices as foldable. Real
    // foldables also declare FEATURE_SENSOR_HINGE_ANGLE, which only exists from API 30.
    private fun hasHingeAngleSensor(): Boolean {
        val sensorPresent = HingeSensorResolver(sensorManager).resolve() != null
        val featureDeclared = Build.VERSION.SDK_INT < Build.VERSION_CODES.R ||
            context.packageManager.hasSystemFeature(PackageManager.FEATURE_SENSOR_HINGE_ANGLE)
        return sensorPresent && featureDeclared
    }
}