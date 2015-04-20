init:
	npm install

clean:
	rm -rf lib/

build:
	@./node_modules/.bin/coffee -o lib/ -c src

test: build
	@./node_modules/.bin/mocha

test-unit: build
	@./node_modules/.bin/mocha --grep @integration --invert

publish: clean init test
	npm publish

coverage: build
	@BLANKET=true ./node_modules/.bin/mocha --reporter html-cov > coverage.html

travis: build
	@BLANKET=true ./node_modules/.bin/mocha --reporter travis-cov

.PHONY: init clean build test test-unit publish coverage travis
