//
//  SdefVerbView.m
//  SDef Editor
//
//  Created by Grayfox on 19/01/05.
//  Copyright 2005 Shadow Lab. All rights reserved.
//

#import "SdefVerbView.h"
#import "SdefVerb.h"
#import "SdefArguments.h"
#import "ShadowMacros.h"
#import "SKAppKitExtensions.h"

@implementation SdefVerbView

+ (void)initialize {
  [super initialize];
  [self setKeys:[NSArray arrayWithObject:@"object"] triggerChangeNotificationsForDependentKey:@"verbLabel"];
}

- (NSString *)verbLabel {
  if (![self object])
    return @"Verb";
  return [[self object] isCommand] ? NSLocalizedString(@"Command", @"Verb Tab Label") : NSLocalizedString(@"Event", @"Verb Tab Label");
}

- (void)selectObject:(SdefObject*)anObject {
  int idx = -1;
  SdefVerb *content = [self object];
  if (anObject == content) idx = 0;
  else if ([anObject parent] == content)  {
    idx = 1;
    [parameters setSelectedObjects:[NSArray arrayWithObject:anObject]];
  }
  if (idx >= 0)
    [tab selectTabViewItemAtIndex:idx];
}

- (id)editedObject:(id)sender {
  switch ([sender tag]) {
    case 0:
      return [parameters selectedObject];
    case 1:
      return [[self object] directParameter];
    case 2:
      return [[self object] result]; 
  }
  return nil;
}

//- (void)tableViewSelectionDidChange:(NSNotification *)aNotification {
//  id table = [aNotification object];
//  int row = [table selectedRow];
//  if (row >= 0 && row < [[self object] childCount]) {
//    [self revealObjectInTree:[[self object] childAtIndex:row]];
//  }
//}

@end
