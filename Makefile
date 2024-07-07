##
 # Generate a custom ISO to install Fedora
##

# ---------- Customizable parameters ----------
# wget | curl
Downloader      ?= wget

FedoraVersion   ?= 40-1.14

# Workstation | Server
FedoraFlavor    ?= Workstation

# x86_64 | aarch64 | ppc64le
Architecture    ?= x86_64
# ---------------------------------------------

# ---------- Computed ----------
ifeq "$(shell uname)" "Darwin"
	DownloadsFolder := $(shell osascript -e 'POSIX path of (path to downloads folder)')
else
	DownloadsFolder != xdg-user-dir DOWNLOADS
endif

ifeq "$(Downloader)" 'wget'
	DOWNLOAD    := wget --directory $(DownloadsFolder) --no-clobber --quiet --show-progress
else
	DOWNLOAD    := curl --output-dir $(DownloadsFolder) --remote-name
endif

FedoraMajor     := $(shell cut -d '-' -f 1 <<< $(FedoraVersion))
OfficialIsoURL  := https://download.fedoraproject.org/pub/fedora/linux/releases/$(FedoraMajor)/$(FedoraFlavor)/$(Architecture)/iso
OfficialIsoName := Fedora-$(FedoraFlavor)-Live-$(Architecture)-$(FedoraVersion).iso
OfficialIso     := $(DownloadsFolder)/$(OfficialIsoName)
# ------------------------------

summary:
	@echo "make build"
	@echo "will download \t"$(OfficialIsoName)
	@echo "to            \t"$(DownloadsFolder)
	@echo "using         \t"$(Downloader)

build:


# Concrete rules

$(OfficialIso):
	@echo $(DOWNLOAD) $(OfficialIsoURL)/$(@F)

full_clean:
	rm $(OfficialIso)
