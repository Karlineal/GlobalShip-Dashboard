allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

val newBuildDir: Directory = rootProject.layout.buildDirectory.dir("../../build").get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}
subprojects {
    // 由于项目路径包含非ASCII字符,需要在gradle.properties中添加android.overridePathCheck=true
    if (!file("${rootProject.projectDir}/gradle.properties").exists()) {
        file("${rootProject.projectDir}/gradle.properties").writeText("android.overridePathCheck=true")
    }
    if (!file("${rootProject.projectDir}/gradle.properties").readText().contains("android.overridePathCheck=true")) {
        file("${rootProject.projectDir}/gradle.properties").appendText("\nandroid.overridePathCheck=true")
    }
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
