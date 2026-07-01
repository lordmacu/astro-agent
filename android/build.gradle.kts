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

    // AGP 8 requires every Android module to declare a `namespace`. Some older
    // plugins (e.g. vosk_flutter_2) don't, which breaks configuration. Inject
    // one (from the module group) via reflection — so we don't need the AGP
    // types on the root classpath. Registered here, BEFORE evaluationDependsOn
    // triggers evaluation, so afterEvaluate isn't added to an evaluated project.
    afterEvaluate {
        val android = project.extensions.findByName("android")
        if (android != null) {
            runCatching {
                val getNamespace = android.javaClass.getMethod("getNamespace")
                if (getNamespace.invoke(android) == null) {
                    val fallback =
                        project.group.toString().ifEmpty { "com.${project.name}" }
                    android.javaClass
                        .getMethod("setNamespace", String::class.java)
                        .invoke(android, fallback)
                }
            }
        }
    }
}
subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
