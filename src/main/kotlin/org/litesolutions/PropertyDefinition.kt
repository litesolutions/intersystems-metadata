package org.litesolutions

@Suppress("MemberVisibilityCanBePrivate")
class PropertyDefinition(classDefinition: ClassDefinition, propertyInfo: List<String>) {
    val classDefinition: ClassDefinition
    val name: String
    val type: String

    init {
        val infoSize = propertyInfo.size
        this.classDefinition = classDefinition
        name = if (infoSize > 0) propertyInfo[0] else ""
        type = if (infoSize > 1) propertyInfo[1] else ""
    }
}
