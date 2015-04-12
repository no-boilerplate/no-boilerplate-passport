
init:
	npm install

clean:
	rm -rf lib/ test/*.js

build:
	coffee -o lib/ -c src/

test:
	mocha -R spec --compilers coffee:coffee-script/register --require 'coffee-script/register' tests/tests.litcoffee

dist: clean init build test

publish: dist
	npm publish
