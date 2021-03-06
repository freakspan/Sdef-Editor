/*
 *  SdefXMLDictionary.m
 *  Sdef Editor
 *
 *  Created by Rainbow Team.
 *  Copyright © 2006 - 2007 Shadow Lab. All rights reserved.
 */

#import "SdefDictionary.h"
#import "SdefSuite.h"
#import "SdefXMLNode.h"
#import "SdefXMLBase.h"

@implementation SdefDictionary (SdefXMLManager)
#pragma mark XML Generation
- (BOOL)sd_usesXInclude {
  if ([self containsXInclude])
    return YES;
  
  SdefObject *child;
  NSEnumerator *children = [self deepChildEnumerator];
  while (child = [children nextObject]) {
    if ([child containsXInclude])
      return YES;
  }
  return NO;
}

- (SdefXMLNode *)xmlNodeForVersion:(SdefVersion)version {
  SdefXMLNode *node = [super xmlNodeForVersion:version];
  if (node) {
    if ([self name]) [node setAttribute:[[self name] stringByEscapingEntities:nil] forKey:@"title"];
    if (version > kSdefLeopardVersion) {
      //[node setMeta:@"10.5" forKey:@"version"];
      if ([self sd_usesXInclude])
        [node setAttribute:@"http://www.w3.org/2003/XInclude" forKey:@"xmlns:xi"];
    } else if (version == kSdefTigerVersion) {
      [node setMeta:@"10.4" forKey:@"version"];
    }
  }
  return node;
}

- (NSString *)xmlElementName {
  return @"dictionary";
}

#pragma mark Parsing
- (void)setXMLMetas:(NSDictionary *)metas {
  NSString *version = [metas objectForKey:@"version"];
  if (version) {
    if ([version isEqualToString:@"10.4"])
      [self setVersion:kSdefTigerVersion];
  }
  [super setXMLMetas:metas];
}

- (void)setXMLAttributes:(NSDictionary *)attrs {
  [super setXMLAttributes:attrs];
  NSString *attr = [attrs objectForKey:@"title"];
  if (attr)
    [self setName:[attr stringByUnescapingEntities:nil]];
}

- (void)addXMLChild:(id<SdefObject>)child {
  switch ([child objectType]) {
    case kSdefType_Suite:
      [self appendChild:(SdefSuite *)child];
      break;
    default:
      [super addXMLChild:child];
      break;
  }
}

@end
