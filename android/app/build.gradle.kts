plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// ─────────────────────────────────────────────────────────────────────────
// GESTIONE KEYSTORE DI PRODUZIONE
// Legge i segreti crittografici dal file key.properties, se esiste.
// In locale non esisterà (useremo debug), in CI/CD verrà creato dalla pipeline.
// ─────────────────────────────────────────────────────────────────────────
def keystoreProperties = new Properties()
def keystorePropertiesFile = rootProject.file('key.properties')
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(new FileInputStream(keystorePropertiesFile))
}

android {
    namespace = "com.example.packlog"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.example.packlog"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    // ─────────────────────────────────────────────────────────────────────────
    // FLAVOR DIMENSIONS
    // Definisce l'asse di variazione degli ambienti. Ogni flavor deve
    // appartenere esattamente a una dimension: questo ci protegge da
    // combinazioni di build ambigue in futuro (es. "env + tier").
    // ─────────────────────────────────────────────────────────────────────────
    flavorDimensions += "app_environment"

    productFlavors {
        // ── DEV ──────────────────────────────────────────────────────────────
        // Installabile in parallelo alla build prod grazie all'applicationIdSuffix.
        // Il suffisso ".dev" garantisce che i due APK non si sovrascrivano sul
        // dispositivo del developer, preservando i dati di produzione.
        create("dev") {
            dimension = "app_environment"
            applicationIdSuffix = ".dev"
            // resValue inietta la stringa nell'R.string generato dal flavor,
            // sovrascrivendo l'eventuale valore in res/values/strings.xml.
            resValue("string", "app_name", "PackLog Dev")
        }

        // ── PROD ─────────────────────────────────────────────────────────────
        // Build destinata agli utenti finali: nessun suffisso all'applicationId,
        // nome pulito senza indicatori di ambiente.
        create("prod") {
            dimension = "app_environment"
            resValue("string", "app_name", "PackLog")
        }
    }


    signingConfigs {
        release {
            // Controlla se abbiamo caricato i dati dal file properties
            if (keystorePropertiesFile.exists()) {
                keyAlias = keystoreProperties['keyAlias']
                keyPassword = keystoreProperties['keyPassword']
                storeFile = file(keystoreProperties['storeFile'])
                storePassword = keystoreProperties['storePassword']
            }
        }
    }

    buildTypes {
        release {
            // Diciamo ad Android di usare la configurazione appena creata
            // Invece di usare signingConfigs.getByName("debug")
            signingConfig = signingConfigs.release
            
            // Best practice enterprise: abilitiamo R8 (ProGuard) per offuscare 
            // e rimpicciolire l'APK di produzione, eliminando codice morto.
            minifyEnabled true
            shrinkResources true
            proguardFiles getDefaultProguardFile('proguard-android-optimize.txt'), 'proguard-rules.pro'
        }
    }
}


flutter {
    source = "../.."
}
