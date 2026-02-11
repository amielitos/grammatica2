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

    // Fix Flutter plugins that use the deprecated `package` attribute in AndroidManifest.xml
    // instead of setting `namespace` in their build.gradle. AGP 8.8+ treats this as a hard error.
    val fixPlugin: () -> Unit = {
        if (plugins.hasPlugin("com.android.library") || plugins.hasPlugin("com.android.application")) {
            val android = extensions.findByName("android")
            if (android is com.android.build.gradle.BaseExtension) {
                if (android is com.android.build.gradle.LibraryExtension) {
                    // Set namespace from group if missing (e.g. vosk_flutter_2)
                    if (android.namespace.isNullOrEmpty()) {
                        val ns = project.group.toString().ifEmpty {
                            "com.grammatica.generated.${project.name.replace("-", "_")}"
                        }
                        android.namespace = ns
                    }

                    // Strip the deprecated `package` attribute from the source AndroidManifest.xml
                    // so AGP 8.8+ doesn't throw a hard error.
                    val manifestFile = project.file("src/main/AndroidManifest.xml")
                    if (manifestFile.exists()) {
                        val content = manifestFile.readText()
                        if (content.contains("package=")) {
                            val fixed = content
                                .replace(Regex("""\s*package="[^"]*""""), "")
                            if (fixed != content) {
                                manifestFile.writeText(fixed)
                            }
                        }
                    }
                }
            }
        }

        // Force Java 17 for all tasks to support modern features like pattern matching
        tasks.withType<JavaCompile>().configureEach {
            sourceCompatibility = JavaVersion.VERSION_17.toString()
            targetCompatibility = JavaVersion.VERSION_17.toString()
        }
        
        // Also force Kotlin jvmTarget if the plugin is present
        plugins.withId("org.jetbrains.kotlin.android") {
            extensions.findByType<org.jetbrains.kotlin.gradle.dsl.KotlinJvmOptions>()?.jvmTarget = "17"
        }
    }

    if (project.state.executed) {
        fixPlugin()
    } else {
        project.afterEvaluate { fixPlugin() }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
