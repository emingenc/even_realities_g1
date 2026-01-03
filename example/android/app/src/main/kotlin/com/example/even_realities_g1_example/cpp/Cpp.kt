package com.example.even_realities_g1_example.cpp

object Cpp {
    init {
        System.loadLibrary("lc3")
    }

    fun init() {}

    @JvmStatic
    external fun decodeLC3(lc3Data: ByteArray?): ByteArray?
}
