package org.litesolutions

@Suppress("MemberVisibilityCanBePrivate")
class MethodDefinition(classDefinition: ClassDefinition, methodInfo: List<String>) {
    val classDefinition: ClassDefinition
    val name: String
    val classMethod: Boolean
    val abstract: Boolean
    val deprecated: Boolean
    val returnType: String
    val formalSpec: List<String>

    init {
        val infoSize = methodInfo.size
        this.classDefinition = classDefinition
        name = if (infoSize > 0) methodInfo[0] else ""
        classMethod = if (infoSize > 1) methodInfo[1] === "1" else false
        abstract = if (infoSize > 2) methodInfo[2] === "1" else false
        deprecated = if (infoSize > 3) methodInfo[3] === "1" else false
        returnType = if (infoSize > 4) methodInfo[4] else ""
        formalSpec = if (infoSize > 5 && methodInfo[5] != null)  listOf(
            *methodInfo[5]!!.split("~").toTypedArray()
        ) else emptyList()
    }
}
