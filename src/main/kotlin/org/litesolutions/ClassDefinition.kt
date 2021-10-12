package org.litesolutions

@Suppress("MemberVisibilityCanBePrivate")
class ClassDefinition(classInfo: List<String?>) {
    val name: String?
    val parent: List<String>
    val abstract: Boolean
    val persistent: Boolean
    val final: Boolean
    val deprecated: Boolean
    val hidden: Boolean
    val sqlTable: String?
    val system: Int
    val ensemble: Boolean

    init {
        val infoSize = classInfo.size
        name = classInfo[0]
        parent = if (infoSize > 1 && classInfo[1] != null) listOf(
            *classInfo[1]!!.split("~").toTypedArray()
        ) else emptyList()
        abstract = if (infoSize > 2) classInfo[2] === "1" else false
        persistent = if (infoSize > 3) classInfo[3] === "1" else false
        final = if (infoSize > 4) classInfo[4] === "1" else false
        deprecated = if (infoSize > 5) classInfo[5] === "1" else false
        hidden = if (infoSize > 6) classInfo[6] === "1" else false
        sqlTable = if (infoSize > 7) classInfo[7] else ""
        system = if (infoSize > 8) ("0" + classInfo[8]).toInt(10) else 0
        ensemble = if (infoSize > 9) classInfo[9] === "1" else false
    }
}
