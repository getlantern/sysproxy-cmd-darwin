# sysproxy-cmd-darwin

This is a command line tool in objective C for setting the system proxy on MacOS. While this functionality is already available via `networksetup` on all MacOS systems, `networksetup` requires admin privileges for setting the system proxy. While `sysproxy-cmd-darwin` is no different in this regard, it does allow the caller program to elevate its privileges in some fashion, which is not possible with `networksetup`.

For distribution, this relies on [code signing and notarization](https://developer.apple.com/documentation/security/notarizing_macos_software_before_distribution) via XCode.