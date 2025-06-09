# Custom Fedora Installer

This set of scripts allows one to generate an ISO image with a custom set of RPMs and an automated installation script.

The generated ISO can then be restored to a USB key and perform a tailored installation of Fedora, without having to disable Secure Boot.

## As a downloader

If you just want to download Fedora official ISOs, this makefile can be of use:
 - it will place the official ISO in your download folder
 - verify the ISO's integrity using the official checksum
 - verify the checksum was signed by Fedora

```shell
# To download the Workstation ISO for x86_64:
make download

# You can choose the edition and architecture:
FedoraEdition=KDE Architecture=aarch64 make download

# You can even choose the installation method for the server edition:
FedoraEdition=Server Architecture=ppc64le make download FedoraMethod=dvd

# And you can choose between wget and curl
Downloader=curl make download
```

Downloadable status as of Fedora 42 :

|           | Workstation | KDE | Server |
|:----------|:-----------:|:---:|:------:|
| `x86_64`  | ✅          | ✅  | ✅     |
| `aarch64` | ✅          | ✅  | ✅     |
| `ppc64le` | ✅          | ✅  | ✅     |
| `s390x`   | ❌          | ❌  | ✅     |

## Generating an ISO

For conveniance, you can place all values you want to customize in a local file `values.sh`:

```bash
# Latest Fedora release
FedoraVersion=42-1.1

# Workstation | KDE | Server
FedoraEdition=Workstation

# x86_64 | aarch64 | ppc64le | s390x
Architecture=x86_64

# wget | curl (defaults to the first available)
# Downloader=wget

# Used to create the initial user of the OS
UserName=mname
Password=`read -s -p 'Password: ' password && openssl passwd -6 -salt SomeRandomSalt $password`
RootPassword=`read -s -p 'Root Password: ' password && openssl passwd -6 -salt SomeRandomSalt $password`

# Used to sign the bootloader (except WorldRegion that is used with City to specify the timezone)
FullName="My NAME"
EmailAddress=my.name@example.com
WorldRegion=America
CountryCode=US
City=New_York

# Used during installation and on the target system
KeyboardLayouts="us,'cz (qwerty)'"
Languages=en_US
# Languages="--addsupport=en_GB en_US.utf8"
NtpPool=3.fedora.pool.ntp.org

# It is possible to override the timezone (if the City you want mentionned in the certificate is not in https://vpodzime.fedorapeople.org/timezones_list.txt)
# TimeZone=America/Toronto
```

Then source the file before calling make:

```bash
( set -a && source ./values.sh && make iso )
```

## Adding a custom entry

You want an ISO that install a specific set of packages, with a tailored partitioning scheme ? You don't have to write a GRUB configuration file !

Just create a `.cfg` file with a name starting with `entry_` in the `kickstart` folder, like `kickstart/entry_myinstaller.cfg`:

```bash
# Entry name : "Install things my way" <- Set the name of your entry as it will appear in the GRUB menu

# Include other kickstart files with this special syntax:
%shard common
# It will include kickstart/common.cfg

# And use any official kickstart command:

%packages
	@Headless-Management
	@Container-Management --optional
%end

skipx

selinux --enforcing

clearpart --all --drives=sda
partition /boot/efi           --ondisk=sda 1024
partition /     --fstype=ext4 --ondisk=sda --grow
partition /home --fstype=ext4 --ondisk=sdb --noformat --usepart=LABEL=MY_HOME
```

If you want this entry to be the default in GRUB, add `DefaultEntry=myinstaller` to `values.sh`.

## Usage

```console
$ make help

This Makefile allows one to generate a custom ISO to install Fedora

Usage:
  make <target>

General:
  default               When no target is specified, display the help and summary
  summary               Sum up what the makefile will do, given the current configuration
  help                  Display this help
  raw_help              Display the help without color

Check for requirements:
  check/downloader      Check that the choosen downloader is installed
  check/gpg_verifier    Check that the GPG verifier is installed
  check/shasum          Check that the sum checker is installed. It is used to verify files integrity
  check/openssl         Check that openssl is installed. It is used to generate certificates
  check/xorriso         Check that xorriso is installed. It is needed to extract from and modify ISOs
  check/envsubst        Check that envsubst is installed. It is used to evaluate templates using the environment
  check/fat             Check that FAT manipulation tools are installed
  check/all             Check that all requirements are installed

Individual steps:
  download              Download the official ISO (and check its integrity)
  certificates          Generate a private public key pair used to sign the bootloader
  extract               Extract bootloaders from the official ISO
  evaluate              Evaluate kickstart scripts templates with the current values.
  grub/config           Generate GRUB configuration: Create an entry for each kickstart script starting with 'entry_'.
  boot/image            Generate an image used to boot in EFI mode

ISO Generation:
  iso                   Generate a bootable ISO image

Removing generated files:
  clean/downloads       Remove downloaded files
  clean/certificates    Remove certificates
  clean/extracted       Remove files extracted from the official ISO
  clean/evaluated       Remove generated kickstart scripts
  clean/iso             Only remove generated ISO images
  clean                 Clean all generated and extracted files
  clean/all             Remove all generated, extracted and downloaded files
```

## Sample summary

```console
$ make summary

Ready to generate a bootable ISO for Fedora 42 (42-1.1)

When ready:
  make <step>

download
  will download:
  - fedora.gpg
  - Fedora-Workstation-42-1.1-x86_64-CHECKSUM
  - Fedora-Workstation-Live-42-1.1.x86_64.iso
  to     /Users/toto/Downloads/
  using  curl

certificates
  will generate certificates for Machine Owner Key verification
  to     generated/certificates
  using  openssl

extract
  will extract from the official ISO:
  - BOOTX64.EFI
  - grubx64.efi
  - mmx64.efi
  to     extracted
  using  xorriso

evaluate
  will fill the values:
  - FullName            : Your NAME
  - UserName            : admin
  - Password            : [...]
  - RootPassword        : [...]
  - TimeZone            : America/New_York
  - Languages           : en_US.utf8
  - KeyboardLayouts     : us
  - NtpPool             : 2.fedora.pool.ntp.org
  in :
  - kickstart/common.cfg
  - kickstart/development.cfg
  - kickstart/entr.cfg
  - kickstart/entry_desktop.cfg
  - kickstart/entry_devmachine.cfg
  - kickstart/entry_minimal.cfg
  - kickstart/entry_runner.cfg
  - kickstart/entry_yocto.cfg
  - kickstart/prompt_hostname.cfg
  - kickstart/pyenv.cfg
  - kickstart/runner.cfg
  - kickstart/security.cfg
  - kickstart/yocto.cfg
  to     generated/kickstart
  using  envsubst

grub/config
  will generate a grub configuration with the following entries:
  - desktop        : Install a graphical environment with developm
  - devmachine     : Headless development machine
  - minimal        : Manual package selection and partitioning
  - runner         : YOCTO Gitlab runner
  - yocto          : Headless machine for YOCTO development

help
  to learn how to use this makefile
```
