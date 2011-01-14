//
//  CoreResourceReadTests.m
//  CoreTest
//
//  Created by Mike Laurence on 1/19/10.
//  Copyright 2010 Mike Laurence. All rights reserved.
//

#import "CoreResourceTestCase.h"

@interface CoreResourceReadTests : CoreResourceTestCase {}
@end

@implementation CoreResourceReadTests


- (BOOL)shouldRunOnMainThread { return NO; }

#pragma mark -
#pragma mark Read


- (void) testFindWithoutLocalHit {
	[self prepare:@selector(completeTestFindWithoutLocalHit)];
    GHAssertFalse([[Artist find:[NSNumber numberWithInt:0]] hasAnyResources], @"Find should not immediately return an object if the object doesn't yet exist");
    [self performSelector:@selector(completeTestFindWithoutLocalHit) withObject:nil afterDelay:5];
	[self waitForStatus:kGHUnitWaitStatusSuccess timeout:10];
}

- (void) completeTestFindWithoutLocalHit {
    // Verify existance of artist after find call
    GHAssertEquals((NSInteger) [[self allLocalArtists] count], 1, nil);
    [self validateFirstArtist:[[self allLocalArtists] objectAtIndex:0]];
	[self notify:kGHUnitWaitStatusSuccess forSelector:@selector(completeTestFindWithoutLocalHit)];
}

- (void) testFindWithLocalHit {
    [self loadArtist:0];
    CoreResult* result = [Artist find:[NSNumber numberWithInt:0]];
    GHAssertEquals((NSInteger) [result resourceCount], 1, nil);
    GHAssertEquals((NSInteger) [[self allLocalArtists] count], 1, nil);
	[Artist destroyAllLocal];
}

- (void) testFindAndNotify {
    [self prepare:@selector(completeTestFindAndNotify:)];
    [Artist find:[NSNumber numberWithInt:0] andNotify:self withSelector:@selector(completeTestFindAndNotify:)];
    [self waitForStatus:kGHUnitWaitStatusSuccess timeout:10.0];
}

- (void) completeTestFindAndNotify:(CoreResult*)result {
    GHAssertEquals((NSInteger) [result resourceCount], 1, nil);
    [self validateFirstArtist:[[result resources] lastObject]];
    [self notify:kGHUnitWaitStatusSuccess forSelector:@selector(completeTestFindAndNotify:)];
}

- (void) testFindAllWithoutLocalHits { 
	[self prepare:@selector(completeTestFindAllWithoutLocalHits)];
	GHAssertFalse([[Artist findAll] hasAnyResources], @"Find all should not immediately any objects if the objects don't yet exist");
    [self performSelector:@selector(completeTestFindAllWithoutLocalHits) withObject:nil afterDelay:5];
	[self waitForStatus:kGHUnitWaitStatusSuccess timeout:10];
}

- (void) completeTestFindAllWithoutLocalHits {    
    // Verify existance of artists after find call
    GHAssertEquals((NSInteger) [[self allLocalArtists] count], 3, nil);
    [self validateFirstArtist:[[self allLocalArtists] objectAtIndex:0]];
    [self validateSecondArtist:[[self allLocalArtists] objectAtIndex:1]];
	[self notify:kGHUnitWaitStatusSuccess forSelector:@selector(completeTestFindAllWithoutLocalHits)];

}

- (void) testFindAllWithSomeLocalHits { 
	[self prepare:@selector(completeTestFindAllWithSomeLocalHits)];
    // Pre-fetch two artists so that they're cached locally
    [self loadArtist:0];
    [self loadArtist:2];
    
    CoreResult* result = [Artist findAllLocal];
    GHAssertEquals((NSInteger) [result resourceCount], 2, nil);
	// trigger the remote fetch
	[Artist findAll];
    [self performSelector:@selector(completeTestFindAllWithSomeLocalHits) withObject:nil afterDelay:10];
	[self waitForStatus:kGHUnitWaitStatusSuccess timeout:20];
}

- (void) completeTestFindAllWithSomeLocalHits {
    GHAssertEquals((NSInteger) [[Artist findAllLocal] resourceCount], 3, nil);
	[self notify:kGHUnitWaitStatusSuccess forSelector:@selector(completeTestFindAllWithSomeLocalHits)];
}
 
- (void) testFindAllWithAllLocalHits { 
    // Pre-fetch all artists
    [self loadAllArtists];

    CoreResult* result = [Artist findAll];
    GHAssertEquals((NSInteger) [result resourceCount], 3, nil);
    
    [NSThread sleepForTimeInterval:0.1];
    GHAssertEquals((NSInteger) [[self allLocalArtists] count], 3, nil);
}

/*
- (void) testFindAllParameterizedWithoutLocalHits { GHFail(nil); }
- (void) testFindAllParameterizedWithLocalHits { GHFail(nil); }
*/

- (void) testFindAllAndNotify {
    [self prepare:@selector(completeTestFindAllAndNotify:)];
    [Artist findAll:nil andNotify:self withSelector:@selector(completeTestFindAllAndNotify:)];
    [self waitForStatus:kGHUnitWaitStatusSuccess timeout:10];
}

- (void) completeTestFindAllAndNotify:(CoreResult*)result {
    GHAssertEquals([result resourceCount], 3, nil);
    [self validateFirstArtist:[[result resources] objectAtIndex:0]];
    [self validateSecondArtist:[[result resources] objectAtIndex:1]];
    [self notify:kGHUnitWaitStatusSuccess forSelector:@selector(completeTestFindAllAndNotify:)];
}

- (void) testFindLocal {
    [self loadArtist:1];

    CoreResult* result = [Artist findLocal:[NSNumber numberWithInt:1]];
    GHAssertEquals([result resourceCount], 1, nil);
    [self validateSecondArtist:(Artist*)[result resource]];
}

- (void) testFindAllLocal {
    [self loadAllArtists];
    CoreResult* result = [Artist findAllLocal];
    GHAssertEquals((NSInteger) [result resourceCount], 3, nil);
    // Sort results by ID manually so we can validate
    NSArray* sortedResources = [[result resources] sortedArrayUsingDescriptors:
        [CoreUtils sortDescriptorsFromString:@"resourceId ASC"]];
    [self validateFirstArtist:(Artist*)[sortedResources objectAtIndex:0]];
    [self validateSecondArtist:(Artist*)[sortedResources objectAtIndex:1]];
}


- (void) testFindRemote {
	[self prepare:@selector(completeTestFindRemote)];
    [Artist findRemote:[NSNumber numberWithInt:1]];
    [self performSelector:@selector(completeTestFindRemote) withObject:nil afterDelay:5];
	[self waitForStatus:kGHUnitWaitStatusSuccess timeout:10];
}

- (void) completeTestFindRemote {
    GHAssertEquals((NSInteger) [[self allLocalArtists] count], 1, nil);
    [self validateSecondArtist:(Artist*)[[self allLocalArtists] lastObject]];
	[self notify:kGHUnitWaitStatusSuccess forSelector:@selector(completeTestFindRemote)];
}

- (void) testFindRemoteAndNotify { 
    [self prepare:@selector(completeTestFindRemoteAndNotify:)];
    [Artist findRemote:[NSNumber numberWithInt:0] andNotify:self withSelector:@selector(completeTestFindRemoteAndNotify:)];
    [self waitForStatus:kGHUnitWaitStatusSuccess timeout:10];
}

- (void) completeTestFindRemoteAndNotify:(CoreResult*)result {
    GHAssertEquals((NSInteger) [result resourceCount], 1, nil);
    [self validateFirstArtist:(Artist*)[result resource]];
    [self notify:kGHUnitWaitStatusSuccess forSelector:@selector(completeTestFindRemoteAndNotify:)];
}

- (void) testFindAllRemote {
	[self prepare:@selector(completeTestFindAllRemote)];
	GHAssertEquals((NSInteger) [[self allLocalArtists] count], 0, nil);
    [Artist findAllRemote];
    [self performSelector:@selector(completeTestFindAllRemote) withObject:nil afterDelay:5];
	[self waitForStatus:kGHUnitWaitStatusSuccess timeout:10.0];
}

- (void) completeTestFindAllRemote {
    GHAssertEquals((NSInteger) [[self allLocalArtists] count], 3, nil);
    [self validateFirstArtist:[[self allLocalArtists] objectAtIndex:0]];
    [self validateSecondArtist:[[self allLocalArtists] objectAtIndex:1]];
	[self notify:kGHUnitWaitStatusSuccess forSelector:@selector(completeTestFindAllRemote)];
}

- (void) testFindAllRemoteAndNotify {
    [self prepare:@selector(completeTestFindAllRemoteAndNotify:)];
    [Artist findAllRemote:nil andNotify:self withSelector:@selector(completeTestFindAllRemoteAndNotify:)];
    [self waitForStatus:kGHUnitWaitStatusSuccess timeout:10.0];
}

- (void) completeTestFindAllRemoteAndNotify:(CoreResult*)result {
    GHAssertEquals((NSInteger) [result resourceCount], 3, nil);
	// do we need to refault the data?
    [self validateFirstArtist:(Artist*)[result resource]];
    [self validateSecondArtist:[[self allLocalArtists] objectAtIndex:1]];
    [self notify:kGHUnitWaitStatusSuccess forSelector:@selector(completeTestFindAllRemoteAndNotify:)];
}

@end
