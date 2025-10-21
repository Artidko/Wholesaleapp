plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.android")
    id("com.google.gms.google-services")      // FlutterFire
    id("dev.flutter.flutter-gradle-plugin")   // ต้องตามหลัง Android/Kotlin
}

android {
    namespace = "com.example.flutter_application_2"

    compileSdk = 35
    // มี NDK r27 จริงค่อยเปิด ใช้เมื่อจำเป็นเท่านั้น
    // ndkVersion = "27.0.12077973"

    defaultConfig {
        applicationId = "com.example.flutter_application_2"
        minSdk = 23
        targetSdk = 35

        versionCode = flutter.versionCode
        versionName = flutter.versionName

        multiDexEnabled = true
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }
    kotlinOptions { jvmTarget = "17" }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("debug")
            // เปิดตอนทำโปรดักชัน
            // isMinifyEnabled = true
            // isShrinkResources = true
        }
    }

    packaging {
        resources { excludes += "/META-INF/{AL2.0,LGPL2.1}" }
    }
}

flutter { source = "../.." }

dependencies {
    implementation("androidx.multidex:multidex:2.0.1")
}
