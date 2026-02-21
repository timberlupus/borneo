allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

rootProject.layout.buildDirectory.set(file("../build"))

subprojects {
    layout.buildDirectory.set(rootProject.layout.buildDirectory.dir(project.name))
    evaluationDependsOn(":app")

    plugins.withId("com.android.library") {
        if (name == "flutter_esp_ble_prov") {
            extensions.configure<com.android.build.gradle.LibraryExtension> {
                namespace = "how.virc.flutter_esp_ble_prov"
            }
        }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
