
OPTIONS := -uroot --rm --init -v ${PWD}:/tmp/metadata -w /tmp/metadata --entrypoint /tmp/metadata/metadata.sh

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
2019.4: IMAGE = store/intersystems/irishealth-community:2019.4.0.383.0
2020.1: IMAGE = store/intersystems/irishealth-community:2020.1.0.217.1
2020.2: IMAGE = store/intersystems/irishealth-community:2020.2.0.211.0
2020.3: IMAGE = store/intersystems/irishealth-community:2020.3.0.221.0
2020.4: IMAGE = store/intersystems/irishealth-community:2020.4.0.524.0
2021.1: IMAGE = store/intersystems/irishealth-community:2021.1.0.215.0

targets=$(shell sed 's/^\(20[0-9][0-9]\.[1-9]\): IMAGE.*/\1/p;d' $(MAKEFILE_LIST))

test:
	@echo $(MAKEFILE_LIST)
	@echo $(targets)

.PHONY: all $(targets)
all: $(targets)

$(targets):
	docker run ${OPTIONS} ${IMAGE}

src/org/litesolutions/Metadata.cls: old

.PHONY: old
old: 
	$(eval CONTAINER = $(shell docker run --rm -d -v `pwd`:/home/irisowner/metadata store/intersystems/irishealth-community:2021.1.0.215.0))
	@docker exec -i $(CONTAINER) /usr/irissys/dev/Cloud/ICM/waitISC.sh IRIS 60 "running"
	@docker exec -i $(CONTAINER) iris session iris '##class(%SYSTEM.OBJ).ImportDir("/home/irisowner/metadata/generator/src/","*.cls","ck",,1)'
	@docker exec -i $(CONTAINER) iris session iris '##class(%SYSTEM.OBJ).ExportPackage("org.litesolutions","/home/irisowner/metadata/generator/src/org.litesolutions.Metadata.xml","/diffexport/exportversion=2014.1")'
	@docker kill $(CONTAINER)


combine:
	@python3 combine.py
	cat `find metadata -iname 'classesDiff.csv' | sort ` > metadata/classes.csv
	cat `find metadata -iname 'methodsDiff.csv' | sort ` > metadata/methods.csv
