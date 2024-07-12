##
 # Generate a custom ISO to install Fedora
 #
 # Requirements:
 # - gpgv
 # - wget or curl
 # - sha256sum or shasum
 #
 # Customizable parameters can be set via environment variables or the command line
 # Other variables can be overridden via the the command line
##

# ---------- Customizable parameters ----------
# wget | curl
Downloader          ?= wget

FedoraVersion       ?= 40-1.14

# Workstation | Server
FedoraFlavor        ?= Workstation

# x86_64 | aarch64 | ppc64le
Architecture        ?= x86_64
# ---------------------------------------------

# ---------- Computed / Preset ----------
GPG_VERIFY          := gpgv

ifeq "$(shell uname)" "Darwin"
	ECHO            := echo
	DownloadsFolder := $(shell osascript -e 'POSIX path of (path to downloads folder)')
	SHA_SUM         := shasum --algorithm 256 --ignore-missing
else
	SHELL           := bash
	ECHO            := echo -e
	DownloadsFolder != xdg-user-dir DOWNLOADS
	SHA_SUM         := sha256sum --ignore-missing
endif

ifeq "$(Downloader)" 'wget'
	DOWNLOAD        := wget --directory $(DownloadsFolder) --no-clobber --quiet --show-progress
else
	DOWNLOAD        := curl --output-dir $(DownloadsFolder) --remote-name --location
endif

FedoraMajor         := $(shell cut --delimiter '-' --field 1 <<< "$(FedoraVersion)")

FedoraKeyName       := fedora.gpg
FedoraKeyURL        := https://fedoraproject.org
FedoraKey           := $(DownloadsFolder)/$(FedoraKeyName)

OfficialIsoURL      := https://download.fedoraproject.org/pub/fedora/linux/releases/$(FedoraMajor)/$(FedoraFlavor)/$(Architecture)/iso
OfficialIsoName     := Fedora-$(FedoraFlavor)-Live-$(Architecture)-$(FedoraVersion).iso
OfficialIso         := $(DownloadsFolder)/$(OfficialIsoName)
OfficialCheckName   := Fedora-$(FedoraFlavor)-$(FedoraVersion)-$(Architecture)-CHECKSUM
OfficialChecksum    := $(DownloadsFolder)/$(OfficialCheckName)
# ---------------------------------------

# ---------- Colors ----------
Cyan       := \033[36m
Bold       := \033[1m
Italic     := \033[3m
EOC        := \033[0m
PP_command := $(Cyan)
PP_section := $(Bold)
PP_input   := $(Bold)
# ----------------------------

# Phony rules

##@ General

default: ## When no target is specified, display the summary

summary: ## Sum up what the makefile intends on doing
	@$(ECHO) "\nReady to generate a bootable ISO for Fedora $(PP_input)$(FedoraMajor)$(EOC) ($(FedoraVersion))\n"
	@$(ECHO) "When ready:\n  make $(PP_command)$(Italic)<step>$(EOC)\n"
	@$(ECHO) "$(PP_section)$(PP_command)download$(EOC) will download:"
	@$(ECHO) "  - "$(FedoraKeyName)
	@$(ECHO) "  - "$(OfficialCheckName)
	@$(ECHO) "  - "$(OfficialIsoName)
	@$(ECHO) "  to     $(PP_input)$(DownloadsFolder)$(EOC)"
	@$(ECHO) "  using  $(PP_input)$(Downloader)$(EOC)"

help: ## Display this help
	@awk 'BEGIN {FS = ":.*##"; printf "\nThis Makefile allows one to generate a custom ISO to install Fedora\n\nUsage:\n  make $(PP_command)<target>$(EOC)\n"} /^[a-zA-Z_0-9-]+:.*?##/ { printf "  $(PP_command)%-15s$(EOC) %s\n", $$1, $$2 } /^##@/ { printf "\n$(PP_section)%s$(EOC):\n", substr($$0, 5) } ' $(MAKEFILE_LIST)

raw_help: ## Display the help without color
	@$(MAKE) help --no-print-directory PP_command= PP_section= EOC=

.PHONY: default summary help

##@ Individual steps

download: $(OfficialIso) ## Only download the official ISO (and check its integrity)

.PHONY: download

# Concrete rules

$(FedoraKey):
	$(DOWNLOAD) $(FedoraKeyURL)/$(@F)

$(OfficialChecksum): $(FedoraKey)
	$(DOWNLOAD) $(OfficialIsoURL)/$(@F)
	$(GPG_VERIFY) --keyring $< $@ || { rm $@ && false ; }

$(OfficialIso): $(OfficialChecksum)
	$(DOWNLOAD) $(OfficialIsoURL)/$(@F)
	( cd $(@D) && $(SHA_SUM) --check $(<F) ) || { rm $@ && false ; }

full_clean:
	$(RM) $(OfficialIso) $(OfficialChecksum) $(FedoraKey)
