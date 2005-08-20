//
//  SdefSynonym.m
//  SDef Editor
//
//  Created by Grayfox on 02/01/05.
//  Copyright 2005 Shadow Lab. All rights reserved.
//

#import "SdefSynonym.h"
#import "SdefBase.h"
#import "SdefImplementation.h"

@implementation SdefSynonym
#pragma mark Protocols Implementations
- (id)copyWithZone:(NSZone *)aZone {
  SdefSynonym *copy = [super copyWithZone:aZone];
  copy->sd_code = [sd_code copy];
  copy->sd_impl = [sd_impl copy];
  return copy;
}

- (void)encodeWithCoder:(NSCoder *)aCoder {
  [super encodeWithCoder:aCoder];
  [aCoder encodeObject:sd_code forKey:@"SYCode"];
  [aCoder encodeObject:sd_impl forKey:@"SYImpl"];
}

- (id)initWithCoder:(NSCoder *)aCoder {
  if (self = [super initWithCoder:aCoder]) {
    sd_code = [[aCoder decodeObjectForKey:@"SYCode"] retain];
    sd_impl = [[aCoder decodeObjectForKey:@"SYImpl"] retain];
  }
  return self;
}

#pragma mark -
- (void)dealloc {
  [sd_impl release];
  [sd_code release];
  [super dealloc];
}

- (NSString *)description {
  return [NSString stringWithFormat:@"<%@ %p> {name=%@ code=%@ hidden=%@}", 
    NSStringFromClass([self class]), self,
 [self name], sd_code, sd_slFlags.hidden ? @"YES" : @"NO"];
}

#pragma mark -
- (NSString *)objectTypeName {
  return @"synonym";
}

- (NSImage *)icon {
  return [NSImage imageNamed:@"Misc"];
}

- (SdefImplementation *)impl {
  if (!sd_impl) {
    SdefImplementation *impl = [[SdefImplementation allocWithZone:[self zone]] init];
    [self setImpl:impl];
    [impl release];
  }
  return sd_impl;
}

- (void)setImpl:(SdefImplementation *)newImpl {
  if (sd_impl != newImpl) {
    [sd_impl setOwner:nil];
    [sd_impl release];
    sd_impl = [newImpl retain];
    [sd_impl setOwner:(SdefObject *)self];
  }
}

- (NSString *)code {
  return sd_code;
}

- (void)setCode:(NSString *)code {
  if (code != sd_code) {
    NSUndoManager *undo = [[self owner] undoManager];
    if (undo) {
      [undo registerUndoWithTarget:self selector:_cmd object:sd_code];
      [undo setActionName:NSLocalizedStringFromTable(@"Change Synonym", @"SdefLibrary", @"Undo Action: Change synonym.")];
    }
    [sd_code release];
    sd_code = [code copy];
  }
}

- (BOOL)isHidden {
  return sd_slFlags.hidden;
}

- (void)setHidden:(BOOL)flag {
  flag = flag ? 1 : 0;
  if (flag != sd_slFlags.hidden) {
    NSUndoManager *undo = [[self owner] undoManager];
    if (undo) {
      [[undo prepareWithInvocationTarget:self] setHidden:sd_slFlags.hidden];
      [undo setActionName:NSLocalizedStringFromTable(@"Change Synonym", @"SdefLibrary", @"Undo Action: Change synonym.")];
    }
    sd_slFlags.hidden = flag;
  }
}

@end
