fun RepositoryHandler.msdMirrors() {
    // Aliyun first — Google Maven is often unreachable on this network
    maven(url = "https://maven.aliyun.com/repository/google")
    maven(url = "https://maven.aliyun.com/repository/central")
    maven(url = "https://maven.aliyun.com/repository/public")
    maven(url = "https://maven.aliyun.com/repository/gradle-plugin")
}

allprojects {
    buildscript {
        repositories {
            msdMirrors()
            gradlePluginPortal()
        }
    }
    repositories {
        msdMirrors()
    }
}

subprojects {
    buildscript {
        repositories {
            msdMirrors()
            gradlePluginPortal()
        }
        // Plugins pin older AGP versions in their own buildscript; reuse the app's AGP
        // (already on the classpath) instead of downloading another copy.
        configurations.named("classpath") {
            resolutionStrategy.eachDependency {
                if (requested.group == "com.android.tools.build" && requested.name == "gradle") {
                    useVersion("8.9.1")
                }
            }
        }
    }
    repositories {
        msdMirrors()
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

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
