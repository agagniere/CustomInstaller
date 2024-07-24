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
ifeq "$(origin Downloader)" 'undefined'
	Downloader      := $(shell command -v wget > /dev/null && echo wget || echo curl)
endif

FedoraVersion       ?= 40-1.14

# Workstation | Server
FedoraEdition       ?= Workstation

# x86_64 | aarch64 | ppc64le | s390x
Architecture        ?= x86_64

FullName            ?= Your NAME
UserName            ?= admin
ifeq "$(origin Password)" 'undefined'
	Password        := $(shell openssl passwd -6 -salt sugar admin)
endif
ifeq "$(origin RootPassword)" 'undefined'
	RootPassword    := $(Password)
endif
EmailAddress        ?= your.name@example.com
WorldRegion         ?= America
CountryCode         ?= US
City                ?= New_York
Languages           ?= en_US.utf8
KeyboardLayouts     ?= us
NtpPool             ?= 2.fedora.pool.ntp.org
DefaultEntry        ?= shutdown
ifeq "$(origin TimeZone)" 'undefined'
	TimeZone        := $(WorldRegion)/$(City)
endif

# In templates, only substitute variables listed here
ExportedVariables   += FullName UserName Password RootPassword TimeZone Languages KeyboardLayouts NtpPool
# ---------------------------------------------

# ---------- Computed / Preset ----------
# Commands
GPG_VERIFY          := gpgv
OPENSSL             := openssl
XORRISO             := xorriso -no_rc
ENVSUBST            := envsubst
MAKE_FAT            := mkfs.fat
MKDIR_FAT           := mmd
CP_FAT              := mcopy

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
	SHELL           := bash
	.SHELLFLAGS     := -o errexit -o nounset -o pipefail -c
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

FedoraMajor         := $(shell cut -d- -f1 <<< "$(FedoraVersion)")
IsoLabel            := Fedora_$(FedoraVersion)_$(Architecture)
FatLabel            := BOOT_EFI
MakeFatOptions      := -C -n $(FatLabel)

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
ExtractedBootloaders:= $(addprefix $(ExtractedFolder)/,BOOT$(ARCHEFI).EFI grub$(ArchEFI).efi mm$(ArchEFI).efi)
KickstartScripts    := $(KickstartTemplates:kickstart/%=$(KickstartFolder)/%)
GrubConfig          := $(GrubFolder)/grub.cfg
IsoImage            := $(GeneratedFolder)/$(IsoLabel).iso
SignedIsoImage      := $(GeneratedFolder)/$(IsoLabel)_signed.iso
EfiBootFiles        := $(ExtractedBootloaders) $(GrubConfig)
EfiBoot             := $(GeneratedFolder)/efiboot.img
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

# ---------- Functions ----------
check_command        = command -v $(value $(1)) > /dev/null || \
	$(ECHO) "$(PP_error)Missing dependency $(Bold)$(firstword $(value $(1)))$(EOC)," \
	"consider installing it or overriding the $(Bold)$(Italic)$(1)$(EOC) variable"
# -------------------------------

#Exporting variables for envsubst
$(foreach varible,$(ExportedVariables),$(eval export $(variable)))

# Phony rules

##@ General

default: help summary ## When no target is specified, display the help and summary

summary: ## Sum up what the makefile will do, given the current configuration
	@$(ECHO) "\nReady to generate a bootable ISO for Fedora $(PP_input)$(FedoraMajor)$(EOC) ($(FedoraVersion))\n"
	@$(ECHO) "When ready:\n  make $(PP_command)$(PP_variable)<step>$(EOC)\n"
	@$(ECHO) "$(PP_section)$(PP_command)download$(EOC)\n  will download:"
	@printf  "  - %s\n" $(FedoraKeyName) $(OfficialCheckName) $(OfficialIsoName)
	@$(ECHO) "  to     $(PP_input)$(DownloadsFolder)$(EOC)"
	@$(ECHO) "  using  $(PP_input)$(Downloader)$(EOC)\n"
	@$(ECHO) "$(PP_section)$(PP_command)certificates$(EOC)"
	@$(ECHO) "  will generate certificates for Machine Owner Key verification"
	@$(ECHO) "  to     $(PP_input)$(CertificateFolder)$(EOC)"
	@$(ECHO) "  using  $(PP_input)$(OPENSSL)$(EOC)\n"
	@$(ECHO) "$(PP_section)$(PP_command)extract$(EOC)"
	@$(ECHO) "  will extract from the official ISO:"
	@printf  "  - %s\n" $(ExtractedBootloaders:$(ExtractedFolder)/%=%)
	@$(ECHO) "  to     $(PP_input)$(ExtractedFolder)$(EOC)"
	@$(ECHO) "  using  $(PP_input)$(firstword $(XORRISO))$(EOC)\n"
	@$(ECHO) "$(PP_section)$(PP_command)evaluate$(EOC)\n  will fill the values:"
	@printf  "  - % -20s: %.40s\n" $(foreach var,$(ExportedVariables),$(var) '$(subst $(quote),,$(value $(var)))')
	@$(ECHO) "  in :$(addprefix \n  - ,$(KickstartTemplates))"
	@$(ECHO) "  to     $(PP_input)$(KickstartFolder)$(EOC)"
	@$(ECHO) "  using  $(PP_input)$(ENVSUBST)$(EOC)\n"
	@$(ECHO) "$(PP_section)$(PP_command)grub/config$(EOC)"
	@$(ECHO) "  will generate a grub configuration with the following entries:"
	@printf  "  - % -15s: $(PP_input)%.45s$(EOC)\n" $(foreach entry,$(filter kickstart/entry_%,$(KickstartTemplates)),\
	`a=$(entry);b=$${a#*entry_};c=$${b%.*};echo $$c`\
	"`head -1 $(entry) | cut -d'\"' -f2`")
	@$(ECHO) "\n$(PP_section)$(PP_command)help$(EOC)\n  to learn how to use this makefile\n"

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

check/fat: ## Check that FAT manipulation tools are installed
	@$(call check_command,MAKE_FAT)
	@$(call check_command,MKDIR_FAT)
	@$(call check_command,CP_FAT)

check/all: check/downloader check/gpg_verifier check/shasum check/openssl check/xorriso check/envsubst ## Check that all requirements are installed

.PHONY: check/all check/downloader check/gpg_verifier check/shasum check/openssl check/xorriso check/envsubst

##@ Individual steps

download: $(OfficialIso) ## Download the official ISO (and check its integrity)

certificates: $(MachineOwnerPEM) $(MachineOwnerDER) $(MachineOwnerKey) ## Generate a private public key pair used to sign the bootloader

extract: $(ExtractedBootloaders) ## Extract bootloaders from the official ISO

evaluate: $(KickstartScripts) ## Evaluate kickstart scripts templates with the current values.

grub/config: $(GrubConfig) ## Generate GRUB configuration: Create an entry for each kickstart script starting with 'entry_'.

boot/image: $(EfiBoot) ## Generate an image used to boot in EFI mode

.PHONY: download certificates extract evaluate grub/config boot/image

##@ ISO Generation

iso: $(IsoImage) ## Generate a bootable ISO image

.PHONY: iso

##@ Removing generated files

clean/downloads: ## Remove downloaded files
	$(RM) $(OfficialIso) $(OfficialChecksum) $(FedoraKey)

clean/certificates: ## Remove certificates
	$(RM) -r $(CertificateFolder)

clean/extracted: ## Remove files extracted from the official ISO
	$(RM) -r $(ExtractedFolder)

clean/evaluated: ## Remove generated kickstart scripts
	$(RM) -r $(KickstartFolder)

clean/iso: ## Only remove generated ISO images
	$(RM) $(IsoImage)

clean: clean/extracted ## Clean all generated and extracted files
	$(RM) -r $(GeneratedFolder)

clean/all: clean/downloads clean ## Remove all generated, extracted and downloaded files

.PHONY: clean/downloads clean/certificates clean/extracted clean/evaluated clean/iso clean clean/all

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
		-subj '/C=$(CountryCode)/L=$(City)/CN=$(FullName)/emailAddress=$(EmailAddress)' \
		-addext 'subjectKeyIdentifier=hash' \
		-addext 'authorityKeyIdentifier=keyid:always,issuer' \
		-addext "basicConstraints=critical,CA:FALSE" \
		-addext "extendedKeyUsage=codeSigning" \
		-addext "nsComment=OpenSSL Generated Certificate" \
		-outform DER -keyout $(MachineOwnerKey) -out $(MachineOwnerDER)

$(MachineOwnerPEM): $(MachineOwnerDER) | $$(@D) check/openssl
	$(OPENSSL) x509 -in $< -inform DER -outform PEM -out $@

$(ExtractedBootloaders): $(OfficialIso) | $$(@D) check/xorriso
	$(XORRISO) -osirrox on -indev $< -extract /EFI/BOOT/$(@F) $@
	@touch $@

$(KickstartScripts): $(KickstartFolder)/%.cfg: kickstart/%.cfg | $$(@D) check/envsubst
	$(ENVSUBST) '$(ExportedVariables:%=$$%)' < $< | sed 's|^%shard \(.*\)$$|%ksappend /run/install/repo/kickstart/\1.cfg|' > $@

$(GrubFolder)/entries.cfg: $(filter kickstart/entry_%,$(KickstartTemplates)) | $$(@D)
	printf "default=$(DefaultEntry)\n" > $@
	printf "search --no-floppy --set=root --label '$(IsoLabel)'\n\n" >> $@
	for entry in $^ ; \
	do \
		title=$$(head -1 $$entry | cut -d'"' -f2) ; \
		id=$${entry#*entry_} ; id=$${id%.*} ; \
		printf "menuentry '%s' --class fedora --class gnu --class os --id '%s' {\n\tset gfxpayload=keep\n\tlinuxefi /images/pxeboot/vmlinuz inst.stage2=hd:LABEL=$(IsoLabel) inst.repo=hd:LABEL=$(IsoLabel):/ inst.ks=hd:LABEL=$(IsoLabel):/%s quiet\n\tinitrdefi /images/pxeboot/initrd.img\n}\n\n" "$$title" "$$id" "$$entry" >> $@ ; \
	done

$(GrubConfig): grub/prefix.cfg $(GrubFolder)/entries.cfg grub/suffix.cfg | $$(@D)
	cat $^ > $@

$(EfiBoot): $(ExtractedBootloaders) $(GrubConfig) | $$(@D) check/fat
	$(RM) $@
	bytes=$$(du --bytes --total --summarize $^ | tail -1 | cut -f1) && \
	kilos=$$(echo "((($$bytes + 1023) / 1024 + 8192 + 1023) / 1024) * 1024" | bc) && \
	$(MAKE_FAT) $(MakeFatOptions) `(( $$kilos >= 36864 )) && echo -F 32` $@ $$kilos
	$(MKDIR_FAT) -i $@ "::/EFI" "::/EFI/BOOT"
	$(CP_FAT) -i $@ $^ "::/EFI/BOOT"

$(IsoImage): $(OfficialIso) $(GrubConfig) $(EfiBoot) $(KickstartScripts) | $$(@D) check/xorriso
	$(RM) $@
	$(XORRISO) \
		-indev $< \
		-outdev $@ \
		-map $(GrubConfig)      EFI/BOOT/grub.cfg \
		-map $(KickstartFolder) kickstart \
		-chmod_r a+r,a-w / -- \
		-as mkisofs \
		-iso-level 3 -full-iso9660-filenames \
		-joliet -joliet-long -rational-rock \
		-volid "$(IsoLabel)" --preparer "$(FullName)" \
		-partition_offset 16 \
		-append_partition 2 'C12A7328-F81F-11D2-BA4B-00A0C93EC93B' $(EfiBoot) \
		-appended_part_as_gpt \
		-eltorito-alt-boot \
		-e '--interval:appended_partition_2:all::' \
		-no-emul-boot

# Put at the end because it is not well parsed by editors providing syntax color
quote := '
