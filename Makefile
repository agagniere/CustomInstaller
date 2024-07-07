##
 # Generate a custom ISO to install Fedora
 #
 # Requirements:
 # - gpgv (brew install gnupg / apt install gpgv / dnf intall gnupg2)
 # - wget or curl
 # - sha256sum or shasum
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
	DownloadsFolder := $(shell osascript -e 'POSIX path of (path to downloads folder)')
	SHA_SUM         := shasum --algorithm 256 --ignore-missing
else
	DownloadsFolder != xdg-user-dir DOWNLOADS
	SHA_SUM         := sha256sum
endif

ifeq "$(Downloader)" 'wget'
	DOWNLOAD        := wget --directory $(DownloadsFolder) --no-clobber --quiet --show-progress
else
	DOWNLOAD        := curl --output-dir $(DownloadsFolder) --remote-name --location
endif

FedoraMajor         := $(shell cut -d '-' -f 1 <<< $(FedoraVersion))

FedoraKeyName       := fedora.gpg
FedoraKeyURL        := https://fedoraproject.org
FedoraKey           := $(DownloadsFolder)/$(FedoraKeyName)

OfficialIsoURL      := https://download.fedoraproject.org/pub/fedora/linux/releases/$(FedoraMajor)/$(FedoraFlavor)/$(Architecture)/iso
OfficialIsoName     := Fedora-$(FedoraFlavor)-Live-$(Architecture)-$(FedoraVersion).iso
OfficialIso         := $(DownloadsFolder)/$(OfficialIsoName)
OfficialCheckName   := Fedora-$(FedoraFlavor)-$(FedoraVersion)-$(Architecture)-CHECKSUM
OfficialChecksum    := $(DownloadsFolder)/$(OfficialCheckName)
# ---------------------------------------

summary:
	@echo "make download"
	@echo "will download:"
	@echo " - "$(FedoraKeyName)
	@echo " - "$(OfficialCheckName)
	@echo " - "$(OfficialIsoName)
	@echo "to            \t"$(DownloadsFolder)
	@echo "using         \t"$(Downloader)

download: $(OfficialIso)

# Concrete rules

$(FedoraKey):
	$(DOWNLOAD) $(FedoraKeyURL)/$(@F)

$(OfficialChecksum): $(FedoraKey)
	$(DOWNLOAD) $(OfficialIsoURL)/$(@F)
	$(GPG_VERIFY) --keyring $< $@ || { rm $@ && false }

$(OfficialIso): $(OfficialChecksum)
	$(DOWNLOAD) $(OfficialIsoURL)/$(@F)
	( cd $(<D) && $(SHA_SUM) --check $(<F) ) || { rm $@ && false }

full_clean:
	$(RM) $(OfficialIso) $(OfficialChecksum) $(FedoraKey)
