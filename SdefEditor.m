/*
 *  SdefEditor.m
 *  Sdef Editor
 *
 *  Created by Rainbow Team.
 *  Copyright � 2006 - 2007 Shadow Lab. All rights reserved.
 */

#import "SdefEditor.h"
#import <ShadowKit/SKFunctions.h>
#import <ShadowKit/SKLSFunctions.h>
#import <ShadowKit/SKApplication.h>

#if MAC_OS_X_VERSION_MIN_REQUIRED < MAC_OS_X_VERSION_10_4
#include <Carbon/Carbon.h>
#endif

#import "SdefSuite.h"
#import "Preferences.h"
#import "SdefDocument.h"
#import "AeteImporter.h"
#import "SdefDictionary.h"
#import "ImporterWarning.h"
#import "OSASdefImporter.h"
#import "CocoaSuiteImporter.h"
#import "SdefObjectInspector.h"
#import "ImportApplicationAete.h"

#if defined (DEBUG)
#import <Foundation/NSDebug.h>
#endif

enum {
  kSdefEditorCurrentVersion = 0x010500, /* 1.5.0 */
};

int main(int argc, const char *argv[]) {
#if defined (DEBUG)  
  NSDebugEnabled = YES;
  NSHangOnUncaughtException = YES;
#endif
  return NSApplicationMain(argc, argv);
}

NSString * ScriptingDefinitionFileType = @"ScriptingDefinition";
const OSType kScriptingDefinitionHFSType = 'Sdef';
NSString * CocoaSuiteDefinitionFileType = @"AppleScriptSuiteDefinition";
const OSType kCocoaSuiteDefinitionHFSType = 'ScSu';

@interface SdefEditor (DebugFacility)
- (void)createDebugMenu;
@end

@interface SdefDocumentController : NSDocumentController {
}
@end

@implementation SdefEditor

+ (void)initialize {
  if ([SdefEditor class] == self) {
    if (SKSystemMajorVersion() == 10 && SKSystemMinorVersion() >= 5) {
      /* Redefine type using UTI */
      ScriptingDefinitionFileType = @"com.apple.scripting-definition";
      CocoaSuiteDefinitionFileType = @"org.shadowlab.cocoa-scripting";
    }
  }
}

- (id)init {
  if (self = [super init]) {
    NSString *sdp = @"/usr/bin/sdp";
    /* Pre-Tiger versions */
    if (SKSystemMajorVersion() == 10 && SKSystemMinorVersion() < 4) {
      sdp = @"/Developer/Tools/sdp";
    }
    NSString *rez = @"/Developer/Tools/Rez";
    /* Initialize custom controller */
    SdefDocumentController *ctrl = [[SdefDocumentController alloc] init];
    if ([ctrl respondsToSelector:@selector(setAutosavingDelay:)]) {
      [ctrl setAutosavingDelay:60];
    }
    [[NSUserDefaults standardUserDefaults] registerDefaults:[NSDictionary dictionaryWithObjectsAndKeys:
      SKBool(YES), @"SdefOpenAtStartup",
      SKBool(![[NSFileManager defaultManager] fileExistsAtPath:sdp]), @"SdefBuildInSdp",
      SKBool(![[NSFileManager defaultManager] fileExistsAtPath:rez]), @"SdefBuildInRez",
      SKBool(YES), @"SdefAutoSelectItem",
      sdp, @"SdefSdpToolPath",
      rez, @"SdefRezToolPath",
      nil]];
    [NSApp setDelegate:self];
#if defined (DEBUG)
    [[NSUserDefaults standardUserDefaults] registerDefaults:[NSDictionary dictionaryWithObjectsAndKeys:
      SKBool(YES), @"SdefDebugMenu",
      SKBool(YES), @"SdefPantherExportEnabled",
      // @"YES", @"NSShowNonLocalizedStrings",
      // @"NO", @"NSShowAllViews",
      // @"6", @"NSDragManagerLogLevel",
      // @"YES", @"NSShowNonLocalizableStrings",
      // @"1", @"NSScriptingDebugLogLevel",
      nil]];
#endif
  } 
  return self;
}

- (void)showWelcome {
  ShadowTrace();
}

- (void)awakeFromNib {
  if ([[NSUserDefaults standardUserDefaults] boolForKey:@"SdefDebugMenu"])
    [self createDebugMenu];
#if MAC_OS_X_VERSION_MIN_REQUIRED < MAC_OS_X_VERSION_10_4
  // If Panther, remove open application sdef menu
  if (!OSACopyScriptingDefinition) {
    NSMenu *file = [[[NSApp mainMenu] itemWithTag:1] submenu];
    [file removeItem:[file itemWithTag:1]];
  }
#endif
#if __LP64__
  NSMenu *file = [[[NSApp mainMenu] itemWithTag:1] submenu];
  NSMenuItem *export = [file itemWithTag:2];
  if (export) {
    NSMenuItem *item  = [[export submenu] itemAtIndex:0];
    if (item) {
      [item retain];
      [[export submenu] removeItem:item];
      [item setTitle:NSLocalizedString(@"Create Dictionary...", @"Create dictionary 64 bits title")];
      NSInteger idx = [file indexOfItem:export];
      [file removeItem:export];
      [file insertItem:item atIndex:idx];
      [item release];
    }
  }
#endif
  
  NSUInteger version = [[NSUserDefaults standardUserDefaults] integerForKey:@"SdefEditorVersion"];
  if (version < kSdefEditorCurrentVersion) {
    [[NSUserDefaults standardUserDefaults] setInteger:kSdefEditorCurrentVersion forKey:@"SdefEditorVersion"];
    [self showWelcome];
  }
}

- (IBAction)openInspector:(id)sender {
  [[SdefObjectInspector sharedInspector] showWindow:sender];
}

- (IBAction)preferences:(id)sender {
  static Preferences *preferences = nil;
  if (!preferences) {
    preferences = [[Preferences alloc] init];
  }
  [preferences showWindow:sender];
}

- (IBAction)releaseNotes:(id)sender {
  [[NSHelpManager sharedHelpManager] openHelpAnchor:@"SdefReleaseNotes" inBook:@"Sdef Editor Help"];
}

- (IBAction)openSuite:(id)sender {
  NSString *suite = nil;
  switch ([sender tag]) {
    case 1:
      suite = @"NSCoreSuite";
      break;
    case 2:
      suite = @"NSTextSuite";
      break;
    case 3:
      suite = @"AppleScriptKit";
      break;
    case 4:
      suite = @"Skeleton";
      break;
  }
  NSString *suitePath = [[NSBundle mainBundle] pathForResource:suite ofType:@"sdef"];
  if (suitePath) {
    NSDocumentController *ctrl = [NSDocumentController sharedDocumentController];
    NSDocument *doc = [ctrl openDocumentWithContentsOfFile:suitePath
                                                    display:NO];
    if (doc) {
      [doc setFileName:nil];
      [doc showWindows];
    }
  }
}

- (IBAction)openSdefReference:(id)sender {
  
}

#pragma mark -
#pragma mark Importation
- (IBAction)openApplicationTerminology:(id)sender {
// Don't check weak ref in Tiger
#if MAC_OS_X_VERSION_MIN_REQUIRED < MAC_OS_X_VERSION_10_4
  if (!OSACopyScriptingDefinition) {
    NSBeep();
    return;
  }
#endif
  
  ImportApplicationAete *panel = [[ImportApplicationAete alloc] initWithWindowNibName:@"ImportApplicationSdef"];
  [panel showWindow:sender];
  [NSApp runModalForWindow:[panel window]];
  SKApplication *appli = [panel selection];
  if (appli) {
    NSString *path = [appli path];
    
    SdefImporter *importer = [[OSASdefImporter alloc] initWithFile:path];
    [self importWithImporter:importer];
    [importer release];
  }
  [panel release];
}

- (void)importWithImporter:(SdefImporter *)importer {
  @try {
    NSArray *suites = [importer sdefSuites];
    SdefDictionary *dico = [importer sdefDictionary];
    if ([dico hasChildren] || [suites count]) {
      SdefDocument *doc = [[NSDocumentController sharedDocumentController] openUntitledDocumentOfType:ScriptingDefinitionFileType display:NO];
      
      if (dico) {
        [doc setDictionary:dico];
      } else if ([suites count]) {
        [[doc dictionary] removeAllChildren];
        
        SdefSuite *suite;
        NSEnumerator *items = [suites objectEnumerator];
        while (suite = [items nextObject]) {
          [[doc dictionary] appendChild:suite];
        }
        [[doc undoManager] removeAllActions];
        [doc updateChangeCount:NSChangeCleared];
      }
      
      [doc showWindows];
      
      if ([importer warnings]) {
        ImporterWarning *alert = [[ImporterWarning alloc] init];
        [alert setDocument:doc];
        [alert setWarnings:[importer warnings]];
        [alert setReleasedWhenClosed:YES];
        [alert showWindow:nil];
      }
    } else {
      NSRunAlertPanel(@"Importation failed!", @"Sdef Editor cannot import this file. Is it in a valid format?", @"OK", nil, nil);
    }
  } @catch (id exception) {
    SKLogException(exception);
    NSBeep();
  }
}

- (void)importCocoaScriptFile:(NSString *)file {
  CocoaSuiteImporter *importer = [[CocoaSuiteImporter alloc] initWithContentsOfFile:file];
  if ([importer preload]) {
    [self importWithImporter:importer];
  } else {
    NSRunAlertPanel(@"Sorry! Sdef Editor cannot import this definition", @"Try with desdp(1) tools (see 'man desdp')", @"OK", nil, nil);
  }
  [importer release];
}

- (IBAction)importCocoaTerminology:(id)sender {
  NSOpenPanel *openPanel = [NSOpenPanel openPanel];
  [openPanel setPrompt:@"Import"];
  [openPanel setMessage:@"Choose a Cocoa .scriptSuite File"];
  [openPanel setCanChooseFiles:YES];
  [openPanel setCanCreateDirectories:NO];
  [openPanel setCanChooseDirectories:NO];
  [openPanel setAllowsMultipleSelection:NO];
  [openPanel setTreatsFilePackagesAsDirectories:YES];
  switch([openPanel runModalForTypes:[NSArray arrayWithObject:@"scriptSuite"]]) {
    case NSCancelButton:
      return;
  }
  if (![[openPanel filenames] count]) return;
  
  NSString *file = [[openPanel filenames] objectAtIndex:0];
  [self importCocoaScriptFile:file];
}

- (IBAction)importAete:(id)sender {
  NSOpenPanel *openPanel = [NSOpenPanel openPanel];
  [openPanel setPrompt:@"Import"];
  [openPanel setMessage:@"Choose an aete Rsrc File"];
  [openPanel setCanChooseFiles:YES];
  [openPanel setCanCreateDirectories:NO];
  [openPanel setCanChooseDirectories:NO];
  [openPanel setAllowsMultipleSelection:NO];
  [openPanel setTreatsFilePackagesAsDirectories:YES];
  switch([openPanel runModalForTypes:nil]) {
    case NSCancelButton:
      return;
  }
  if (![[openPanel filenames] count]) return;
  
  NSString *file = [[openPanel filenames] objectAtIndex:0];
  AeteImporter *aete = [[AeteImporter alloc] initWithContentsOfFile:file];
  [self importWithImporter:aete];
  [aete release];
}

- (IBAction)importSystemSuites:(id)sender {
  AeteImporter *aete = [[AeteImporter alloc] initWithSystemSuites];
  if (aete) {
    [self importWithImporter:aete];
    [aete release];
  }
}

- (IBAction)importApplicationAete:(id)sender {
  ImportApplicationAete *panel = [[ImportApplicationAete alloc] init];
  [panel showWindow:sender];
  [NSApp runModalForWindow:[panel window]];
  SKApplication *appli = [panel selection];
  if (appli) {
    if (![appli isRunning]) {
      [appli launch];
    }
    AeteImporter *aete = nil;
    switch ([appli idType]) {
      case kSKApplicationOSType:
        aete = [[AeteImporter alloc] initWithApplicationSignature:[appli signature]]; 
        break;
      case kSKApplicationBundleIdentifier:
        aete = [[AeteImporter alloc] initWithApplicationBundleIdentifier:[appli identifier]];
        break;
      default:
        aete = nil;
    }
    if (aete) {
      [self importWithImporter:aete];
      [aete release];
    } else {
      NSBeep();
    }
  }
  [panel release];
}

#pragma mark -
#pragma mark Application Delegate
- (BOOL)application:(NSApplication *)theApplication openFile:(NSString *)filename {
  Boolean isapp = false;
  NSString *type = [[NSDocumentController sharedDocumentController] typeFromFileExtension:[filename pathExtension]];
  if ([type isEqualToString:CocoaSuiteDefinitionFileType]) {
    [self importCocoaScriptFile:filename];
    return YES;
  } else {
#if MAC_OS_X_VERSION_MIN_REQUIRED < MAC_OS_X_VERSION_10_4
    if (OSACopyScriptingDefinition) {
#endif
      if ((noErr == SKLSIsApplicationAtPath((CFStringRef)filename, &isapp)) && isapp) {
        SdefImporter *importer = [[OSASdefImporter alloc] initWithFile:filename];
        [self importWithImporter:importer];
        [importer release];
        return YES;
      }
#if MAC_OS_X_VERSION_MIN_REQUIRED < MAC_OS_X_VERSION_10_4      
    }
#endif
  }
  /* lets document manager handle it */
  return NO;
}

- (BOOL)applicationShouldOpenUntitledFile:(NSApplication *)sender {
  return [[NSUserDefaults standardUserDefaults] boolForKey:@"SdefOpenAtStartup"];
}

#pragma mark -
#pragma mark Debug Menu
- (void)createDebugMenu {
  NSMenuItem *debugMenu = [[NSMenuItem alloc] initWithTitle:@"" action:nil keyEquivalent:@""];
  NSMenu *menu = [[NSMenu alloc] initWithTitle:@"Debug"];
  [menu addItemWithTitle:@"Import System Suites" action:@selector(importSystemSuites:) keyEquivalent:@""];
  [debugMenu setSubmenu:menu];
  [menu release];
  [[NSApp mainMenu] insertItem:debugMenu atIndex:[[NSApp mainMenu] numberOfItems] -1];
  [debugMenu release];
}

@end

@implementation SdefDocumentController

- (void)noteNewRecentDocument:(NSDocument *)aDocument {
  NSString *path = [aDocument fileName];
  if (![path hasPrefix:[[NSBundle mainBundle] bundlePath]]) {
    [super noteNewRecentDocument:aDocument];
  }
}

@end
