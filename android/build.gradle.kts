allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

val newBuildDir: Directory =
    rootProject.layout.buildDirectory
        .dir("../../build")
        .get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}
subprojects {
    project.evaluationDependsOn(":app")
}

// Manche Flutter-Plugins (hier home_widget) kompilieren ihren Kotlin-Code noch
// gegen JVM 1.8, ziehen aber Abhängigkeiten herein, die mit JVM 11 gebaut sind:
//   "Cannot inline bytecode built with JVM target 11 into bytecode that is
//    being built with JVM target 1.8"
// Ein Upgrade des Plugins hilft nicht — auch 0.9.3 setzt noch 1.8. Deshalb
// alle Module auf 17 heben, passend zu app/build.gradle.kts. Java und Kotlin
// müssen dabei zusammenpassen, sonst bricht AGP mit
// "Inconsistent JVM-target compatibility" ab.
subprojects {
    afterEvaluate {
        extensions.findByName("android")?.let { ext ->
            (ext as com.android.build.gradle.BaseExtension).compileOptions {
                sourceCompatibility = JavaVersion.VERSION_17
                targetCompatibility = JavaVersion.VERSION_17
            }
        }
    }
    tasks.withType<org.jetbrains.kotlin.gradle.tasks.KotlinCompile>().configureEach {
        compilerOptions.jvmTarget.set(org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17)
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
