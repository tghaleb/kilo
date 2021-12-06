.PHONY: build release test docs serve

SACK = ".rucksack"
NAME = "kilo"

build:
	shards build
	cat ${SACK} >> bin/${NAME}
release:
	shards build --release
	cat ${SACK} >> bin/${NAME}
test:
	crystal spec -v
docs:
	mkdocs build
serve:
	mkdocs serve
