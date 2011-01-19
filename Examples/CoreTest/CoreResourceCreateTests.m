//
//  CoreResourceCreateTests.m
//  CoreTest
//
//  Created by Mike Laurence on 1/19/10.
//  Copyright 2010 Mike Laurence. All rights reserved.
//

#import "CoreResourceTestCase.h"

@interface CoreResourceCreateTests : CoreResourceTestCase {
	Artist *artist_;
}
@end

@implementation CoreResourceCreateTests

#pragma mark -
#pragma mark Create

- (void) testCreateLocal { 
    Artist* artistOne = [Artist create:[self artistData:0]];
    [self validateFirstArtist:artistOne];
    
    Artist* artistTwo = [Artist create:[self artistData:1]];
    [self validateSecondArtist:artistTwo];
	[Artist destroyAllLocal];
}

-(void) testCreateRemote {
	Artist *artistOne = [Artist create:[self artistData:0]];
	artistOne.resourceId = nil;
	[[artistOne managedObjectContext] save:nil];
	[artistOne push];
}
-(void) testCreateRemoteWithoutLocal {
	[self prepare:@selector(testCreateRemoteWithoutLocal)];
	Artist* artistOne = [Artist create:[self artistData:1]];
	[[CoreManager sharedCoreManager] save];
	[artistOne pushForAction:Create AndNotify:self withSelector:@selector(midpointTestCreateRemoteWithOutLocal:)];
	[self waitForStatus:kGHUnitWaitStatusSuccess timeout:10.0];
}
-(void) midpointTestCreateRemoteWithOutLocal:(CoreRequest *)request {
	[[[[Artist class] coreManager] managedObjectContext] rollback]; // sneakily we didn't save
	[Artist findAllRemote];
	[self performSelector:@selector(completeTestCreateRemoteWithoutLocal) withObject:nil afterDelay:5];
}
-(void) completeTestCreateRemoteWithoutLocal {
	NSFetchRequest *fetch = [Artist fetchRequestWithSort:nil andPredicate:[NSPredicate predicateWithFormat:@"name like \"Peter Gabriel\""]];
	NSArray *artists = [[[[Artist class]coreManager] managedObjectContext] executeFetchRequest:fetch error:nil];
	Artist *peterGabriel = [artists objectAtIndex:0];
	[self validateFirstArtist:peterGabriel];
	GHAssertTrue([peterGabriel isInRemoteCollection], @"The resource should have a remote Id");
	[self notify:kGHUnitWaitStatusSuccess forSelector:@selector(testCreateRemoteWithoutLocal)];
}

-(void) testCreateRemoteWithLocal {
	
	[self prepare:@selector(testCreateRemoteWithLocal)];
	artist_ = [[Artist create:[self artistData:0]]retain];
	artist_.resourceId = nil;
	[[CoreManager sharedCoreManager] save];
	[artist_ push];
	[self performSelector:@selector(completeTestCreateRemoteWithLocal) withObject:nil afterDelay:5];
	[self waitForStatus:kGHUnitWaitStatusSuccess timeout:1000.0];
}

-(void) completeTestCreateRemoteWithLocal {
	// Examine the retained artist:
	GHAssertTrue([artist_ isInRemoteCollection], @"The resource should now have a remote Id");
	DLog(@"Artist Id: %@ Name: %@", artist_.resourceId, artist_.name);
	[self notify:kGHUnitWaitStatusSuccess forSelector:@selector(testCreateRemoteWithLocal)];
}

@end
