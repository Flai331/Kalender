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
// Plugin-Module (z.B. home_widget) bauen sonst mit dem Default-Ziel 1.8 und
// können den JVM-11-Bytecode ihrer Abhängigkeiten nicht inlinen.
// Java und Kotlin müssen dasselbe Ziel haben, sonst bricht Gradle mit
// "Inconsistent JVM-target compatibility" ab. Muss vor evaluationDependsOn
// stehen: das evaluiert die Projekte sofort, danach ist es zu spät.
subprojects {
    // Java-Ziel kommt bei AGP aus der android-Extension, nicht aus der Task.
    plugins.withId("com.android.library") {
        val androidExt = extensions.findByName("android")
        if (androidExt is com.android.build.gradle.BaseExtension) {
            androidExt.compileOptions {
                sourceCompatibility = JavaVersion.VERSION_17
                targetCompatibility = JavaVersion.VERSION_17
            }
        }
    }
    tasks.withType<org.jetbrains.kotlin.gradle.tasks.KotlinCompile>().configureEach {
        compilerOptions {
            jvmTarget.set(org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17)
        }
    }
}

subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
