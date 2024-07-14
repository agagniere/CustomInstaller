# Custom OS Installer

This set of scripts allows one to generate an ISO image with a custom set of RPMs and an automated installation script.

The generated ISO can then be restored to a USB key and perform a tailored installation of Fedora, without having to disable Secure Boot.

## As a downloader

If you just want to download Fedora official ISOs, this makefile can be of use:
 - it will place the official ISO in your download folder
 - verify the ISO's integrity using the official checksum
 - verify the checksum was signed by Fedora

```shell
# To download the Workstaion ISO for x86_64:
make download

# You can choose the edition and architecture:
FedoraEdition=Server Architecture=aarch64 make download

# You can even choose the installation method for the server edition:
FedoraEdition=Server Architecture=ppc64le make download FedoraMethod=dvd

# And you can choose between wget and curl
Downloader=curl make download
```

Downloadable status as of Fedora 40 :

|         | Workstation | Server |
|:--------|:-----------:|:------:|
| x86_64  | ✅          | ✅     |
| aarch64 | ❌          | ✅     |
| ppc64le | ✅          | ✅     |
| s390x   | ❌          | ✅     |
