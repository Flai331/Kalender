allprojects {
    repositories {
        google()
        mavenCentral()
    }
    // home_widget 0.9.1 fordert seine Android-Bibliotheken mit Platzhalter-Versionen
    // an ("androidx.glance:glance-appwidget:1.+", "androidx.work:work-runtime-ktx:2.+",
    // "kotlinx-coroutines-android:1.+"). Gradle nimmt dann die neueste Version samt
    // Alpha-Releases, aktuell glance 1.3.0-alpha02: braucht Android-Gradle-Plugin 9.1
    // und compileSdk 37, der Build bricht ab - und ändert sich mit jedem neuen Release.
    // Nur solche Platzhalter-Anfragen werden auf eine feste, stabile Version gesetzt;
    // ausdrücklich angeforderte Versionen bleiben unberührt.
    configurations.all {
        resolutionStrategy.eachDependency {
            val angefragt = requested.version
            if (angefragt != null && angefragt.endsWith("+")) {
                when {
                    requested.group == "androidx.glance" -> useVersion("1.1.1")
                    requested.group == "androidx.work" -> useVersion("2.10.0")
                    requested.group == "org.jetbrains.kotlinx" && requested.name.startsWith("kotlinx-coroutines") ->
                        useVersion("1.10.2")
                }
            }
        }
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
// Das Java-Ziel muss NACH dem build.gradle des Plugins gesetzt werden: das
// setzt sein compileOptions selbst (auf 1.8) und überschreibt alles, was vorher
// über plugins.withId gesetzt wurde. Das ergab "Inconsistent JVM-target
// compatibility ... 'compileReleaseJavaWithJavac' (1.8) and
// 'compileReleaseKotlin' (17)". Also afterEvaluate, registriert vor der
// Auswertung des Moduls (dieser Block steht deshalb vor evaluationDependsOn).
// Ist ein Modul schon ausgewertet, wäre afterEvaluate ein Fehler ("Cannot run
// Project.afterEvaluate when the project is already evaluated") - dann wird
// direkt gesetzt (betrifft nur :app, dessen Ziel schon 17 ist).
subprojects {
    fun javaZiel17() {
        val ext = extensions.findByName("android")
        if (ext is com.android.build.gradle.BaseExtension) {
            ext.compileOptions {
                sourceCompatibility = JavaVersion.VERSION_17
                targetCompatibility = JavaVersion.VERSION_17
            }
        }
    }
    if (state.executed) javaZiel17() else afterEvaluate { javaZiel17() }
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
