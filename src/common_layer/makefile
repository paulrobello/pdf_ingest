NEW_CKSUM := $(shell md5sum src/* ../lib/*.py ../lib/utils/*.py ../lib/par_ai_core/*.py ../docker/Dockerfile.layer ../docker/makefile.layer ./makefile 2>/dev/null| md5sum | cut -f1 -d' ')

-include ../docker/makefile.layer

assemble:
	cp -R ../lib/* build/lib
	cp -R src build
