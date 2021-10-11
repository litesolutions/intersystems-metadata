package org.litesolutions

import org.rocksdb.RocksDB
import java.nio.file.Files
import java.nio.file.StandardCopyOption
import java.util.*
import java.util.jar.JarFile

class InterSystemsMetadata private constructor() {
    private val db: RocksDB
    private val versions: List<String>

    companion object {
        private var instance: InterSystemsMetadata? = null

        init {
            instance = InterSystemsMetadata()
        }

        @JvmStatic
        fun getInstance(): InterSystemsMetadata? {
            return instance
        }
    }

    init {
        val dbDir = extractMetadataDB()
        db = RocksDB.openReadOnly(dbDir)

        versions = String(db.get("versions".toByteArray())).split(",")
        Collections.sort(versions, Collections.reverseOrder())
    }

    private fun normalizeClassName(className: String): String {
        return className.replace("^%([^.]+)$".toRegex(), "%Library.$1")
    }

    private fun getObjectInfo(
        kind: String,
        version: String = "",
        className: String,
        objectName: String?
    ): List<String>? {
        val versList = if (version.isEmpty() || !versions.contains(version))
            versions else versions.subList(versions.indexOf(version), versions.size)

        versList.forEach { vers ->
            val key = if (objectName == null)
                listOf(kind, vers, className) else listOf(kind, vers, className, objectName)
            val value = String(db.get(key.joinToString(",").toByteArray()) ?: return@forEach).split(",").toMutableList()
            if (value[0] == "Deleted") return null
            value[0] = objectName ?: className
            return value
        }

        return null
    }

    private fun getClassInfo(version: String, className: String): List<String>? {
        return getObjectInfo("class", version, normalizeClassName(className), null)
    }

    private fun getMethodInfo(version: String, className: String, methodName: String?): List<String>? {
        val classInfo = getClassInfo(version, className) ?: return null
        val classList = listOf(className) + classInfo[1].split("~").filter { it.isNotEmpty() }
        classList.forEach { clsName ->
            val methodInfo = getObjectInfo("method", version, normalizeClassName(clsName), methodName)
            if (methodInfo != null) return methodInfo
        }
        return null
    }

    private fun getPropertyInfo(version: String, className: String, propertyName: String?): List<String>? {
        val classInfo = getClassInfo(version, className) ?: return null
        val classList = listOf(className) + classInfo[1].split("~").filter { it.isNotEmpty() }
        classList.forEach { clsName ->
            val propertyInfo = getObjectInfo("property", version, normalizeClassName(clsName), propertyName)
            if (propertyInfo != null) return propertyInfo
        }
        return null
    }

    @Suppress("unused")
    fun classExists(version: String = "", className: String): Boolean {
        return classOpen(version, className) != null
    }

    @Suppress("unused")
    fun classOpen(version: String = "", className: String): ClassDefinition? {
        return getClassInfo(version, className)?.let { classInfo ->
            ClassDefinition(classInfo)
        }
    }

    @Suppress("unused")
    fun methodExists(version: String = "", className: String, methodName: String): Boolean {
        return methodOpen(version, className, methodName) != null
    }

    @Suppress("unused")
    fun methodOpen(version: String = "", className: String, methodName: String): MethodDefinition? {
        return classOpen(version, className)?.let { classDef ->
            val methodInfo = getMethodInfo(version, className, methodName)
            return methodInfo?.let { MethodDefinition(classDef, methodInfo) }
        }
    }

    @Suppress("unused")
    fun prpertyExists(version: String = "", className: String, propertyName: String): Boolean {
        return propertyOpen(version, className, propertyName) != null
    }

    @Suppress("unused")
    fun propertyOpen(version: String = "", className: String, propertyName: String): PropertyDefinition? {
        return classOpen(version, className)?.let { classDef ->
            val propertyInfo = getPropertyInfo(version, className, propertyName)
            return propertyInfo?.let { PropertyDefinition(classDef, propertyInfo) }
        }
    }
}

private fun extractMetadataDB(): String {
    val resource = InterSystemsMetadata::class.java.getResource("/metadatadb/").path
    if (!resource.startsWith("file:/")) return resource
    val jarFile = resource.replace("!.*|file:".toRegex(), "")
    val dbDir = Files.createTempDirectory("metadatadb")

    JarFile(jarFile).use { jf ->
        jf.entries().toList().forEach { entry ->
            if (entry.name.startsWith("metadatadb/") && !entry.isDirectory) {
                val file = dbDir.resolve(entry.name.replace("metadatadb/", ""))
                jf.getInputStream(entry).use { inputStream ->
                    Files.copy(inputStream, file, StandardCopyOption.REPLACE_EXISTING)
                }
            }
        }
    }
    return dbDir.toFile().absolutePath
}
