//
//  CoreResourceTestCase.m
//  CoreTest
//
//  Created by Mike Laurence on 1/19/10.
//  Copyright 2010 Mike Laurence. All rights reserved.
//

#import "CoreResourceTestCase.h"

@implementation CoreResourceTestCase

@synthesize delegatesCalled;

static int dbInc = 1;

#pragma mark -
#pragma mark Convenience methods

- (NSString*) artistDataJSON:(NSString*)file {
    NSError* parseError;
    return [NSString stringWithContentsOfFile:
        [[NSBundle mainBundle] pathForResource:file ofType:@"json"] 
        encoding:NSUTF8StringEncoding error:&parseError];
}

- (NSDictionary*) artistData:(int)index {
    return [[self artistDataJSON:[NSString stringWithFormat:@"artists.%@", [NSNumber numberWithInt:index]]] JSONValue];
}

- (void) loadAllArtists {
    [self loadArtist:0];
    [self loadArtist:1];
    [self loadArtist:2];
}

- (Artist*) loadArtist:(int)index {
    return [self loadArtist:index inContext:[[CoreManager sharedCoreManager]managedObjectContext]];
}

- (Artist*) loadArtist:(int)index andSave:(BOOL)shouldSave {
    return [self loadArtist:index andSave:shouldSave inContext:[[CoreManager sharedCoreManager] managedObjectContext]];
}

- (Artist*) loadArtist:(int)index inContext:(NSManagedObjectContext*)context {
    return [self loadArtist:index andSave:YES inContext:context];
}

- (Artist*) loadArtist:(int)index andSave:(BOOL)shouldSave inContext:(NSManagedObjectContext*)context {
    Artist* artist = [NSEntityDescription insertNewObjectForEntityForName:@"Artist" inManagedObjectContext:context];
    NSDictionary* dict = [self artistData:index];
    artist.resourceId = [dict objectForKey:@"id"];
    artist.name = [dict objectForKey:@"name"];
    artist.summary = [dict objectForKey:@"summary"];
    artist.detail = [dict objectForKey:@"detail"];
    artist.updatedAt = [[[CoreManager sharedCoreManager] defaultDateParser] dateFromString:[dict objectForKey:@"updatedAt"]];
    
    NSDictionary* songsArray = [dict objectForKey:@"songs"];
    NSMutableSet* songs = [NSMutableSet set];
    if (songsArray) {
        for (NSDictionary* dict in songsArray) {
            Song* song = [NSEntityDescription insertNewObjectForEntityForName:@"Song" inManagedObjectContext:context];
            song.resourceId = [dict objectForKey:@"id"];
            song.name = [dict objectForKey:@"name"];
            [songs addObject:song];
        }
        artist.songs = songs;
    }
    
    if (shouldSave) {
        NSError *error = nil;
        [context save:&error];
    }
    
    return artist;
}

- (NSArray*) allLocalArtists {
    NSError* error = nil;
    NSArray* artists = [[Artist managedObjectContext] executeFetchRequest:[Artist fetchRequestWithSort:@"resourceId ASC" andPredicate:nil] error:&error];
    GHAssertNULL(error, @"There should be no errors in the allLocalArtists convenience method");
    NSLog(@"%i local artists", [artists count]);
    return artists != nil ? artists : [NSArray array];
}

- (void) validateFirstArtist:(Artist*)artist {
	DLog(@"Validating Artist: %@", artist.name);
    GHAssertEqualStrings(artist.name, @"Peter Gabriel", nil);
    GHAssertEqualStrings(artist.summary, @"Peter Brian Gabriel is an English musician and songwriter.", nil);
    //GHAssertEquals([artist.resourceId intValue], 0, nil);
}

- (void) validateSecondArtist:(Artist*)artist {
    GHAssertEqualStrings(artist.name, @"Spoon", nil);
    GHAssertEqualStrings(artist.summary, @"Spoon is an American indie rock band from Austin, Texas.", nil);
   // GHAssertEquals([artist.resourceId intValue], 1, nil); // given a remote ID we don't know what the 
    GHAssertEquals((NSInteger) [artist.songs count], 2, nil);
    GHAssertEqualStrings(((Song*)[[artist sortedSongs] objectAtIndex:0]).name, @"Don't Make Me a Target", nil);
    GHAssertEqualStrings(((Song*)[[artist sortedSongs] objectAtIndex:1]).name, @"You Got Yr. Cherry Bomb", nil);
}



#pragma mark -
#pragma mark GHUnit Configuration

- (void) setUp {
	//DLog(@"GHUnit setup called");
	// NSString *dbName = $S(@"db-%i-%i.sqlite", [NSDate timeIntervalSinceReferenceDate], dbInc++);
    //DLog(@"\n\nCreating core manager with DB named '%@'\n\n", dbName);
    CoreManager *aCoreManager = [CoreManager sharedCoreManager];
    aCoreManager.logLevel = 2;
   // aCoreManager.useBundleRequests = YES;
    aCoreManager.bundleRequestDelay = 0.01;
	aCoreManager.remoteSiteURL = @"http://localhost:5555/cgi-bin/WebObjects/CoreResourceTest.woa/ra";
	aCoreManager.debugName = @"CoreResourceTestCase Core Manager";
	[Artist destroyAllLocal];

    //[CoreManager setMain:aCoreManager];
}

- (void) tearDown {
	DLog(@"GHUnit teardown called");
}


@end