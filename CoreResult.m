//
//  CoreResult.m
//  CoreResource
//
//  Created by Mike Laurence on 12/31/09.
//  Copyright 2009 Punkbot LLC. All rights reserved.
//

#import "CoreResult.h"


@implementation CoreResult

@synthesize request;
@synthesize resources;
@synthesize error;

- (id) initWithResource:(id)resource {
    if (self = [super init])
        self.resources = [NSArray arrayWithObject:resource];
    return self;
}

- (id) initWithResources:(NSArray*)resourceArray {
    if (self = [super init])
        self.resources = resourceArray;
    return self;
}

@end
