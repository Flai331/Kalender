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
// Manche Flutter-Plugins (hier home_widget) kompilieren ihren Kotlin-Code noch
// gegen JVM 1.8, ziehen aber Abhängigkeiten herein, die mit JVM 11 gebaut sind:
//   "Cannot inline bytecode built with JVM target 11 into bytecode that is
//    being built with JVM target 1.8"
// Ein Upgrade des Plugins hilft nicht — auch home_widget 0.9.3 setzt noch 1.8.
// Deshalb alle Module auf 17 heben, passend zu app/build.gradle.kts. Java und
// Kotlin müssen zusammenpassen, sonst bricht AGP mit
// "Inconsistent JVM-target compatibility" ab.
//
// Bewusst über plugins.withId statt afterEvaluate: der evaluationDependsOn-
// Block unten wertet :app vorzeitig aus, ein späteres afterEvaluate scheitert
// dann mit "Cannot run Project.afterEvaluate when the project is already
// evaluated".
subprojects {
    listOf("com.android.application", "com.android.library").forEach { pluginId ->
        plugins.withId(pluginId) {
            extensions.configure(com.android.build.gradle.BaseExtension::class.java) {
                compileOptions {
                    sourceCompatibility = JavaVersion.VERSION_17
                    targetCompatibility = JavaVersion.VERSION_17
                }
            }
        }
    }
    tasks.withType<org.jetbrains.kotlin.gradle.tasks.KotlinCompile>().configureEach {
        compilerOptions.jvmTarget.set(org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17)
    }
}

subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
