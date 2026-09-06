package com.jaytech.jaypos

import android.app.Application
import androidx.multidex.MultiDex

class JayPOSApplication : Application() {
    override fun onCreate() {
        super.onCreate()
        MultiDex.install(this)
    }
}
