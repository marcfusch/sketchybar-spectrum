APP       := SketchySpectrum
BUNDLE    := build/$(APP).app
PREFIX    ?= $(HOME)/Applications
BINDIR    ?= /opt/homebrew/bin
SIGN_ID   ?= -
BUNDLE_ID := com.marcfusch.SketchySpectrum
EXE       := $(PREFIX)/$(APP).app/Contents/MacOS/$(APP)
CONFIG    := $(HOME)/.config/sketchybar-spectrum/config.json

.PHONY: all build bundle install config run stop demo logs uninstall reset-permission clean

all: bundle

build:
	swift build -c release

bundle: build
	rm -rf $(BUNDLE)
	mkdir -p $(BUNDLE)/Contents/MacOS
	cp .build/release/$(APP) $(BUNDLE)/Contents/MacOS/
	cp Resources/Info.plist $(BUNDLE)/Contents/
	codesign --force --sign "$(SIGN_ID)" $(BUNDLE)

install: bundle config
	mkdir -p $(PREFIX)
	rm -rf $(PREFIX)/$(APP).app
	cp -R $(BUNDLE) $(PREFIX)/
	ln -sf $(EXE) $(BINDIR)/sketchyspectrum

config:
	@mkdir -p $(dir $(CONFIG))
	@[ -f $(CONFIG) ] || (cp config.example.json $(CONFIG) && echo "created $(CONFIG)")

# Installs and (re)starts the LaunchAgent, picking up the new build.
run: install
	-@pkill -x $(APP) && sleep 0.5
	$(EXE) --restart-service

stop:
	-$(EXE) --stop-service

# Stops the service; `make run` brings it back.
demo: install stop
	-@pkill -x $(APP) && sleep 0.5
	open -g $(PREFIX)/$(APP).app --args --demo

logs:
	tail -f /tmp/sketchyspectrum_$(USER).err.log

uninstall:
	-$(EXE) --uninstall-service
	rm -rf $(PREFIX)/$(APP).app $(BINDIR)/sketchyspectrum

reset-permission:
	tccutil reset AudioCapture $(BUNDLE_ID)

clean:
	rm -rf .build build
