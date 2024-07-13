## Machine Owner Key management

The "Module-signing only" `1.3.6.1.4.1.2312.16.1.2` KeyUsage OID is used to indicate that a key is only used to sign kernel modules:
the key will be ignored when shim or GRUB validate images to load in firmware.
