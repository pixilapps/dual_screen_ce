/**
 * Copyright (c) Microsoft Corporation.
 * Licensed under the MIT License.
 */

package com.pixilapps.dual_screen_ce

import android.hardware.Sensor
import android.hardware.SensorEvent
import android.hardware.SensorEventListener
import io.flutter.plugin.common.EventChannel

/**
 * Converts [SensorEventListener] events to [EventChannel.EventSink] events.
 */
class SensorListenerToEventSink(private val eventSink: EventChannel.EventSink) : SensorEventListener {
    override fun onAccuracyChanged(sensor: Sensor?, accuracy: Int) {
        // no-op
    }

    override fun onSensorChanged(event: SensorEvent?) {
        event?.let {
            this.eventSink.success(it.values[0])
        }
    }
}