plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
    id("com.google.gms.google-services")
}

android {
    namespace = "com.example.aplikasi_to_do_list"
    
    // --- SETTING SDK (WAJIB 36) ---
    compileSdk = 36
    // ------------------------------

    ndkVersion = "27.0.12077973"

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_1_8
        targetCompatibility = JavaVersion.VERSION_1_8
        isCoreLibraryDesugaringEnabled = true
    }

    kotlinOptions {
        jvmTarget = "1.8"
    }

    defaultConfig {
        applicationId = "com.example.aplikasi_to_do_list"
        
        // Minimal Android 6.0 (Marshmallow)
        minSdk = flutter.minSdkVersion 
        
        // --- KITA PAKSA JADI 36 AGAR SINKRON ---
        targetSdk = 36 
        // ---------------------------------------

        versionCode = flutter.versionCode
        versionName = flutter.versionName
        
        multiDexEnabled = true
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.0.4")
}
