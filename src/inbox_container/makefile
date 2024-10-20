NEW_CKSUM := $(shell md5sum  src/* src/ai_ocr/* ../lib/*.py ../lib/utils/*.py ../docker/makefile.ecr ./makefile ./Dockerfile 2>/dev/null| md5sum | cut -f1 -d' ')

-include ../docker/makefile.ecr

assemble:
	cp -R requirements.txt build
	cp -R src build
	cp -R ../lib build/src/ai_ocr
