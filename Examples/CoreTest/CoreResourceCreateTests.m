//
//  CoreResourceCreateTests.m
//  CoreTest
//
//  Created by Mike Laurence on 1/19/10.
//  Copyright 2010 Mike Laurence. All rights reserved.
//

#import "CoreResourceTestCase.h"

@interface CoreResourceCreateTests : CoreResourceTestCase {}
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
	[self prepare:@selector(completeTestCreateRemote)];
	Artist* artistOne = [Artist create:[self artistData:0]];
	[artistOne pushForAction:Create AndNotify:self withSelector:@selector(midpointTestCreateRemote:)];
	[self waitForStatus:kGHUnitWaitStatusSuccess timeout:10.0];
}
-(void) midpointTestCreateRemote:(CoreRequest *)request {
	[[[[Artist class] coreManager] managedObjectContext] rollback]; // shouldn't call the remote destroy as they're not inserted into the MOC
	[Artist findAllRemote];
	[self performSelector:@selector(completeTestCreateRemote) withObject:nil afterDelay:5];
}
-(void) completeTestCreateRemote {
	NSFetchRequest *fetch = [Artist fetchRequestWithSort:nil andPredicate:[NSPredicate predicateWithFormat:@"name like \"Peter Gabriel\""]];
	NSArray *artists = [[[[Artist class]coreManager] managedObjectContext] executeFetchRequest:fetch error:nil];
	[self validateFirstArtist:[artists objectAtIndex:0]];
}
/*
- (void) testCreateOrUpdateWithDictionary { GHFail(nil); }
- (void) testCreateOrUpdateWithDictionaryAndRelationship { GHFail(nil); }
*/

@end
