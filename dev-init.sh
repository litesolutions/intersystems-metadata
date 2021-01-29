#!/bin/bash

iris session iris "##class(%SYSTEM.OBJ).LoadDir(\"${PWD}/generator/src\",\"ckd\",,1)"
iris session iris -U%SYS '##class(Security.Users).UnExpireUserPasswords("*")'
