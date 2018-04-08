PY?=python3
PELICAN?=pelican
PELICANOPTS=
S3OPTS=

BASEDIR=$(CURDIR)
INPUTDIR=$(BASEDIR)/content
OUTPUTDIR=$(BASEDIR)/output
CONFFILE=$(BASEDIR)/pelicanconf.py
PUBLISHCONF=$(BASEDIR)/publishconf.py

S3_BUCKET=www.codependentcodr.com
DOCKER_IMAGE_NAME=codependentcodr
DOCKER_IMAGE_TAGS := $(shell docker images --format '{{.Repository}}:{{.Tag}}' | grep '$(DOCKER_IMAGE_NAME)')

LINTER_BASE_ARGS=--rm -it -v $(shell pwd):/develop -w /develop

DEBUG ?= 0
ifeq ($(DEBUG), 1)
	PELICANOPTS += -D
	S3OPTS += --dryrun
endif

RELATIVE ?= 0
ifeq ($(RELATIVE), 1)
	PELICANOPTS += --relative-urls
endif

help:
	@echo 'Makefile for a pelican Web site                                           '
	@echo '                                                                          '
	@echo 'Usage:                                                                    '
	@echo '   make html                           (re)generate the web site          '
	@echo '   make clean                          remove the generated files         '
	@echo '   make regenerate                     regenerate files upon modification '
	@echo '   make publish                        generate using production settings '
	@echo '   make serve [PORT=8000]              serve site at http://localhost:8000'
	@echo '   make serve-global [SERVER=0.0.0.0]  serve (as root) to $(SERVER):80    '
	@echo '   make devserver [PORT=8000]          start/restart develop_server.sh    '
	@echo '   make stopserver                     stop local server                  '
	@echo '   make s3_upload                      upload the web site via S3         '
	@echo '   make markdownlint                   run markdownlint on content        '
	@echo '   make pylint                         run pylint on content              '
	@echo '   make lint_the_things                run all linters & checks           '
	@echo '   make dockerbuild                    build docker image                 '
	@echo '   make dockerrun                      run a shell in built Docker image  '
	@echo '   make dockerdevserverstart           run a dev server in a container    '
	@echo '   make dockerdevserverstop            stop a running container server    '
	@echo '                                                                          '
	@echo 'Set the DEBUG variable to 1 to enable debugging, e.g. make DEBUG=1 html   '
	@echo 'Set the RELATIVE variable to 1 to enable relative urls                    '
	@echo '                                                                          '

html:
	$(PELICAN) $(INPUTDIR) -o $(OUTPUTDIR) -s $(CONFFILE) $(PELICANOPTS)
	if test -d $(BASEDIR)/extra; then cp $(BASEDIR)/extra/* $(OUTPUTDIR)/; fi

clean:
	[ ! -d $(OUTPUTDIR) ] || rm -rf $(OUTPUTDIR)
	docker rmi $(DOCKER_IMAGE_TAGS) || true

regenerate:
	$(PELICAN) -r $(INPUTDIR) -o $(OUTPUTDIR) -s $(CONFFILE) $(PELICANOPTS)

serve:
ifdef PORT
	cd $(OUTPUTDIR) && $(PY) -m pelican.server $(PORT)
else
	cd $(OUTPUTDIR) && $(PY) -m pelican.server
endif

serve-global:
ifdef SERVER
	cd $(OUTPUTDIR) && $(PY) -m pelican.server 80 $(SERVER)
else
	cd $(OUTPUTDIR) && $(PY) -m pelican.server 80 0.0.0.0
endif

# old deprecated way to run dev server, see dockerdevserverstart
devserver:
ifdef PORT
	$(BASEDIR)/develop_server.sh restart $(PORT)
else
	$(BASEDIR)/develop_server.sh restart
endif

# old deprecated way to stop dev server, see dockerdevserverstop
stopserver:
	$(BASEDIR)/develop_server.sh stop
	@echo 'Stopped Pelican and SimpleHTTPServer processes running in background.'

publish:
	$(PELICAN) $(INPUTDIR) -o $(OUTPUTDIR) -s $(PUBLISHCONF) $(PELICANOPTS)
	if test -d $(BASEDIR)/extra; then cp $(BASEDIR)/extra/* $(OUTPUTDIR)/; fi

s3_upload: publish lint_the_things
	aws s3 sync $(OUTPUTDIR) s3://$(S3_BUCKET) --delete $(S3OPTS)

lint_the_things: markdownlint pylint

markdownlint: dockerbuild
	docker run $(LINTER_BASE_ARGS) $(DOCKER_IMAGE_NAME):latest markdownlint content/

pylint: dockerbuild
	docker run $(LINTER_BASE_ARGS) $(DOCKER_IMAGE_NAME):latest pylint *.py

dockerbuild:
	docker build -t $(DOCKER_IMAGE_NAME):latest .

dockerrun: dockerbuild
	docker run $(LINTER_BASE_ARGS) $(DOCKER_IMAGE_NAME):latest /bin/sh

dockerdevserverstart: dockerbuild
	# run a dev server in a container
	docker run -d -p 8000:8000 -v $(shell pwd):/develop --rm --name=codependentcodr $(DOCKER_IMAGE_NAME):latest make devserver

dockerdevserverstop:
	docker stop codependentcodr

.PHONY: html help clean regenerate serve serve-global devserver stopserver publish s3_upload github
