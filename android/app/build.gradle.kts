import java.io.FileInputStream
import java.net.NetworkInterface
import java.util.Properties

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val keystorePropertiesFile = rootProject.file("key.properties")
val keystoreProperties = Properties().apply {
    if (keystorePropertiesFile.exists()) load(FileInputStream(keystorePropertiesFile))
}

android {
    namespace = "sy.msd.msd_mobile"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "sy.msd.msd_mobile"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        create("release") {
            if (keystorePropertiesFile.exists()) {
                keyAlias = keystoreProperties.getProperty("keyAlias")
                keyPassword = keystoreProperties.getProperty("keyPassword")
                storeFile = file(keystoreProperties.getProperty("storeFile"))
                storePassword = keystoreProperties.getProperty("storePassword")
            }
        }
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("release")
        }
    }

    // Debug packaging uses the generated file so cleartext stays limited to
    // loopback, the emulator, and this machine's private LAN addresses.
    sourceSets.named("debug") {
        res.setSrcDirs(listOf(file("src/debug/res-none")))
        res.srcDir(layout.buildDirectory.dir("generated/res/debugCleartext"))
    }
}

val generateDebugNetworkSecurity = tasks.register("generateDebugNetworkSecurity") {
    val outDir = layout.buildDirectory.dir("generated/res/debugCleartext")
    outputs.dir(outDir)
    doLast {
        val xmlDir = outDir.get().asFile.resolve("xml")
        xmlDir.mkdirs()
        val hosts = linkedSetOf("localhost", "127.0.0.1", "10.0.2.2", "10.0.3.2")
        val interfaces = NetworkInterface.getNetworkInterfaces()
        while (interfaces.hasMoreElements()) {
            val nic = interfaces.nextElement()
            val addresses = nic.inetAddresses
            while (addresses.hasMoreElements()) {
                val raw = addresses.nextElement().hostAddress ?: continue
                val ip = raw.substringBefore('%')
                if (isPrivateLanHost(ip)) hosts.add(ip)
            }
        }
        val domains = hosts.joinToString("\n") { host ->
            val sub = if (host == "localhost") "true" else "false"
            "        <domain includeSubdomains=\"$sub\">$host</domain>"
        }
        xmlDir.resolve("network_security_config.xml").writeText(
            """
            |<?xml version="1.0" encoding="utf-8"?>
            |<network-security-config>
            |    <base-config cleartextTrafficPermitted="false">
            |        <trust-anchors>
            |            <certificates src="system" />
            |            <certificates src="user" />
            |        </trust-anchors>
            |    </base-config>
            |    <domain-config cleartextTrafficPermitted="true">
            |$domains
            |    </domain-config>
            |</network-security-config>
            """.trimMargin() + "\n",
        )
    }
}

fun isPrivateLanHost(ip: String): Boolean {
    val parts = ip.split('.')
    if (parts.size != 4) return false
    val numbers = parts.map { it.toIntOrNull() ?: return false }
    if (numbers.any { it !in 0..255 }) return false
    val a = numbers[0]
    val b = numbers[1]
    return a == 10 || a == 127 || (a == 192 && b == 168) || (a == 172 && b in 16..31) || (a == 169 && b == 254)
}

tasks.named("preBuild").configure {
    dependsOn(generateDebugNetworkSecurity)
}

gradle.taskGraph.whenReady {
    val wantsRelease = allTasks.any { it.name.contains("Release") && (it.name.startsWith("assemble") || it.name.startsWith("bundle")) }
    if (wantsRelease && !keystorePropertiesFile.exists()) {
        throw GradleException("android/key.properties is missing — release builds must be signed with the upload key.")
    }
}

flutter {
    source = "../.."
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}
