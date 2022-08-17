#import <Foundation/Foundation.h>

#import <SystemConfiguration/SCPreferences.h>
#import <SystemConfiguration/SCNetworkConfiguration.h>

#import <sys/stat.h>
#import <mach-o/dyld.h>

enum RET_ERRORS {
    RET_NO_ERROR = 0,
    INVALID_FORMAT = 1,
    NO_PERMISSION = 2,
    SYSCALL_FAILED = 3,
    NO_MEMORY = 4
};

int setUid(void) {
  char exeFullPath [PATH_MAX];
  uint32_t size = PATH_MAX;
  if (_NSGetExecutablePath(exeFullPath, &size) != 0) {
    printf("Path longer than %d, should not occur!!!!!", size);
    return SYSCALL_FAILED;
  }
  // root:wheel
  if (chown(exeFullPath, 0, 0) != 0) {
    puts("Error chown");
    return NO_PERMISSION;
  }
  if (chmod(exeFullPath, S_IRWXU | S_IRGRP | S_IXGRP | S_IROTH | S_IXOTH | S_ISUID) != 0) {
    puts("Error chmod");
    return NO_PERMISSION;
  }
  return RET_NO_ERROR;
}

Boolean doSetSystemProxy(SCNetworkProtocolRef proxyProtocolRef, NSDictionary* oldPreferences, bool turnOn, NSString* nsProxyHost, NSNumber* nsProxyPort) {
  NSString* nsOldProxyHost;
  NSNumber* nsOldProxyPort;
  NSMutableDictionary *newPreferences = [NSMutableDictionary dictionaryWithDictionary: oldPreferences];
  Boolean success;

  if (turnOn == true) {
    [newPreferences setValue: nsProxyHost forKey:(NSString*)kSCPropNetProxiesHTTPProxy];
    [newPreferences setValue: nsProxyHost forKey:(NSString*)kSCPropNetProxiesHTTPSProxy];
    [newPreferences setValue: nsProxyPort forKey:(NSString*)kSCPropNetProxiesHTTPPort];
    [newPreferences setValue: nsProxyPort forKey:(NSString*)kSCPropNetProxiesHTTPSPort];
    [newPreferences setValue:[NSNumber numberWithInt:1] forKey:(NSString*)kSCPropNetProxiesHTTPEnable];
    [newPreferences setValue:[NSNumber numberWithInt:1] forKey:(NSString*)kSCPropNetProxiesHTTPSEnable];
  } else {
    nsOldProxyHost = [newPreferences valueForKey:(NSString*)kSCPropNetProxiesHTTPProxy];
    nsOldProxyPort = [newPreferences valueForKey:(NSString*)kSCPropNetProxiesHTTPPort];
    if ([nsProxyHost isEqualToString:nsOldProxyHost] && [nsProxyPort intValue] == [nsOldProxyPort intValue]) {
      [newPreferences setValue:[NSNumber numberWithInt:0] forKey:(NSString*)kSCPropNetProxiesHTTPEnable];
      [newPreferences setValue: @"" forKey:(NSString*)kSCPropNetProxiesHTTPProxy];
      [newPreferences setValue: @"" forKey:(NSString*)kSCPropNetProxiesHTTPPort];
    }
    nsOldProxyHost = [newPreferences valueForKey:(NSString*)kSCPropNetProxiesHTTPSProxy];
    nsOldProxyPort = [newPreferences valueForKey:(NSString*)kSCPropNetProxiesHTTPSPort];
    if ([nsProxyHost isEqualToString:nsOldProxyHost] && [nsProxyPort intValue] == [nsOldProxyPort intValue]) {
      [newPreferences setValue:[NSNumber numberWithInt:0] forKey:(NSString*)kSCPropNetProxiesHTTPSEnable];
      [newPreferences setValue: @"" forKey:(NSString*)kSCPropNetProxiesHTTPSProxy];
      [newPreferences setValue: @"" forKey:(NSString*)kSCPropNetProxiesHTTPSPort];
    }
  }

  success = SCNetworkProtocolSetConfiguration(proxyProtocolRef, (__bridge CFDictionaryRef)newPreferences);
  if(!success) {
    NSLog(@"Failed to set Protocol Configuration");
  }
  return success;
}

int setSystemProxy(bool persist, bool turnOn, NSString* host, NSNumber* port) {
  int ret = RET_NO_ERROR;
  Boolean success;

  SCNetworkSetRef networkSetRef;
  CFArrayRef networkServicesArrayRef;
  SCNetworkServiceRef networkServiceRef;
  SCNetworkProtocolRef proxyProtocolRef;
  NSDictionary *oldPreferences;

  // Get System Preferences Lock
  SCPreferencesRef prefsRef = SCPreferencesCreate(NULL, CFSTR("org.getlantern.lantern"), NULL);

  if(prefsRef==NULL) {
    NSLog(@"Fail to obtain Preferences Ref");
    ret = NO_PERMISSION;
    goto freePrefsRef;
  }

  success = SCPreferencesLock(prefsRef, true);
  if (!success) {
    NSLog(@"Fail to obtain PreferencesLock");
    ret = NO_PERMISSION;
    goto freePrefsRef;
  }

  // Get available network services
  networkSetRef = SCNetworkSetCopyCurrent(prefsRef);
  if(networkSetRef == NULL) {
    NSLog(@"Fail to get available network services");
    ret = SYSCALL_FAILED;
    goto freeNetworkSetRef;
  }

  //Look up interface entry
  networkServicesArrayRef = SCNetworkSetCopyServices(networkSetRef);
  networkServiceRef = NULL;
  for (long i = 0; i < CFArrayGetCount(networkServicesArrayRef); i++) {
    networkServiceRef = CFArrayGetValueAtIndex(networkServicesArrayRef, i);

    // Get proxy protocol
    proxyProtocolRef = SCNetworkServiceCopyProtocol(networkServiceRef, kSCNetworkProtocolTypeProxies);
    if(proxyProtocolRef == NULL) {
      NSLog(@"Couldn't acquire copy of proxyProtocol");
      ret = SYSCALL_FAILED;
      goto freeProxyProtocolRef;
    }

    oldPreferences = (__bridge NSDictionary*)SCNetworkProtocolGetConfiguration(proxyProtocolRef);
      if (!doSetSystemProxy(proxyProtocolRef, oldPreferences, turnOn, host, port)) {
          ret = SYSCALL_FAILED;
      }

freeProxyProtocolRef:
    CFRelease(proxyProtocolRef);
  }

  if (persist) {
    success = SCPreferencesCommitChanges(prefsRef);
    if(!success) {
      NSLog(@"Failed to Commit Changes");
      ret = SYSCALL_FAILED;
      goto freeNetworkServicesArrayRef;
    }

    success = SCPreferencesApplyChanges(prefsRef);
    if(!success) {
      NSLog(@"Failed to Apply Changes");
      ret = SYSCALL_FAILED;
      goto freeNetworkServicesArrayRef;
    }
  }

  //Free Resources
freeNetworkServicesArrayRef:
  CFRelease(networkServicesArrayRef);
freeNetworkSetRef:
  CFRelease(networkSetRef);
freePrefsRef:
  SCPreferencesUnlock(prefsRef);
  CFRelease(prefsRef);

  return ret;
}

int show(NSDictionary* oldPreferences) {
    NSNumber* on = [oldPreferences valueForKey:(NSString*)kSCPropNetProxiesHTTPEnable];
    NSString* nsOldProxyHost = [oldPreferences valueForKey:(NSString*)kSCPropNetProxiesHTTPProxy];
    NSNumber* nsOldProxyPort = [oldPreferences valueForKey:(NSString*)kSCPropNetProxiesHTTPPort];
    if ([on intValue] == 1) {
        printf("%s:%d\n", [nsOldProxyHost UTF8String], [nsOldProxyPort intValue]);
    }
    return TRUE;
}

void turnOffProxyOnSignal(int signal) {
    setSystemProxy(true, false, @"", 0);
    exit(0);
}

void setupSignals(void) {
    // Register signal handlers to make sure we turn proxy off no matter what
    signal(SIGABRT, turnOffProxyOnSignal);
    signal(SIGFPE, turnOffProxyOnSignal);
    signal(SIGILL, turnOffProxyOnSignal);
    signal(SIGINT, turnOffProxyOnSignal);
    signal(SIGSEGV, turnOffProxyOnSignal);
    signal(SIGTERM, turnOffProxyOnSignal);
    signal(SIGSEGV, turnOffProxyOnSignal);
}

void usage(const char* binName) {
    printf("Usage: %s [on | off | wait-and-cleanup <proxy host> <proxy port>]\n", binName);
    exit (1);
}

int main(int argc, const char * argv[]) {
    @autoreleasepool {
        if (argc < 2) {
          usage(argv[0]);
        }
        if (strcmp(argv[1], "setuid") == 0) {
          return setUid();
        }
        if (strcmp(argv[1], "show") == 0) {
            //setSystemProxy(false, false, @"", 0);
            //show();
        }
        if (argc < 4) {
            usage(argv[0]);
        }
        if (strcmp(argv[1], "on") == 0) {
            NSString* host = [NSString stringWithUTF8String:argv[2]];
            NSString* portString = [NSString stringWithUTF8String:argv[3]];
            NSNumberFormatter *f = [[NSNumberFormatter alloc] init];
            NSNumber* port = [f numberFromString:portString];
            printf("Setting system proxy %s:%d\n", [host UTF8String], [port intValue]);
            setSystemProxy(true, true, host, port);
        } else if (strcmp(argv[1], "off") == 0) {
            return setSystemProxy(true, false, @"", 0);
        } else if (strcmp(argv[1], "wait-and-cleanup") == 0) {
            setupSignals();
            // wait for input from stdin (or close), then toggle off
            getchar();
            return setSystemProxy(true, false, @"", 0);
        } else {
            usage(argv[0]);
        }
      
      // code never reaches here, just avoids compiler from complaining.
      return RET_NO_ERROR;
    }
    return 0;
}
