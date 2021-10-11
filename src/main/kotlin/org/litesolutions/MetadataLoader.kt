package org.litesolutions

import kotlinx.cli.ArgParser
import kotlinx.cli.ArgType
import kotlinx.cli.default
import org.rocksdb.Options
import org.rocksdb.RocksDB
import org.rocksdb.WriteOptions
import java.io.File

class MetadataLoader {
    companion object {
        var verbose = false
    }
}

fun main(args: Array<String>) {

    val parser = ArgParser("metadata-loader")
    val input by parser.option(ArgType.String, shortName = "i", description = "Input directory")
    val verbose by parser.option(ArgType.Boolean, shortName = "v", description = "Verbose output").default(false)
    val test by parser.option(ArgType.Boolean, shortName = "t", description = "Test database").default(false)

    try {
        parser.parse(args)
    } catch (e: Exception) {
        println(e.message)
        return
    }
    MetadataLoader.verbose = verbose

    RocksDB.loadLibrary()

    if (test) {
        println("testing")
        val metadata = InterSystemsMetadata.getInstance()
        println("methodTest: ${metadata?.methodExists("2020.2", "HS.FHIRServer.ServiceInstance", "NewInstance")}")
        println("methodTest: ${metadata?.methodExists("", "HS.FHIRServer.ServiceInstance", "NewInstance")}")
        return
    }

    val dir = File(input)
    if (!dir.exists() && !dir.isDirectory) {
        println("Input directory '${dir.absolutePath}' does not exists")
        kotlin.system.exitProcess(1)
    }

    val rootResource = MetadataLoader::class.java.getResource("/")?.path

    val dbDir = File(rootResource, "metadatadb")
    if (dbDir.exists()) {
        dbDir.deleteRecursively()
        dbDir.mkdirs()
    }

    Options().apply {
        setCreateIfMissing(true)
        setMaxLogFileSize(0)
    }.use { options ->
        RocksDB.open(options, dbDir.absolutePath).use { db ->
            val files = HashMap<String, Int>()
            files["classes.csv"] = 3
            files["methods.csv"] = 4
            files["properties.csv"] = 4

            files.forEach { (fileName, num) ->
                val (count, versions) = File(dir, fileName).useLines { lines -> processFile(db, lines, num) }
                println("$fileName = $count")
                db.put("versions".toByteArray(), versions.toString().toByteArray())
            }
        }
    }
}

private fun processFile(db: RocksDB, lines: Sequence<String>, num: Int): List<Any> {
    var count = 0
    val versions = mutableListOf<String>()
    lines.map { line -> line.split(",") }.forEach { itLine ->
        val line = itLine.map { if (it == "TRUE") "1" else it }
        val version = line[1]
        if (!versions.contains(version)) versions.add(version)
        val key = line.take(num).joinToString(",").toByteArray()
        val value = line.drop(num).joinToString(",").toByteArray()
        if (MetadataLoader.verbose) println(String(key) + ": " + String(value))
        db.put(WriteOptions().setDisableWAL(true), key, value)
        count++
    }
    return listOf(count, versions.joinToString(","))
}

private fun Options.use(block: (Options) -> Unit) {
    try {
        return block(this)
    } finally {
        close()
    }
}

private fun RocksDB.use(block: (RocksDB) -> Unit) {
    try {
        return block(this)
    } finally {
        close()
    }
}


