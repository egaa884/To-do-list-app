buildscript {
    repositories {
        google()
        mavenCentral()
    }
    dependencies {
        // --- TAMBAHAN PENTING (JANGAN DIHAPUS) ---
        // 1. Tiket Masuk Firebase
        classpath("com.google.gms:google-services:4.4.2")
        
        // 2. Tiket Utama Android (Wajib ada)
        classpath("com.android.tools.build:gradle:8.2.1") 
        
        // 3. Tiket Bahasa Kotlin (Wajib ada)
        classpath("org.jetbrains.kotlin:kotlin-gradle-plugin:1.8.22")
        // -------------------------------------------
    }
}

allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

val newBuildDir: Directory = rootProject.layout.buildDirectory.dir("../../build").get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}
subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}