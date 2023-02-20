
OPTIONS := -v ${PWD}/metadata.sh:/tmp/app/metadata.sh --entrypoint /tmp/app/metadata.sh 
OPTIONS += -v ${PWD}/generator:/tmp/app/generator
ENSOPTIONS := 
IRISOPTIONS := -v `pwd`/iris.key:/usr/irissys/mgr/iris.key

.DEFAULT_GOAL := help
.PHONY: help
help:
	@echo "\nUsage: make \033[36m<target>\033[0m\n"
	@printf "\033[36m%-10s\033[0m %s\n" "all" "process all versions"
	@grep -E '^20[0-9]{2}\.[1-9]: IMAGE = .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ": IMAGE = "}; {printf "\033[36m%-10s\033[0m %s\n", $$1, $$2}'

2014.1 2015.1 2015.2 2016.1: old

# Docker Images
2014.1: IMAGE = daimor/intersystems-ensemble:2014.1
2015.1: IMAGE = daimor/intersystems-ensemble:2015.1
2015.2: IMAGE = daimor/intersystems-ensemble:2015.2
2016.1: IMAGE = daimor/intersystems-ensemble:2016.1
2016.2: IMAGE = daimor/intersystems-ensemble:2016.2
2017.1: IMAGE = daimor/intersystems-ensemble:2017.1
2017.2: IMAGE = daimor/intersystems-ensemble:2017.2
2018.1: IMAGE = daimor/intersystems-ensemble:2018.1
2019.4: IMAGE = intersystemsdc/irishealth-community:2019.4.0.383.0-zpm
2020.1: IMAGE = intersystemsdc/irishealth-community:2020.1.0.215.0-zpm
2020.2: IMAGE = intersystemsdc/irishealth-community:2020.2.0.204.0-zpm
2020.3: IMAGE = intersystemsdc/irishealth-community:2020.3.0.221.0-zpm
2020.4: IMAGE = intersystemsdc/irishealth-community:2020.4.0.547.0-zpm
2021.1: IMAGE = intersystemsdc/irishealth-community:2021.1.0.215.3-zpm
2021.2: IMAGE = intersystemsdc/irishealth-community:2021.2.0.651.0-zpm
2022.1: IMAGE = intersystemsdc/irishealth-community:2022.1.1.374.0-zpm
2022.2: IMAGE = intersystemsdc/irishealth-community:2022.2.0.368.0-zpm
2022.3: IMAGE = intersystemsdc/irishealth-community:2022.3.0.599.0-zpm

targets=$(shell sed 's/^\(20[0-9][0-9]\.[1-9]\): IMAGE.*/\1/p;d' $(MAKEFILE_LIST))
ensemble=$(shell sed 's/^\(20[0-9][0-9]\.[1-9]\): IMAGE.*ensemble.*/\1/p;d' $(MAKEFILE_LIST))
iris=$(shell sed 's/^\(20[0-9][0-9]\.[1-9]\): IMAGE.*iris.*/\1/p;d' $(MAKEFILE_LIST))

test:
	@echo $(MAKEFILE_LIST)
	@echo $(targets)

.PHONY: all $(targets)
all: $(targets)

$(ensemble): OPTIONS += $(ENSOPTIONS)
$(iris): OPTIONS += $(IRISOPTIONS)

$(targets):
	mkdir -p metadata
	$(eval CONTAINER := $(shell docker create ${OPTIONS} ${IMAGE}))
	@docker start $(CONTAINER)
	sleep 10
	@docker wait $(CONTAINER)
	@docker logs $(CONTAINER)
	@docker cp $(CONTAINER):/tmp/metadata/$@ metadata/
	@docker rm $(CONTAINER)

src/org/litesolutions/Metadata.cls: old

.PHONY: old
old: 
	$(eval CONTAINER = $(shell docker run --rm -d -v `pwd`:/home/irisowner/metadata intersystemsdc/iris-community))
	@docker exec -i $(CONTAINER) /usr/irissys/dev/Cloud/ICM/waitISC.sh IRIS 120 "running"
	@docker exec -i $(CONTAINER) iris session iris '##class(%SYSTEM.OBJ).ImportDir("/home/irisowner/metadata/generator/src/","*.cls","ck",,1)'
	@docker exec -i $(CONTAINER) iris session iris '##class(%SYSTEM.OBJ).ExportPackage("org.litesolutions","/tmp/org.litesolutions.Metadata.xml","/diffexport/exportversion=2014.1")'
	@docker cp $(CONTAINER):/tmp/org.litesolutions.Metadata.xml generator/src/
	@docker kill $(CONTAINER)


combine:
	@python3 combine.py
	cat `find metadata -iname 'classesDiff.csv'    | sort ` > metadata/classes.csv
	cat `find metadata -iname 'methodsDiff.csv'    | sort ` > metadata/methods.csv
	cat `find metadata -iname 'propertiesDiff.csv' | sort ` > metadata/properties.csv
