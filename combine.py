from os import listdir
import os.path
from multiprocessing import Process, freeze_support
from typing import List
import re
import time

metadataPath = os.path.abspath("./metadata/")
def splitLine(line): return str.split(line, ",")


def writeLines(file, version, kind, cnt, reason, lines):
    for line in lines:
        line.insert(cnt, reason)
        line.insert(0, version)
        line.insert(0, kind)
        file.write(",".join(line))


def readFiles(folder):
    folder = os.path.join(metadataPath, folder)
    with open(os.path.join(folder, "classes.csv")) as file:
        classes = file.readlines()
        classes.pop(0)
    with open(os.path.join(folder, "methods.csv")) as file:
        methods = file.readlines()
        methods.pop(0)
    with open(os.path.join(folder, "properties.csv")) as file:
        properties = file.readlines()
        properties.pop(0)

    return classes, methods, properties


def getDiffferences(cnt, curr, prev, deletedList):
    prevNew = list(set(curr) - set(prev))
    currNew = list(set(prev) - set(curr))
    diff = list(set(currNew).symmetric_difference(set(prevNew)))

    diff = list(map(lambda i: ",".join(str.split(i, ",")[:cnt]), diff))
    diff = list(set(diff))
    diff = list(map(splitLine, diff))
    if deletedList:
        diff = [i for i in diff if i[0] not in deletedList]

    prevList = list(map(splitLine, prevNew))
    currList = list(map(splitLine, currNew))

    prevList = [i for i in prevList if i[:cnt] in diff]
    currList = [i for i in currList if i[:cnt] in diff]

    prevListInfo = list(map(lambda i: ",".join(i[:cnt]), prevList))
    currListInfo = list(map(lambda i: ",".join(i[:cnt]), currList))
    deleted = list(set(prevListInfo) - set(currListInfo))
    deleted = [i for i in prevList if ",".join(i[:cnt]) in deleted]
    added = list(set(currListInfo) - set(prevListInfo))
    added = [i for i in currList if ",".join(i[:cnt]) in added]
    changed = list(set(currListInfo).intersection(set(prevListInfo)))
    changed = [i for i in currList if ",".join(i[:cnt]) in changed]

    return (added, deleted, changed)


def process(kind, curr, prev, version: str, cnt: int, saveTo: str, deletedList=[]):

    (added, deleted, changed) = getDiffferences(cnt, curr, prev, deletedList)
    if cnt == 1:
        deletedList = list(map(lambda i: i[0], deleted))

    with open(saveTo, mode="w") as file:
        writeLines(file, version, kind, cnt, "Added", added)
        writeLines(file, version, kind, cnt, "Deleted", deleted)
        writeLines(file, version, kind, cnt, "Changed", changed)

    return deletedList


def processDir(currData, prevData, currVer):
    start_time = time.time()
    classes, methods, properties = currData
    classesPrev, methodsPrev, propertiesPrev = prevData

    deletedList = process(
        "class", classes, classesPrev, currVer, 1,
        os.path.join(metadataPath, currVer, "classesDiff.csv"))
    process(
        "method", methods, methodsPrev, currVer, 2,
        os.path.join(metadataPath, currVer, "methodsDiff.csv"), deletedList)
    process(
        "property", properties, propertiesPrev, currVer, 2,
        os.path.join(metadataPath, currVer, "propertiesDiff.csv"), deletedList)

    print("Execution time for %s: %.3f" % (currVer, time.time() - start_time))


if __name__ == '__main__':
    freeze_support()
    dirs = sorted(listdir(metadataPath), reverse=True)
    dirs = list(filter(lambda dirname: re.match("\d{4}\.\d", dirname), dirs))

    last = dirs[-1]
    classes, methods, properties = readFiles(last)
    with open(os.path.join(metadataPath, last, "classesDiff.csv"), "w") as file:
        writeLines(file, last, "class", 1, "", list(map(splitLine, classes)))
    with open(os.path.join(metadataPath, last, "methodsDiff.csv"), "w") as file:
        writeLines(file, last, "method", 2, "", list(map(splitLine, methods)))
    with open(os.path.join(metadataPath, last, "propertiesDiff.csv"), "w") as file:
        writeLines(file, last, "property", 2, "",
                   list(map(splitLine, properties)))

    currVer = dirs[0]
    prevData = readFiles(currVer)
    for (prev) in dirs[1:]:
        print("%s - %s" % (currVer, prev))
        currData = readFiles(prev)

        Process(
            target=processDir,
            args=(currData, prevData, currVer)
        ).start()

        currVer = prev
        prevData = currData
