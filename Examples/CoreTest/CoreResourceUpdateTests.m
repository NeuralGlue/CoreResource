//
//  CoreResourceUpdateTests.m
//  CoreTest
//
//  Created by Mike Laurence on 1/19/10.
//  Copyright 2010 Mike Laurence. All rights reserved.
//

#import "CoreResourceTestCase.h"

@interface CoreResourceUpdateTests : CoreResourceTestCase {}
@end

@implementation CoreResourceUpdateTests

- (void) testUpdateWithDictionary {
    [self loadArtist:0];
    NSDictionary* updateDict = [[self artistDataJSON:@"artists.0.update"] JSONValue];
    
    Artist* artist = (Artist*)[[Artist findLocal:[NSNumber numberWithInt:0]] resource];
    [artist update:updateDict];
    
    GHAssertEqualStrings(artist.name, @"Peter B. Gabriel", nil);
    GHAssertEqualStrings(artist.summary, @"Peter Brian Gabriel is a musician and songwriter.", nil);
	[Artist destroyAllLocal];
}

-(void) testUpdateWithPush {
	[self prepare:@selector(completeTestUpdateWithPush:)];
	NSString *nameString = @"Frank Barnsley";
	[self loadArtist:1];
	Artist *artist = (Artist *)[[Artist find:[NSNumber numberWithInt:1]]resource];
	artist.name = nameString;
	[artist setValue:nil forKey:[Artist localIdField]]; //The artist doesn't actually exist
	[[[artist class] coreManager] save];
	[Artist destroyAllLocal];
	[self performSelector:@selector(midUpdateWithPush) withObject:nil afterDelay:5];
	[self waitForStatus:kGHUnitWaitStatusSuccess timeout:10.0];
}
-(void) midUpdateWithPush {
	[Artist find:[NSNumber numberWithInt:1] andNotify:self withSelector:@selector(completeTestUpdateWithPush:)];
}


-(void) completeTestUpdateWithPush:(CoreResult *)result {
	NSString *nameString = @"Frank Barnsley";
	Artist *artist = (Artist *)[result resource];
	if ([Artist useBundleRequests]) {
		GHAssertNotEqualStrings(artist.name, nameString, @"Using Bundle Requests");
	}else {
		GHAssertEqualStrings(artist.name, nameString, @"Using Remote Requests");
	}
    [self notify:kGHUnitWaitStatusSuccess forSelector:@selector(completeTestUpdateWithPush:)];
}
@end
