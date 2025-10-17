// เวอร์ชันตัวอย่าง: ปรับตามเครื่องคุณได้
plugins {
    id("com.android.application") version "8.6.1" apply false
    id("com.android.library") version "8.6.1" apply false
    id("org.jetbrains.kotlin.android") version "1.9.24" apply false
    id("dev.flutter.flutter-gradle-plugin") apply false
}

// ----- ย้าย buildDir ของ root project ไปไว้ ../../build -----
val newBuildDir = layout.buildDirectory.dir("../../build")
layout.buildDirectory.set(newBuildDir)

// ----- ย้าย buildDir ของทุก subproject ไปไว้ใต้โฟลเดอร์ชื่อโปรเจกต์ -----
subprojects {
    layout.buildDirectory.set(
        // newBuildDir เป็น Provider<Directory> ต้อง map เพื่อ .dir(name)
        newBuildDir.map { it.dir(name) }
    )
    // (ไม่จำเป็นต้องใช้ evaluationDependsOn(":app") กับโปรเจกต์ Flutter ทั่วไป)
}

// ----- งาน clean -----
tasks.register<Delete>("clean") {
    delete(layout.buildDirectory)
}
