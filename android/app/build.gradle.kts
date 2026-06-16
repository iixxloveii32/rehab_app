plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.example.rehab_app"

    // android:attr/lStar not found 오류 해결을 위해 compileSdk를 명시적으로 올림
    compileSdk = 35

    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        // TODO: 정식 배포 전에는 고유한 applicationId로 변경 권장
        applicationId = "com.example.rehab_app"

        // Isar 및 최신 Android 리소스 호환성을 위해 minSdk를 명시
        minSdk = flutter.minSdkVersion

        // 교수님 검토용 APK 빌드 기준
        targetSdk = 35

        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            // 교수님 검토용 APK: 우선 debug signing으로 release APK 생성
            // Play Store 배포 시에는 별도 release signingConfig 설정 필요
            signingConfig = signingConfigs.getByName("debug")

            // 현재는 난독화/리소스 축소 비활성화
            isMinifyEnabled = false
            isShrinkResources = false
        }
    }
}

flutter {
    source = "../.."
}
