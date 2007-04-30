/*
 *  SdefXMLGenerator.m
 *  Sdef Editor
 *
 *  Created by Rainbow Team.
 *  Copyright � 2006 - 2007 Shadow Lab. All rights reserved.
 */

#import "SdefXMLGenerator.h"
#import "SdefXMLNode.h"
#import "SdefComment.h"
#import "SdefXMLBase.h"
#import <ShadowKit/SKExtensions.h>

@implementation SdefXMLGenerator

- (id)init {
  if (self = [super init]) {
    sd_metas = YES;
  }
  return self;
}

- (id)initWithRoot:(SdefObject *)anObject {
  if (self = [self init]) {
    [self setRoot:anObject];
  }
  return self;
}

- (void)dealloc {
  if (sd_doc) { CFRelease(sd_doc); sd_doc = nil; }
  [sd_root release];
  [sd_comment release];
  [super dealloc];
}

#pragma mark -
- (SdefObject *)root {
  return sd_root;
}
- (void)setRoot:(SdefObject *)anObject {
  SKSetterRetain(sd_root, anObject);
}

- (void)setIgnoreMetas:(BOOL)flag {
  sd_metas = !flag;
}
- (void)setHeaderComment:(NSString *)comment {
  SKSetterCopy(sd_comment, comment);
}

#pragma mark -
- (CFXMLTreeRef)appendNode:(CFXMLNodeRef)node {
  NSParameterAssert(node != nil);
  NSAssert(sd_node != NULL, @"Current node must not be nil.");
  CFXMLTreeRef treeNode = CFXMLTreeCreateWithNode(kCFAllocatorDefault, node);
  CFTreeAppendChild((CFTreeRef)sd_node, (CFTreeRef)treeNode);
  CFRelease(treeNode);
  return treeNode;
}

- (CFXMLTreeRef)appendTree:(CFXMLTreeRef)aTree {
  NSParameterAssert(aTree != nil);
  NSAssert(sd_node != NULL, @"Current node must not be nil.");
  CFTreeAppendChild((CFTreeRef)sd_node, (CFTreeRef)aTree);
  return aTree;
}

- (CFXMLTreeRef)appendElementNode:(NSString *)name attributesKeys:(NSArray *)keys attributesValues:(NSArray *)values isEmpty:(BOOL)flag {
  NSParameterAssert(name != nil);
  NSParameterAssert([keys count] == [values count]);
  CFXMLElementInfo infos;
  infos.attributes = (CFDictionaryRef)[[NSDictionary alloc] initWithObjects:values forKeys:keys];
  infos.attributeOrder = (CFArrayRef)keys;
  infos.isEmpty = flag;
  
  CFXMLNodeRef node = CFXMLNodeCreate(kCFAllocatorDefault, kCFXMLNodeTypeElement, (CFStringRef)name, &infos, kCFXMLNodeCurrentVersion);
  CFXMLTreeRef tree = [self appendNode:node];
  if (!flag) {
    sd_node = tree;
    sd_indent++;
  } 
  CFRelease(node);
  [(id)infos.attributes release];
  return tree;
}

- (CFXMLTreeRef)insertCDData:(NSString *)str {
  if ([str rangeOfString:@"]]>"].location != NSNotFound) {
    NSMutableString *mstr = [str mutableCopy];
    [mstr replaceOccurrencesOfString:@"]]>" withString:@"]]&gt;" 
                             options:0 range:NSMakeRange(0, [mstr length])];
    str = [mstr autorelease];
  }
  CFXMLNodeRef node = CFXMLNodeCreate(kCFAllocatorDefault, kCFXMLNodeTypeCDATASection, (CFStringRef)str, NULL, kCFXMLNodeCurrentVersion);
  CFXMLTreeRef tree = [self appendNode:node];
  CFRelease(node);
  return tree;
}

- (CFXMLTreeRef)insertTextNode:(NSString *)str {
  CFXMLNodeRef node = CFXMLNodeCreate(kCFAllocatorDefault, kCFXMLNodeTypeText, (CFStringRef)str, NULL, kCFXMLNodeCurrentVersion);
  CFXMLTreeRef tree  = [self appendNode:node];
  CFRelease(node);
  return tree;
}

- (CFXMLTreeRef)insertComment:(NSString *)str {
  CFXMLTreeRef tree = nil;
  NSMutableString *comment = [str mutableCopy]; 
  if (comment) {
    CFStringTrimWhitespace((CFMutableStringRef)comment);
    if ([comment length]) {
      /* '--' is not allow in XML comments. And a comment must not end with '-' */
      if ([str rangeOfString:@"--"].location != NSNotFound || [str hasSuffix:@"-"]) {
        str = [str mutableCopy];
        do {
          [(id)str replaceOccurrencesOfString:@"--" withString:@"-" 
                                      options:NSLiteralSearch range:NSMakeRange(0, [str length])];
        } while ([str rangeOfString:@"--"].location != NSNotFound);
        if ([str hasSuffix:@"-"])
          [(id)str appendString:@" "];
        [str autorelease];
      }
      CFXMLNodeRef node = CFXMLNodeCreate(kCFAllocatorDefault, kCFXMLNodeTypeComment, (CFStringRef)str, NULL, kCFXMLNodeCurrentVersion);
      tree  = [self appendNode:node];
      CFRelease(node);
    }
    [comment release];
  }
  return tree;
}

- (void)insertWhiteSpace {
  if (sd_node) {
    NSMutableString *str = [[NSMutableString alloc] initWithCapacity:sd_indent + 1];
    [str appendString:@"\n"];
    for (NSUInteger i = 0; i < sd_indent; i++) {
      [str appendString:@"\t"];
    }
    [self insertTextNode:str];
    [str release];
  }
}

- (void)upOneLevelWithWhiteSpace:(BOOL)flag {
  if (sd_node) {
    sd_indent = (sd_indent) ? sd_indent - 1 : 0;
    if (flag) [self insertWhiteSpace];
    sd_node = CFTreeGetParent((CFTreeRef)sd_node);
  }
}

- (void)createDocument {
  if (sd_doc) {
    CFRelease(sd_doc);
    sd_doc = nil;
  }
  CFXMLDocumentInfo info;
  info.sourceURL = nil;
  info.encoding = kCFStringEncodingUTF8;
  CFXMLNodeRef node = CFXMLNodeCreate(kCFAllocatorDefault,
                                      kCFXMLNodeTypeDocument,
                                      nil, &info, kCFXMLNodeCurrentVersion);
  sd_doc = CFXMLTreeCreateWithNode(kCFAllocatorDefault, node);
  sd_node = sd_doc;
  CFRelease(node);
  sd_indent = 0;
  CFXMLProcessingInstructionInfo procInfo = { CFSTR("version=\"1.0\" encoding=\"UTF-8\"") };
  node = CFXMLNodeCreate(kCFAllocatorDefault, kCFXMLNodeTypeProcessingInstruction, CFSTR("xml"), &procInfo, kCFXMLNodeCurrentVersion);
  [self appendNode:node];
  CFRelease(node);
  
  [self insertWhiteSpace];
  CFURLRef url = CFURLCreateWithString(kCFAllocatorDefault, CFSTR("file://localhost/System/Library/DTDs/sdef.dtd"), nil);
  CFXMLDocumentTypeInfo doctype = { {url, nil} };
  node = CFXMLNodeCreate(kCFAllocatorDefault, kCFXMLNodeTypeDocumentType, CFSTR("dictionary"), &doctype, kCFXMLNodeCurrentVersion);
  [self appendNode:node];
  CFRelease(node);
  CFRelease(url);
  
  if ([sd_comment length]) {
    [self insertWhiteSpace];  
    [self insertComment:sd_comment];
  }
}

- (void)insertMetas:(NSDictionary *)metas wsbefore:(BOOL)flag {
  if (sd_metas && metas && [metas count] > 0) {
    NSString *key;
    NSEnumerator *iter = [metas keyEnumerator];
    while (key = [iter nextObject]) {
      if (flag)
        [self insertWhiteSpace];
      if ([self insertComment:[NSString stringWithFormat:@" @%@(%@) ", key, [metas objectForKey:key]]]) {
        if (!flag)
          [self insertWhiteSpace];
      }
    }
  }
}

- (void)appendXMLNode:(SdefXMLNode *)node {
  if (![node isList]) {
    [self insertWhiteSpace];
    
    /* Insert meta */
    [self insertMetas:[node metas] wsbefore:NO];
    
    /* Insert comments */
    SdefComment *comment;
    NSEnumerator *comments = [[node comments] objectEnumerator];
    while (comment = [comments nextObject]) {
      if ([self insertComment:[comment value]])
        [self insertWhiteSpace];
    }
    /* Append the elements */
    [self appendElementNode:[node elementName]
             attributesKeys:[node attrKeys]
           attributesValues:[node attrValues]
                    isEmpty:[node isEmpty]];
    /* Write element content if needed */
    if ([node content]) {
      if ([node isCDData]) {
        [self insertCDData:[node content]];
      } else {
        [self insertTextNode:[node content]];
      }
    }
  }
  /* Append elements children if needed */
  SdefXMLNode *child = nil;
  NSEnumerator *children = [node childEnumerator];
  while (child = [children nextObject]) {
    [self appendXMLNode:child];
  }
  
  /* Insert postmeta */
  [self insertMetas:[node postmetas] wsbefore:YES];
  
  if (![node isList] && ![node isEmpty]) {
    [self upOneLevelWithWhiteSpace:([node content] == nil)];
  }
}

- (NSData *)xmlDataForVersion:(SdefVersion)version {
  if (!sd_root)
    return nil;
  
  [self createDocument];
  if (!sd_doc) return nil;
  
  [self appendXMLNode:[sd_root xmlNodeForVersion:version]];
  CFDataRef xml = CFXMLTreeCreateXMLData(kCFAllocatorDefault, sd_doc);
  return [(id)xml autorelease];
}

@end
