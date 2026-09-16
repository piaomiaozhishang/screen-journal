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

// 统一强制所有插件子模块使用 compileSdk 36：部分插件（如 file_picker）
// 硬编码了较低的 compileSdk，但其依赖（flutter_plugin_android_lifecycle）要求 36，
// 否则 checkAarMetadata 失败。必须在下面 evaluationDependsOn 触发评估之前注册。
subprojects {
    afterEvaluate {
        val androidExt = extensions.findByName("android")
        if (androidExt != null) {
            try {
                val method = androidExt.javaClass.getMethod(
                    "compileSdkVersion", Int::class.javaPrimitiveType
                )
                method.invoke(androidExt, 36)
            } catch (_: Exception) {
                // 非 Android 模块忽略
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
