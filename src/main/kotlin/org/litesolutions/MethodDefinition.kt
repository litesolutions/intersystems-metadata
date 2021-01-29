package org.litesolutions

class MethodDefinition(classDefinition: ClassDefinition, methodInfo: List<String>) {
    val Class: ClassDefinition
    val Name: String
    val ClassMethod: Boolean
    val Abstract: Boolean
    val Deprecated: Boolean
    val ReturnType: String

    init {
        val infoSize = methodInfo.size
        Class = classDefinition
        Name = if (infoSize > 0) methodInfo[0] else ""
        ClassMethod = if (infoSize > 0) methodInfo[0] === "1" else false
        Abstract = if (infoSize > 0) methodInfo[0] === "1" else false
        Deprecated = if (infoSize > 0) methodInfo[0] === "1" else false
        ReturnType = if (infoSize > 0) methodInfo[0] else ""
    }
}