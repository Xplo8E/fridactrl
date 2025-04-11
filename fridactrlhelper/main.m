#import <Foundation/Foundation.h>
#import <stdio.h>
#import <stdlib.h>    // For calloc(), free()
#import <string.h>    // For strcmp(), strerror()
#import <sys/wait.h>  // For waitpid(), WEXITSTATUS()
#import <sys/stat.h>  // For chmod()
#import <unistd.h>    // For chown(), close(), getuid(), geteuid()
#import <spawn.h>     // For posix_spawn()

// Required by posix_spawn
extern char **environ;

// --- Function Declarations ---
int runCommandSimple(NSString *commandPath, NSArray<NSString *> *arguments); // Simple runner
BOOL reloadLaunchDaemon(NSString* plistPath); // Uses simple runner
NSString* findPlistPath(void);
NSMutableDictionary* readPlist(NSString* plistPath);
BOOL writePlist(NSDictionary* dictionary, NSString* plistPath);
BOOL setPortInPlist(NSString* plistPath, NSString* port);
BOOL revertDefaultInPlist(NSString* plistPath);


// --- Main Entry Point ---
int main(int argc, char *argv[]) {
    @autoreleasepool {
        // --- Root Check ---
        uid_t actual_uid = getuid();
        uid_t effective_uid = geteuid();
        NSLog(@"[FridaCtrlHelper] Starting Checks - UID: %d, EUID: %d", actual_uid, effective_uid);
        if (effective_uid != 0) {
             fprintf(stderr, "[FridaCtrlHelper] Error: Helper is not running as root (EUID: %d).\n", effective_uid);
             return 10; // Error: Not root
        }
        NSLog(@"[FridaCtrlHelper] Running as root.");

        // --- Argument Parsing ---
        if (argc < 2) {
            fprintf(stderr, "[FridaCtrlHelper] Error: No action specified. Usage: %s --set-port <port> | --revert-default | --get-status\n", argv[0]);
            return 1;
        }
        NSString *action = [NSString stringWithUTF8String:argv[1]];

        // --- Find Plist Path ---
        NSString *plistPath = findPlistPath();
        if (!plistPath) {
             fprintf(stderr, "[FridaCtrlHelper] Error: Could not find re.frida.server.plist.\n");
             return 2;
        }
        NSLog(@"[FridaCtrlHelper] Using plist: %s", [plistPath fileSystemRepresentation]);

        // --- Perform Action ---
        BOOL plistActionResult = NO;
        BOOL needsReload = NO;

        if ([action isEqualToString:@"--set-port"]) {
            if (argc < 3) {
				 fprintf(stderr, "[FridaCtrlHelper] Error: Missing port number.\n"); 
				 return 3; 
			}
            NSString *portString = [NSString stringWithUTF8String:argv[2]];
            NSScanner *scanner = [NSScanner scannerWithString:portString]; int portNumber;
            BOOL isNumeric = [scanner scanInt:&portNumber] && [scanner isAtEnd];
            if (!isNumeric || portNumber <= 0 || portNumber > 65535) { 
				fprintf(stderr, "[FridaCtrlHelper] Error: Invalid port '%s'.\n", argv[2]); 
				return 4; 
			}
            NSLog(@"[FridaCtrlHelper] Action: Set Port to %@", portString);
            plistActionResult = setPortInPlist(plistPath, portString);
            needsReload = YES;

        } else if ([action isEqualToString:@"--revert-default"]) {
             NSLog(@"[FridaCtrlHelper] Action: Revert to Default Port");
             plistActionResult = revertDefaultInPlist(plistPath);
             needsReload = YES;

        } else if ([action isEqualToString:@"--get-status"]) {
            NSLog(@"[FridaCtrlHelper] Action: Get Status");
            NSMutableDictionary* plistDict = readPlist(plistPath);
            if (!plistDict) {
				 fprintf(stderr, "[FridaCtrlHelper] Error: Failed read for status.\n"); 
				 return 8; 
			}
            NSString *currentPort = @"default";
            id argsObject = plistDict[@"ProgramArguments"];
            if (argsObject && [argsObject isKindOfClass:[NSArray class]]) {
                NSArray *argsArray = (NSArray *)argsObject;
                for (NSUInteger i = 0; i < [argsArray count]; ++i) {
                    if ([argsArray[i] isKindOfClass:[NSString class]] && [argsArray[i] isEqualToString:@"-l"]) {
                        if (i + 1 < [argsArray count] && [argsArray[i+1] isKindOfClass:[NSString class]]) {
                            NSString *listenArg = argsArray[i+1];
                            NSRange colonRange = [listenArg rangeOfString:@":" options:NSBackwardsSearch];
                            currentPort = (colonRange.location != NSNotFound) ? [listenArg substringFromIndex:colonRange.location + 1] : listenArg;
                            break;
                        }
                    }
                }
            }
            // Print result ONLY to stdout for capture by GUI app
            printf("%s", [currentPort UTF8String]);
            return 0; // Success for get-status

        } else {
            fprintf(stderr, "[FridaCtrlHelper] Error: Unknown action '%s'.\n", argv[1]);
            return 5;
        }

        // --- Reload Daemon (Only if needed and plist action succeeded) ---
        if (needsReload) {
            if (plistActionResult) {
                 NSLog(@"[FridaCtrlHelper] Plist action successful. Reloading daemon...");
                 BOOL reloadSuccess = reloadLaunchDaemon(plistPath);
                 if (reloadSuccess) {
                     NSLog(@"[FridaCtrlHelper] Daemon reloaded successfully.");
                     printf("[FridaCtrlHelper] Operation completed successfully.\n"); // Success message to stdout
                     return 0; // SUCCESS
                 } else { /* Error already printed */ return 7; } // Error: Reload failed
            } else { 
				fprintf(stderr, "[FridaCtrlHelper] Error: Failed to modify plist file.\n"); 
				return 6; 
			} // Error: Plist mod failed
        }
        // Should only be reached by programming error
        return 99;
    } // End autoreleasepool
}


// --- Function Implementations ---

// Simpler posix_spawn wrapper, just runs command and returns exit status.
// Returns -1 if spawn/wait fails, otherwise the command's exit status.
int runCommandSimple(NSString *commandPath, NSArray<NSString *> *arguments) {
    const char *cPath = [commandPath fileSystemRepresentation];
    NSLog(@"[FridaCtrlHelper] Running (simple): %@", commandPath);

    // Prepare argv
    size_t argc = arguments.count + 1;
    const char **argv = (const char **)calloc(argc + 1, sizeof(char *));
    if (!argv) { NSLog(@"[FridaCtrlHelper] Failed memory for argv"); return -1; }
    argv[0] = cPath;
    for (size_t i = 0; i < arguments.count; ++i) { argv[i + 1] = [arguments[i] fileSystemRepresentation]; }
    argv[argc] = NULL;

    pid_t pid;
    int ret = posix_spawn(&pid, cPath, NULL, NULL, (char* const*)argv, environ);
    free(argv); // Free argv immediately

    if (ret != 0) {
        NSLog(@"[FridaCtrlHelper] posix_spawn failed for %s: %s", cPath, strerror(ret));
        return -1; // Indicate spawn failure
    }

    // Wait for command to finish
    int status;
    pid_t waitedPid = waitpid(pid, &status, 0);
    if (waitedPid == -1) {
        perror("[FridaCtrlHelper] waitpid failed");
        return -1; // Indicate wait failure
    }

    if (WIFEXITED(status)) {
        return WEXITSTATUS(status); // Return actual exit status
    }
    return -1; // Indicate non-normal exit (signal, etc)
}


// Reloads the daemon using the simple runner
BOOL reloadLaunchDaemon(NSString* plistPath) {
    NSString *launchctlPath = @"/var/jb/bin/launchctl"; // Direct rootless path
    NSArray *unloadArgs = @[@"unload", plistPath];
    NSArray *loadArgs = @[@"load", plistPath];

    NSLog(@"[FridaCtrlHelper] Attempting unload using runCommandSimple...");
    int unloadExitCode = runCommandSimple(launchctlPath, unloadArgs);
    NSLog(@"[FridaCtrlHelper] Unload completed with exit code: %d", unloadExitCode);
    // Ignore unload exit code unless it indicates spawn failure (-1)

    NSLog(@"[FridaCtrlHelper] Attempting load using runCommandSimple...");
    int loadExitCode = runCommandSimple(launchctlPath, loadArgs);
    NSLog(@"[FridaCtrlHelper] Load completed with exit code: %d", loadExitCode);

    // Success ONLY if load command executes and returns exit code 0
    if (loadExitCode == 0) {
        return YES;
    } else {
        NSLog(@"[FridaCtrlHelper] Load command failed (Exit code: %d)", loadExitCode);
        fprintf(stderr, "[FridaCtrlHelper] Error: launchctl load failed (Exit code: %d)\n", loadExitCode);
        return NO;
    }
}


// Finds the correct plist path
NSString* findPlistPath() {
    NSFileManager *fm = [NSFileManager defaultManager];
    NSString *rootlessPath = @"/var/jb/Library/LaunchDaemons/re.frida.server.plist";
    if ([fm fileExistsAtPath:rootlessPath]) { 
		return rootlessPath;
	}
    NSString *standardPath = @"/Library/LaunchDaemons/re.frida.server.plist";
    if ([fm fileExistsAtPath:standardPath]) { 
		return standardPath;
	}
    NSLog(@"[FridaCtrlHelper] Plist not found at %@ or %@", rootlessPath, standardPath);
    return nil;
}

// Reads and parses plist file
NSMutableDictionary* readPlist(NSString* plistPath) {
    NSError *readError = nil;
    NSData *plistData = [NSData dataWithContentsOfFile:plistPath options:0 error:&readError];
    if (!plistData) {
		fprintf(stderr, "[FridaCtrlHelper] Error reading plist: %s\n", [[readError localizedDescription] UTF8String]);
		return nil; 
	}
    NSError *parseError = nil;
    id plistObject = [NSPropertyListSerialization propertyListWithData:plistData options:NSPropertyListMutableContainersAndLeaves format:NULL error:&parseError];
    if (!plistObject) { 
		fprintf(stderr, "[FridaCtrlHelper] Error parsing plist: %s\n", [[parseError localizedDescription] UTF8String]); 
		return nil; 
	}
    if (![plistObject isKindOfClass:[NSMutableDictionary class]]) { 
		fprintf(stderr, "[FridaCtrlHelper] Error: Plist root not dictionary.\n"); 
		return nil; 
	}
    NSLog(@"[FridaCtrlHelper] Read plist: %s", [plistPath fileSystemRepresentation]);
    return (NSMutableDictionary *)plistObject;
}

// Writes dictionary back to plist file, setting permissions
BOOL writePlist(NSDictionary* dictionary, NSString* plistPath) {
    NSError *serializeError = nil;
    NSData *newData = [NSPropertyListSerialization dataWithPropertyList:dictionary format:NSPropertyListXMLFormat_v1_0 options:0 error:&serializeError];
    if (!newData) { 
		fprintf(stderr, "[FridaCtrlHelper] Error serializing dictionary: %s\n", [[serializeError localizedDescription] UTF8String]); 
		return NO; 
	}
    NSError *writeError = nil;
    BOOL success = [newData writeToFile:plistPath options:NSDataWritingAtomic error:&writeError];
    if (!success) { 
		fprintf(stderr, "[FridaCtrlHelper] Error writing plist: %s\n", [[writeError localizedDescription] UTF8String]); 
	}
    else {
        const char *cPlistPath = [plistPath fileSystemRepresentation];
        NSLog(@"[FridaCtrlHelper] Wrote plist: %s", cPlistPath);
        if (chown(cPlistPath, 0, 0) != 0) { 
			perror("[FridaCtrlHelper] Warning: chown failed"); 
		}
        if (chmod(cPlistPath, 0644) != 0) { 
			perror("[FridaCtrlHelper] Warning: chmod failed"); 
		}
    }
    return success;
}

// Modifies plist to set a specific port
BOOL setPortInPlist(NSString* plistPath, NSString* port) {
    NSMutableDictionary *plistDict = readPlist(plistPath); if (!plistDict) return NO;
    NSString *argsKey = @"ProgramArguments"; id argsObject = plistDict[argsKey];
    if (!argsObject) { 
		fprintf(stderr, "[FridaCtrlHelper] Error: '%s' key missing.\n", [argsKey UTF8String]); 
		return NO; 
	}
    if (![argsObject isKindOfClass:[NSMutableArray class]]) {
        if ([argsObject isKindOfClass:[NSArray class]]) { 
			argsObject = [argsObject mutableCopy]; plistDict[argsKey] = argsObject; 
		}
        else { 
			fprintf(stderr, "[FridaCtrlHelper] Error: '%s' not array.\n", [argsKey UTF8String]); 
			return NO; 
		}
    }
    NSMutableArray *argsArray = (NSMutableArray *)argsObject;
    BOOL removed = NO; // Track if we removed existing
    for (NSInteger i = [argsArray count] - 1; i >= 0; i--) {
        if ([argsArray[i] isKindOfClass:[NSString class]] && [argsArray[i] isEqualToString:@"-l"]) {
            if (i + 1 < [argsArray count]) { 
				[argsArray removeObjectAtIndex:i + 1]; 
			} // Remove value after -l
            [argsArray removeObjectAtIndex:i]; // Remove -l
            removed = YES;
        }
    }
    if (removed) { 
		NSLog(@"[FridaCtrlHelper] Removed existing '-l' arguments.");
	}
    NSString *listenAddress = [NSString stringWithFormat:@"0.0.0.0:%@", port];
    NSLog(@"[FridaCtrlHelper] Adding '-l' and '%@'", listenAddress);
    [argsArray addObject:@"-l"]; [argsArray addObject:listenAddress];
    return writePlist(plistDict, plistPath);
}

// Modifies plist to remove the port argument
BOOL revertDefaultInPlist(NSString* plistPath) {
     NSMutableDictionary *plistDict = readPlist(plistPath); 
	 if (!plistDict) {
		return NO;
	}
     NSString *argsKey = @"ProgramArguments"; id argsObject = plistDict[argsKey];
    if (!argsObject) { 
		NSLog(@"[FridaCtrlHelper] Info: '%@' key missing, assuming default.", argsKey); 
		return YES; 
	}
    if (![argsObject isKindOfClass:[NSMutableArray class]]) {
        if ([argsObject isKindOfClass:[NSArray class]]) { 
			argsObject = [argsObject mutableCopy]; plistDict[argsKey] = argsObject; 
		} else { 
			fprintf(stderr, "[FridaCtrlHelper] Error: '%s' not array.\n", [argsKey UTF8String]); 
			return NO; 
		}
    }
     NSMutableArray *argsArray = (NSMutableArray *)argsObject;
     BOOL removedSomething = NO;
     for (NSInteger i = [argsArray count] - 1; i >= 0; i--) {
         if ([argsArray[i] isKindOfClass:[NSString class]] && [argsArray[i] isEqualToString:@"-l"]) {
             if (i + 1 < [argsArray count]) { 
				[argsArray removeObjectAtIndex:i + 1]; 
			}
             [argsArray removeObjectAtIndex:i];
             removedSomething = YES;
         }
     }
     if (!removedSomething) { 
		NSLog(@"[FridaCtrlHelper] No '-l' flag found to remove."); 
		return YES; 
	} // No change needed
     NSLog(@"[FridaCtrlHelper] Removed existing '-l' arguments.");
     return writePlist(plistDict, plistPath); // Write if changed
}