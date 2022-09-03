# sysproxy-cmd-darwin

This is a command line tool in objective C for setting the system proxy on MacOS. While this functionality is already available via `networksetup` on all MacOS systems, `networksetup` requires admin privileges for setting the system proxy. While `sysproxy-cmd-darwin` is no different in this regard, it does allow the caller program to elevate its privileges in some fashion, which is not possible with `networksetup`.

To build, you can just run:

`make`

Underneath, this calls `build.sh`, which runs:

```
xcodebuild build
codesign --options runtime --strict --timestamp --force --deep -r="designated => anchor trusted and identifier com.getlantern.lantern" -s "Developer ID Application: Innovate Labs LLC (4FYC28AXA2)" -v build/Release/sysproxy
cp build/Release/sysproxy ../sysproxy-cmd/darwin
file ../sysproxy-cmd/darwin
```