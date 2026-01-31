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

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
