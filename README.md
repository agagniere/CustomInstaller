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
FedoraEdition=Server Architecture=aarch64 make download

# You can even choose the installation method for the server edition:
FedoraEdition=Server Architecture=ppc64le make download FedoraMethod=dvd

# And you can choose between wget and curl
Downloader=curl make download
```

Downloadable status as of Fedora 40 :

|           | Workstation | Server |
|:----------|:-----------:|:------:|
| `x86_64`  | ✅          | ✅     |
| `aarch64` | ❌          | ✅     |
| `ppc64le` | ✅          | ✅     |
| `s390x`   | ❌          | ✅     |

## Generating an ISO

For conveniance, you can place all values you want to customize in a local file `values.sh`:

```bash
# Latest Fedora release
FedoraVersion=40-1.14

# Workstation | Server
FedoraEdition=Workstation

# x86_64 | aarch64 | ppc64le | s390x
Architecture=x86_64

# wget | curl
Downloader=wget

# Used to create the initial user of the OS
UserName=mname
Password=`read -s -p 'Password: ' password && openssl passwd -6 -salt SomeRandomSalt $password`
RootPassword=`read -s -p 'Root Password: ' password && openssl passwd -6 -salt SomeRandomSalt $password`

# Used to sign the bootloader
FullName=My NAME
EmailAddress=my.name@example.com
CountryCode=US
Locality=New York
```

Then source the file before calling make:

```bash
set -a && source ./values.sh
make iso
```
