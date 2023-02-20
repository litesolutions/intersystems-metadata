#!/bin/bash

CCONTROL=ccontrol
if ! command -v ccontrol &> /dev/null
then 
  CCONTROL=iris
  ZPM=1
fi

echo CCONTROL=${CCONTROL}

$CCONTROL start $ISC_PACKAGE_INSTANCENAME EmergencyId=sys,sys

VERSION=($($CCONTROL qlist | cut -d '^' -f 3 | cut -d '.' -f 1,2 | tr '.' "\n"))
if (([ ${VERSION[0]} == 2016 ] && [[ ${VERSION[1]} -gt 1 ]]) || [ ${VERSION[0]} -gt 2016 ])
then
  FILTER="*.cls"
else
  FILTER="*.xml"
fi

if [ ! -z $ZPM ]
then
  echo "Installing ZPM"
  wget https://pm.community.intersystems.com/packages/zpm/latest/installer -qO /tmp/zpm.xml 
  echo -e "sys\nsys\n" \
    "set sc = \$system.OBJ.DeletePackage(\"%ZPM\")\n" \
    "set sc = \$system.OBJ.Load(\"/tmp/zpm.xml\",\"ck\")\n" \
    "halt\n" \
  | $CCONTROL session $ISC_PACKAGE_INSTANCENAME 
fi

echo -e "sys\nsys\n" \
  "set sc = \$system.OBJ.ImportDir(\"/tmp/app/generator/src\",\"$FILTER\",\"ck\",,1)\n" \
  "if 'sc do ##class(%SYSTEM.Process).Terminate(, 1)\n" \
  "set sc = ##class(org.litesolutions.Metadata).Extract(\"/tmp\")\n" \
  "if 'sc do ##class(%SYSTEM.Process).Terminate(, 1)\n" \
  "write \"Finished\"\n" \
  "halt\n" \
| $CCONTROL session $ISC_PACKAGE_INSTANCENAME 
exit=$?

find /tmp/metadata

echo "Stopping"
echo -e "sys\nsys" | $CCONTROL stop $ISC_PACKAGE_INSTANCENAME quietly

exit $exit
