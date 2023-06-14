.PHONY: all build build-ta

all: build build-ta

build:
	rm -rf src-snipped/
	cp -r src/ src-snipped/
	python3 scripts/snip.py --verbose --live ./src-snipped SOLUTION
	# ./scripts/pdf-snipped.sh
	goo build site.yaml
	cp -r ./src/docs/static/posts ./build/static

build-ta:
	# ./scripts/pdf.sh
	goo build site-ta.yaml
	cp -r ./src/docs/static/posts ./build-ta/static

serve: build
	goo serve site.yaml 3000 --nobuild

serve-ta: build-ta
	goo serve site-ta.yaml 3000 --nobuild

serve-no-pdf:
	goo build site-ta.yaml
	cp -r ./src/docs/static/posts ./build-ta/static
	goo serve site-ta.yaml 3000 --nobuild
