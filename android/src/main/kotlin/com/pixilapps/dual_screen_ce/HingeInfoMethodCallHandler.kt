/**
 * Copyright (c) Microsoft Corporation.
 * Licensed under the MIT License.
 */

package com.pixilapps.dual_screen_ce

import android.content.Context
import android.content.pm.PackageManager
import android.hardware.SensorManager
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
    // foldable also declare the FEATURE_SENSOR_HINGE_ANGLE system feature; require both.
    private fun hasHingeAngleSensor(): Boolean {
        val sensorPresent = HingeSensorResolver(sensorManager).resolve() != null
        val featureDeclared = context.packageManager.hasSystemFeature(PackageManager.FEATURE_SENSOR_HINGE_ANGLE)
        return sensorPresent && featureDeclared
    }
}