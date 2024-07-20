##
 # Generate a custom ISO to install Fedora
 #
 # Requirements:
 # - gpgv
 # - wget or curl
 # - sha256sum or shasum
 # - openssl
 # - xorriso
 #
 # Customizable parameters can be set via environment variables or the command line
 # Other variables can be overridden via the the command line
 #
 # For help about how to use this makefile:
 # make help
 #
 # For a human-readable description of what the current configuration is:
 # make summary
##

##
 # |         |  Workstation  |     Server    |
 # | ------- | ------------- | ------------- |
 # | x86_64  |  To be tested | To be tested  |
 # | aarch64 |       X       | To be tested  |
 # | ppc64le | Download only | Download only |
 # |  s390x  |       X       | Download only |
 #
 # TL;DR: x86_64  -> Workstation
 #        aarch64 -> Server
 #        ppc64le, s390x !?
##

# ---------- Customizable parameters ----------
# wget | curl
ifeq "$(origin Downloader)" "undefined"
	Downloader      := $(shell command -v wget > /dev/null && echo wget || echo curl)
endif

FedoraVersion       ?= 40-1.14

# Workstation | Server
FedoraEdition       ?= Workstation

# x86_64 | aarch64 | ppc64le | s390x
Architecture        ?= x86_64

FullName            ?= $(shell { read -p "Full Name: " name ; echo $$name ; } )
UserName            ?= $(shell { read -p "User Name: " name ; echo $$name ; } )
Password            ?= $(shell { read -p 'Salt: ' salt && read -s -p "Password: " word && openssl passwd -6 -salt $$salt $$word ; } )
RootPassword        ?= Password
EmailAddress        ?= $(shell { read -p "Email Address: " adress ; echo $$adress; } )
CountryCode         ?= FR
Locality            ?= $(shell { read -p "City: " city ; echo $$city ; } )

# Only substitute variables listed here
EnvsubstFormat      += '$FullName$UserName$Password$RootPassword$EmailAddress'
# ---------------------------------------------

# ---------- For use in envsubst ----------
export FullName
export UserName
export Password
export RootPassword
export EmailAddress
# -----------------------------------------

# ---------- Computed / Preset ----------
# Commands
GPG_VERIFY          := gpgv
OPENSSL             := openssl
XORRISO             := xorriso -no_rc
ENVSUBST            := envsubst

# Folders
GeneratedFolder     := generated
ExtractedFolder     := extracted
CertificateFolder   := $(GeneratedFolder)/certificates
KickstartFolder     := $(GeneratedFolder)/kickstart
GrubFolder          := $(GeneratedFolder)/grub

# OS specific
ifeq "$(shell uname)" "Darwin"
	ECHO            := echo
	DownloadsFolder := $(shell osascript -e 'POSIX path of (path to downloads folder)')
	SHA_SUM         := shasum --algorithm 256
else
	SHELL           := bash -o errexit -o nounset -o pipefail
	ECHO            := echo -e
	DownloadsFolder != xdg-user-dir DOWNLOAD
	SHA_SUM         := sha256sum
endif

# Download command
ifeq "$(Downloader)" 'wget'
	DOWNLOAD        := wget --directory $(DownloadsFolder) --no-clobber --quiet --show-progress
else ifeq "$(Downloader)" 'curl'
	DOWNLOAD        := curl --output-dir $(DownloadsFolder) --remote-name --location
else
	DOWNLOAD        := $(Downloader)
endif

# Architecture specific
ifeq "$(Architecture)" 'x86_64'
	ARCHEFI         := X64
	ArchEFI         := x64
	FedoraChannel   := fedora/linux
else ifeq "$(Architecture)" 'aarch64'
	ARCHEFI         := AA64
	ArchEFI         := aa64
	FedoraChannel   := fedora/linux
else
	FedoraChannel   := fedora-secondary
endif

# Edition specific
ifeq "$(FedoraEdition)" 'Workstation'
	FedoraMethod    := Live
else
# dvd | netinst
	FedoraMethod    := netinst
endif

FedoraMajor         := $(shell cut --delimiter '-' --field 1 <<< "$(FedoraVersion)")
IsoLabel            := Fedora_$(FedoraVersion)_$(Architecture)
FatLabel            := BOOT_EFI

# URLs
FedoraKeyURL        := https://fedoraproject.org
OfficialIsoURL      := https://download.fedoraproject.org/pub/$(FedoraChannel)/releases/$(FedoraMajor)/$(FedoraEdition)/$(Architecture)/iso

# File names
FedoraKeyName       := fedora.gpg
OfficialIsoName     := Fedora-$(FedoraEdition)-$(FedoraMethod)-$(Architecture)-$(FedoraVersion).iso
OfficialCheckName   := Fedora-$(FedoraEdition)-$(FedoraVersion)-$(Architecture)-CHECKSUM

# Input Files
KickstartTemplates  := $(wildcard kickstart/*.cfg)

# Files created by this Makefile
FedoraKey           := $(DownloadsFolder)/$(FedoraKeyName)
OfficialIso         := $(DownloadsFolder)/$(OfficialIsoName)
OfficialChecksum    := $(DownloadsFolder)/$(OfficialCheckName)
MachineOwnerKey     := $(CertificateFolder)/MOK.priv
MachineOwnerDER     := $(CertificateFolder)/MOK.der
MachineOwnerPEM     := $(CertificateFolder)/MOK.pem
ExtractedShim       := $(ExtractedFolder)/shim-$(Architecture).efi
ExtractedGrub       := $(ExtractedFolder)/grub-$(Architecture).efi
ExtractedMokManager := $(ExtractedFolder)/mok_manager-$(Architecture).efi
KickstartScripts    := $(KickstartTemplates:kickstart/%=$(KickstartFolder)/%)
GrubConfig          := $(GrubFolder)/grub.cfg
# ---------------------------------------

# ---------- Make Configuration ----------
.DELETE_ON_ERROR: # Delete the target of a rule if its recipe execution fails
.SUFFIXES:        # Disable atomatic suffix guessing
#.ONESHELL:        # Perform a single shell invocation per recipe. Only makes sense if the shell is set to exit on error !
# ----------------------------------------

# ---------- Colors ----------
Red                 := \033[31m
Cyan                := \033[36m
Bold                := \033[1m
Italic              := \033[3m
EOC                 := \033[0m
PP_command          := $(Cyan)
PP_section          := $(Bold)
PP_input            := $(Bold)
PP_error            := $(Red)
PP_variable         := $(Italic)
# ----------------------------

check_command        = command -v $(value $(1)) > /dev/null || \
	$(ECHO) "$(PP_error)Missing dependency $(Bold)$(firstword $(value $(1)))$(EOC)," \
	"consider installing it or overriding the $(Bold)$(Italic)$(1)$(EOC) variable"

# Phony rules

##@ General

default: help summary ## When no target is specified, display the help and summary

summary: ## Sum up what the makefile will do, given the current configuration
	@$(ECHO) "\nReady to generate a bootable ISO for Fedora $(PP_input)$(FedoraMajor)$(EOC) ($(FedoraVersion))\n"
	@$(ECHO) "When ready:\n  make $(PP_command)$(PP_variable)<step>$(EOC)\n"
	@$(ECHO) "$(PP_section)$(PP_command)download$(EOC)\n  will download:"
	@$(ECHO) "  - "$(FedoraKeyName)
	@$(ECHO) "  - "$(OfficialCheckName)
	@$(ECHO) "  - "$(OfficialIsoName)
	@$(ECHO) "  to     $(PP_input)$(DownloadsFolder)$(EOC)"
	@$(ECHO) "  using  $(PP_input)$(Downloader)$(EOC)\n"
	@$(ECHO) "$(PP_section)$(PP_command)certificates$(EOC)"
	@$(ECHO) "  will generate certificates for Machine Owner Key verification"
	@$(ECHO) "  to     $(PP_input)$(realpath $(CertificateFolder))$(EOC)"
	@$(ECHO) "  using  $(PP_input)$(OPENSSL)$(EOC)\n"
	@$(ECHO) "$(PP_section)$(PP_command)extract$(EOC)"
	@$(ECHO) "  will extract from the official ISO:"
	@$(ECHO) "  - BOOT$(ARCHEFI).EFI"
	@$(ECHO) "  - grub$(ArchEFI).efi"
	@$(ECHO) "  - mm$(ArchEFI).efi"
	@$(ECHO) "  to     $(PP_input)$(realpath $(ExtractedFolder))$(EOC)"
	@$(ECHO) "  using  $(PP_input)$(firstword $(XORRISO))$(EOC)\n"
	@$(ECHO) "$(PP_section)$(PP_command)evaluate$(EOC)"
	@$(ECHO) "  will fill the values:"
	@$(ECHO) "  - UserName: $(PP_input)$(UserName)$(EOC)"
	@$(ECHO) "  - FullName: $(PP_input)$(FullName)$(EOC)"
	@$(ECHO) "  in :$(addprefix \n  - ,$(KickstartTemplates))"
	@$(ECHO) "  to     $(PP_input)$(realpath $(KickstartFolder))$(EOC)"
	@$(ECHO) "  using  $(PP_input)$(ENVSUBST)$(EOC)\n"
	@$(ECHO) "$(PP_section)$(PP_command)help$(EOC)\n  to learn how to use this makefile\n"

help: ## Display this help
	@awk 'BEGIN {FS = ":.*##"; printf "\nThis Makefile allows one to generate a custom ISO to install Fedora\n\nUsage:\n  make $(PP_command)$(PP_variable)<target>$(EOC)\n"} /^[\/a-zA-Z_0-9-]+:.*?##/ { printf "  $(PP_command)%-20s$(EOC) %s\n", $$1, $$2 } /^##@/ { printf "\n$(PP_section)%s$(EOC):\n", substr($$0, 5) } ' $(MAKEFILE_LIST)

raw_help: ## Display the help without color
	@$(MAKE) help --no-print-directory PP_command= PP_section= PP_variable= EOC=

.PHONY: default summary help

##@ Check for requirements

check/downloader: ## Check that the choosen downloader is installed
	@$(call check_command,Downloader)

check/gpg_verifier: ## Check that the GPG verifier is installed
	@$(call check_command,GPG_VERIFY)

check/shasum: ## Check that the sum checker is installed. It is used to verify files integrity
	@$(call check_command,SHA256SUM)

check/openssl: ## Check that openssl is installed. It is used to generate certificates
	@$(call check_command,OPENSSL)

check/xorriso: ## Check that xorriso is installed. It is needed to extract from and modify ISOs
	@$(call check_command,XORRISO)

check/envsubst: ## Check that envsubst is installed. It is used to evaluate templates using the environment
	@$(call check_command,ENVSUBST)

check/all: check/downloader check/gpg_verifier check/shasum check/openssl check/xorriso check/envsubst ## Check that all requirements are installed

.PHONY: check/all check/downloader check/gpg_verifier check/shasum check/openssl check/xorriso check/envsubst

##@ Individual steps

download: $(OfficialIso) ## Download the official ISO (and check its integrity)

certificates: $(MachineOwnerPEM) $(MachineOwnerDER) $(MachineOwnerKey) ## Generate a private public key pair used to sign the bootloader

extract: $(ExtractedShim) $(ExtractedGrub) $(ExtractedMokManager) ## Extract bootloaders from the official ISO

evaluate: $(KickstartScripts) ## Evaluate kickstart scripts templates with the current values.

grub/config: $(GrubConfig) ## Generate GRUB configuration: Create an entry for each kickstart script starting with 'entry_'.

.PHONY: download certificates extract evaluate grub/config

##@ Removing generated files

clean/downloads: ## Remove downloaded files
	$(RM) $(OfficialIso) $(OfficialChecksum) $(FedoraKey)

clean/certificates: ## Remove certificates
	$(RM) -r $(CertificateFolder)

clean/extracted: ## Remove files extracted from the official ISO
	$(RM) -r $(ExtractedFolder)

clean/evaluated: ## Remove generated kickstart scripts
	$(RM) -r $(KickstartFolder)

clean: clean/extracted ## Clean all generated and extracted files
	$(RM) -r $(GeneratedFolder)

clean/all: clean/downloads clean ## Remove all generated, extracted and downloaded files

.PHONY: clean/downloads clean/certificates clean/extracted clean/evaluated clean clean/all

# Concrete rules

$(DownloadsFolder) $(GeneratedFolder) $(ExtractedFolder) $(CertificateFolder) $(KickstartFolder) $(GrubFolder):
	mkdir -p $@

# --------------- Second Expansion ---------------
# When a rule is expanded, both the target and the prerequisites
# are immediately evaluated. Enabling a second expansion allows
# a prerequisite to use automatic variables like $@, $*, etc
.SECONDEXPANSION:

$(FedoraKey): | $$(@D) check/downloader
	$(DOWNLOAD) $(FedoraKeyURL)/$(@F)
	@touch $@

$(OfficialChecksum): $(FedoraKey) | $$(@D) check/downloader check/gpg_verifier
	$(DOWNLOAD) $(OfficialIsoURL)/$(@F)
	$(GPG_VERIFY) --keyring $< $@
	@touch $@

$(OfficialIso): $(OfficialChecksum) | $$(@D) check/downloader check/shasum
	$(DOWNLOAD) $(OfficialIsoURL)/$(@F)
	( cd $(@D) && $(SHA_SUM) --ignore-missing --check $(<F) 2> /dev/null )
	@touch $@
# Update the timestamp to the time downloaded, not the time it was created upstream
# Because of course Fedora can only generate the checksum AFTER generating the ISO
# Using the upstream time would ALWAYS want to re-download the ISO as its dependency would be newer

$(MachineOwnerKey) $(MachineOwnerDER) &: | $$(@D) check/openssl
	$(OPENSSL) req -new -x509 -newkey rsa:2048 -nodes -days 3650 \
		-subj '/C=$(CountryCode)/L=$(Locality)/CN=$(FullName)/emailAddress=$(EmailAddress)' \
		-addext 'subjectKeyIdentifier=hash' \
		-addext 'authorityKeyIdentifier=keyid:always,issuer' \
		-addext "basicConstraints=critical,CA:FALSE" \
		-addext "extendedKeyUsage=codeSigning" \
		-addext "nsComment=OpenSSL Generated Certificate" \
		-outform DER -keyout $(MachineOwnerKey) -out $(MachineOwnerDER)

$(MachineOwnerPEM): $(MachineOwnerDER) | $$(@D) check/openssl
	$(OPENSSL) x509 -in $< -inform DER -outform PEM -out $@

$(ExtractedShim) $(ExtractedGrub) $(ExtractedMokManager) &: $(OfficialIso) | $$(@D) check/xorriso
	$(XORRISO) -osirrox on -indev $< \
		-extract /EFI/BOOT/BOOT$(ARCHEFI).EFI $(ExtractedShim) \
		-extract /EFI/BOOT/grub$(ArchEFI).efi $(ExtractedGrub) \
		-extract /EFI/BOOT/mm$(ArchEFI).efi   $(ExtractedMokManager)

$(KickstartFolder)/%.cfg: kickstart/%.cfg | $$(@D) check/envsubst
	$(ENVSUBST) $(EnvsubstFormat) < $< > $@

$(GrubFolder)/entries.cfg: $(filter kickstart/entry_%,$(KickstartTemplates)) | $$(@D)
	printf "search --no-floppy --set=root --label '$(IsoLabel)'\n\n" > $@
	for entry in $^ ; \
	do \
		$(ECHO) "$(Bold)# $$entry #$(EOC)" ; \
		title=$$(head -1 $$entry | cut -d'"' -f2) ; \
		id=$${entry#*entry_} ; id=$${id%.*} ; \
		$(ECHO) "'$$title', '$$id'" ; \
		printf "menuentry '%s' --class fedora --class gnu --class os --id '%s' {\n\tset gfxpayload=keep\n\tlinuxefi /images/pxeboot/vmlinuz inst.stage2=hd:LABEL=$(IsoLabel) inst.repo=hd:LABEL=$(IsoLabel):/ inst.ks=hd:LABEL=$(IsoLabel):/%s quiet\n\tinitrdefi /images/pxeboot/initrd.img\n}\n" "$$title" "$$id" "$$entry" >> $@ ; \
	done

$(GrubFolder)/grub.cfg: grub/prefix.cfg $(GrubFolder)/entries.cfg grub/suffix.cfg | $$(@D)
	cat $^ > $@
