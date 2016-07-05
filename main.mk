.DELETE_ON_ERROR:

pp-%:
	@echo "$(strip $($*))" | tr ' ' \\n

NODE_ENV ?= development
out := $(NODE_ENV)
src := $(dir $(realpath $(lastword $(MAKEFILE_LIST))))
mkdir = @mkdir -p $(dir $@)
restart_make = @printf "\033[0;33m%s\033[0;m\n" 'Restarting $(MAKE)...'


.PHONY: compile
compile:


package.json: $(src)/package.json
	cp $< $@

export NODE_PATH = $(realpath node_modules)
node_modules: package.json
	npm i --loglevel=error --depth=0
	touch $@

compile: node_modules


js.src := $(shell find $(src) -name '*.js' -type f)
js.dest := $(patsubst $(src)%.js, $(out)/.ccache/%.js, $(js.src))

ifeq ($(NODE_ENV), development)
BABEL_OPT := -s inline
endif
$(out)/.ccache/%.js: $(src)%.js
	$(mkdir)
	node_modules/.bin/babel --presets es2015 $(BABEL_OPT) $< -o $@

compile: $(js.dest)


bundles.src := $(filter %/main.js, $(js.dest))
bundles.dest := $(patsubst $(out)/.ccache/%.js, $(out)/%.js, $(bundles.src))

ifeq ($(NODE_ENV), development)
BROWSERIFY_OPT := -d
endif
$(bundles.dest): $(out)/%.js: $(out)/.ccache/%.js
	$(mkdir)
	node_modules/.bin/browserify $(BROWSERIFY_OPT) $< -o $@

compile: $(bundles.dest)


include $(out)/.ccache/depend.mk
$(out)/.ccache/depend.mk: $(js.dest)
	make-commonjs-depend $^ > $@
	$(restart_make)


static.src := $(src)/comments/main.css $(src)/manifest.json
static.dest := $(patsubst $(src)%, $(out)/%, $(static.src))

$(static.dest): $(out)/%: $(src)%
	cp $< $@

compile: $(static.dest)


define get-test-data =
$(mkdir)
cd `dirname $(dir $@)` && wget -Epkq '$(1)'
@if [ -r $@ ]; then :; else (cd $(dir $@) && mv *.html index.html); fi
endef

test/data/frontpage/news.ycombinator.com/index.html:
	$(call get-test-data,https://news.ycombinator.com)

test/data/user-comments/news.ycombinator.com/index.html:
	$(call get-test-data,https://news.ycombinator.com/threads?id=edw519)


.PHONY: test
test: test/data/frontpage/news.ycombinator.com/index.html \
	test/data/user-comments/news.ycombinator.com/index.html
