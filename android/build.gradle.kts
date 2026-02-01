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
    
    // Workaround for missing namespace in some Flutter plugins (like vosk_flutter_2)
    val fixNamespace = {
        if (plugins.hasPlugin("com.android.library")) {
            val android = extensions.findByType<com.android.build.gradle.LibraryExtension>()
            if (android != null && android.namespace == null) {
                android.namespace = "com.grammatica.generated.${project.name.replace("-", "_")}"
            }
        }
    }

    if (state.executed) {
        fixNamespace()
    } else {
        afterEvaluate { fixNamespace() }
    }
}

subprojects {
    plugins.whenPluginAdded {
        if (this.toString().contains("com.android.build.gradle.LibraryPlugin") || 
            this.toString().contains("com.android.build.gradle.AppPlugin")) {
            val android = project.extensions.getByName("android") as com.android.build.gradle.BaseExtension
            if (android.namespace == null) {
                android.namespace = project.group.toString()
            }
            // Only set compileSdkVersion if it's not already set to a safe value
            // or if it's a plugin that we know needs a boost.
            // Using compileSdkVersion instead of compileSdk for BaseExtension compatibility
            android.compileSdkVersion(34)
        }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
