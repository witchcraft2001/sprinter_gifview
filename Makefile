.PHONY: build package image clean

build:
	tools/build.sh

package: build
	tools/package.sh

image: build
	tools/image.sh

clean:
	rm -rf build
	rm -f distr/gifview.zip distr/gifview.img
