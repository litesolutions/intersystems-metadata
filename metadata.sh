#!/bin/bash

CCONTROL=ccontrol
FILTER="*.xml"
if ! command -v ccontrol &> /dev/null
then 
  FILTER="*.cls"
  CCONTROL=iris
fi

echo CCONTROL=${CCONTROL}

$CCONTROL start $ISC_PACKAGE_INSTANCENAME EmergencyId=sys,sys

echo -e "sys\nsys\n" \
  "set sc = \$system.OBJ.ImportDir(\"$PWD/generator/src\",\"$FILTER\",\"ck\",,1)\n" \
  "if 'sc do ##class(%SYSTEM.Process).Terminate(, 1)\n" \
  "set sc = ##class(org.litesolutions.Metadata).Extract(\"$PWD\")\n" \
  "if 'sc do ##class(%SYSTEM.Process).Terminate(, 1)\n" \
  "write \"Finished\"\n" \
  "halt\n" \
| $CCONTROL session $ISC_PACKAGE_INSTANCENAME 
exit=$?

echo "Stopping"
echo -e "sys\nsys" | $CCONTROL stop $ISC_PACKAGE_INSTANCENAME quietly

exit $exit
