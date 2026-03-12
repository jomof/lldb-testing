package com.example.testapp

import androidx.appcompat.app.AppCompatActivity
import android.os.Bundle
import android.widget.TextView
import com.example.testapp.databinding.ActivityMainBinding

class MainActivity : AppCompatActivity() {

    private lateinit var binding: ActivityMainBinding
    private val handler = android.os.Handler(android.os.Looper.getMainLooper())
    private val runnable = object : Runnable {
        override fun run() {
            binding.sampleText.text = stringFromJNI()
            handler.postDelayed(this, 100)
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        binding = ActivityMainBinding.inflate(layoutInflater)
        setContentView(binding.root)

        handler.post(runnable)
    }

    override fun onDestroy() {
        super.onDestroy()
        handler.removeCallbacks(runnable)
    }
    /**
      * A native method that is implemented by the 'testapp' native library,
      * which is packaged with this application.
      */
     external fun stringFromJNI(): String

     companion object {
         // Used to load the 'testapp' library on application startup.
         init {
             System.loadLibrary("testapp")
         }
     }
}