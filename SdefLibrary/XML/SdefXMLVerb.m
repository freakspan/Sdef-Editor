/*
 *  SdefXMLVerb.m
 *  Sdef Editor
 *
 *  Created by Rainbow Team.
 *  Copyright © 2006 - 2007 Shadow Lab. All rights reserved.
 */

#import "SdefVerb.h"
#import "SdefSuite.h"
#import "SdefXMLNode.h"
#import "SdefXMLBase.h"
#import "SdefArguments.h"

@implementation SdefVerb (SdefXMLManager)
#pragma mark XML Generation
- (SdefXMLNode *)xmlNodeForVersion:(SdefVersion)version {
  SdefXMLNode *node = [super xmlNodeForVersion:version];
  if (node) {
    SdefXMLNode *childNode = nil;
    /* Insert before parameters */
    NSUInteger idx = [node count] - [self count];
    /* Direct Parameter */
    if (_direct) {
      childNode = [_direct xmlNodeForVersion:version];
      if (childNode) {
        [node insertChild:childNode atIndex:idx];
      }
    }
    
    /* Result */
    if (_result) {
      childNode = [_result xmlNodeForVersion:version];
      if (childNode) {
        [node appendChild:childNode];
      }
    }
  }
  return node;
}

- (NSString *)xmlElementName {
  return [self isCommand] ? @"command" : @"event"; 
}

#pragma mark Parsing
- (void)addXMLChild:(id<SdefObject>)child {
  switch ([child objectType]) {
    case kSdefResultType:
      [self setResult:(SdefResult *)child];
      break;
    case kSdefParameterType:
      [self appendChild:(SdefParameter *)child];
      break;
    case kSdefDirectParameterType:
      [self setDirectParameter:(SdefDirectParameter *)child];
      break;
    default:
      [super addXMLChild:child];
      break;
  }
}

@end

@implementation SdefDirectParameter (SdefXMLManager)
#pragma mark XML Generation
- (SdefXMLNode *)xmlNodeForVersion:(SdefVersion)version {
  SdefXMLNode *node = nil;
  if ([self hasType] && (node = [super xmlNodeForVersion:version])) {
    [node removeAttributeForKey:@"name"];
    if ([self isOptional]) {
      if (version >= kSdefTigerVersion) {
        [node setAttribute:@"yes" forKey:@"optional"];
      } else {
        [node setAttribute:@"optional" forKey:@"optional"];
      }
    }
    [node setEmpty:YES];
  }
  return node;
}

- (NSString *)xmlElementName {
  return @"direct-parameter";
}

#pragma mark -
#pragma mark Parsing
- (void)setXMLAttributes:(NSDictionary *)attrs {
  [super setXMLAttributes:attrs];
  NSString *optional = [attrs objectForKey:@"optional"];
  if (optional && ![optional isEqualToString:@"no"]) {
    [self setOptional:YES];
  }
}

@end

@implementation SdefParameter (SdefXMLManager)
#pragma mark XML Generation
- (SdefXMLNode *)xmlNodeForVersion:(SdefVersion)version {
  SdefXMLNode *node = [super xmlNodeForVersion:version];
  if (node) {
    if ([self isOptional]) {
      if (version >= kSdefTigerVersion) {
        [node setAttribute:@"yes" forKey:@"optional"];
      } else {
        [node setAttribute:@"optional" forKey:@"optional"];
      }
    }
  }
  return node;
}

- (NSString *)xmlElementName {
  return @"parameter";
}

#pragma mark -
#pragma mark Parsing
- (void)setXMLAttributes:(NSDictionary *)attrs {
  [super setXMLAttributes:attrs];

  NSString *optional = [attrs objectForKey:@"optional"];
  if (optional && ![optional isEqualToString:@"no"]) {
    [self setOptional:YES];
  }
}

@end

@implementation SdefResult (SdefXMLManager)
#pragma mark XML Generation
- (SdefXMLNode *)xmlNodeForVersion:(SdefVersion)version {
  SdefXMLNode *node = nil;
  if ([self hasType] && (node = [super xmlNodeForVersion:version])) {
    [node removeAttributeForKey:@"name"];
    [node setEmpty:YES];
  }
  return node;
}

- (NSString *)xmlElementName {
  return @"result";
}

@end


