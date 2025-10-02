package com.example.hellotermuxapp

import android.os.Bundle
import androidx.appcompat.app.AppCompatActivity
import com.example.hellotermuxapp.databinding.ActivityMainBinding

class MainActivity : AppCompatActivity() {
    private lateinit var binding: ActivityMainBinding

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        binding = ActivityMainBinding.inflate(layoutInflater)
        setContentView(binding.root)

        binding.helloText.text = "Hello from Termux!"
    }
}
