//
//  CoreManager.m
//  CoreManager
//
//  Created by Mike Laurence on 12/24/09.
//  Copyright Mike Laurence 2010. All rights reserved.
//

#import "CoreManager.h"
#import "CoreResource.h"

#if TARGET_OS_IPHONE
#import "Reachability.h"
#endif

#define CRDEFAULT_CONFIGURATION_FILE_NAME @"CoreResourceDefaults"
#define CRDEFAULT_DATETIME_FORMAT @"yyyy-MM-dd'T'HH:mm:ss'Z'"
#define CRDEFAULT_PERSISTENTSTORE_NAME @"coreresource.sqlite"
#define CRDEFAULT_PERSISTENTSTORE_TYPE NSSQLiteStoreType

@interface CoreManager()
@property (nonatomic, retain) NSManagedObjectModel *managedObjectModel;
@property (nonatomic, retain) NSManagedObjectContext *managedObjectContext;
@property (nonatomic, retain) NSPersistentStoreCoordinator *persistentStoreCoordinator;
@property (nonatomic, retain) NSDictionary *settings;
@property (nonatomic, retain) NSString *databaseName;
@end


@implementation CoreManager

@synthesize persistentStoreCoordinator, managedObjectContext, managedObjectModel;
@synthesize requestQueue, deserialzationQueue;
@synthesize remoteSiteURL, useBundleRequests, bundleRequestDelay, defaultDateParser;
@synthesize entityDescriptions, modelProperties, modelRelationships, modelAttributes;
@synthesize logLevel;
@synthesize settings, databaseName, debugName;

#pragma mark -
#pragma mark Static access
static CoreManager* sharedCoreManager = nil;

+ (CoreManager*) main { 
	//DLog(@"Main called to fetch %@", sharedCoreManager.debugName);
	return sharedCoreManager;
}
+ (void) setMain:(CoreManager*) newMain {
	// removed as this should never be called as this is a singleton
	NSLog(@"setMain is a depreciated method that should not be called unless for testing");
	sharedCoreManager = newMain;
}

+(CoreManager *)sharedCoreManager {
	@synchronized(self) {
		//DLog(@"sharedCoreManager called to fetch %@", sharedCoreManager.debugName);
		if (sharedCoreManager == nil) {
			sharedCoreManager = [[self alloc] init];
			sharedCoreManager.debugName = @"New Manager";
			DLog(@"New shared Core Manager %@", sharedCoreManager.debugName);

		}
	}
	return sharedCoreManager;
}

+(id)allocWithZone:(NSZone *)zone {
	@synchronized (self){
		if(sharedCoreManager == nil) {
			sharedCoreManager = [super allocWithZone:zone];
			return sharedCoreManager;
		}
	}
	return nil;
}

-(id)copyWithZone:(NSZone *)zone {
	return self;
}

-(id)retain {
	return self;
}

-(NSUInteger)retainCount {
	return NSUIntegerMax;
}

-(void)release {
	//NOOP
}

-(id)autorelease {
	return self;
}

#pragma mark -
#pragma mark Configuration
-(NSDictionary *)settings {
	if (settings == nil) {
		NSString *path = [[NSBundle mainBundle] pathForResource:CRDEFAULT_CONFIGURATION_FILE_NAME ofType:@"plist"];
		NSDictionary *aSettings = [NSDictionary dictionaryWithContentsOfFile:path];
		self.settings = aSettings;
	}
	return settings;
}

- (id) init {
	// as access through @synchronized, we don't need to lock the init
	if ((self = [super init])) {


		
		
		// register for save notifications on the managed object context:
		
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(willSave:) name:NSManagedObjectContextWillSaveNotification object:nil];
		
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(didSave:) name:NSManagedObjectContextDidSaveNotification object:nil];
		
		// setup operation queues for the background operations:
		
        requestQueue = [[NSOperationQueue alloc] init];
        deserialzationQueue = [[NSOperationQueue alloc] init];
        
        // Default date parser is ruby DateTime.to_s style parser
        defaultDateParser = [[NSDateFormatter alloc] init];
		if([settings valueForKey:@"DateFormat"]) {
			[defaultDateParser setDateFormat:[self.settings valueForKey:@"DateFormat"]];
		}else {
			[defaultDateParser setDateFormat:CRDEFAULT_DATETIME_FORMAT];
		}

        
        self.entityDescriptions = [NSMutableDictionary dictionary];
        self.modelProperties = [NSMutableDictionary dictionary];
        self.modelRelationships = [NSMutableDictionary dictionary];
        
        useBundleRequests = NO;
        bundleRequestDelay = 0;
        
        logLevel = 1;

        
    }
    return self;
}

- (id) initWithOptions:(NSDictionary*)options {
// removed as this should never be called
	NSLog(@"initWithOptions is a depreciated method that should not be called!");
	self.databaseName = [options valueForKey:@"databaseName"];
	
    return [self init];
}


#pragma mark -
#pragma mark Networking

- (void) enqueueRequest:(ASIHTTPRequest*)request {
	DLog(@"[CoreManager#enqueueRequest] request queued: %@", request.url);
    if ([CoreManager sharedCoreManager].logLevel > 2) // CHANGED removed semicolon
        NSLog(@"[CoreManager#enqueueRequest] request queued: %@", request.url);
	if (request) { // no point in adding a nil request
		[requestQueue addOperation:request];
	}
    
}


#pragma mark -
# pragma mark Alerts

+ (void) alertWithError:(NSError*)error {
    [self alertWithTitle:@"Error" andMessage:[error localizedDescription]];
}

#if TARGET_OS_IPHONE
+ (void) alertWithTitle:(NSString*)title andMessage:(NSString*)message {
    UIAlertView *alert = [[UIAlertView alloc] initWithTitle:title
        message:message delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil];
    [alert show];
    [alert release];
}
#endif

+ (void) logCoreDataError:(NSError *)error {
    NSLog(@"Failed to save to data store: %@", [error localizedDescription]);
    NSArray* detailedErrors = [[error userInfo] objectForKey:NSDetailedErrorsKey];
    if(detailedErrors != nil && [detailedErrors count] > 0) {
        for(NSError* detailedError in detailedErrors)
                NSLog(@"  DetailedError: %@", [detailedError userInfo]);
    }
    else
        NSLog(@"  %@", [error userInfo]);
}




#pragma mark -
#pragma mark Core Data stack

-(NSManagedObjectModel *)managedObjectModel {
	if (managedObjectModel == nil) {
		NSManagedObjectModel *aModel = [NSManagedObjectModel mergedModelFromBundles:nil];
		self.managedObjectModel = aModel;
	}
	return managedObjectModel;
}
-(NSPersistentStoreCoordinator *) persistentStoreCoordinator {
	if (persistentStoreCoordinator == nil) {
		NSError *error = nil;
		NSURL *storeUrl = [NSURL fileURLWithPath: [[self applicationDocumentsDirectory] 
												   stringByAppendingPathComponent: self.databaseName != nil ? self.databaseName : @"coreresource.sqlite"]];
        NSPersistentStoreCoordinator *aCoordinator = [[NSPersistentStoreCoordinator alloc] initWithManagedObjectModel:self.managedObjectModel];
        if (![aCoordinator addPersistentStoreWithType:NSSQLiteStoreType configuration:nil URL:storeUrl options:nil error:&error]) {
            NSLog(@"Unresolved error in persistent store creation %@, %@", error, [error userInfo]);
            abort();
        }
		self.persistentStoreCoordinator = aCoordinator;		
	}
	return persistentStoreCoordinator;
}
-(NSString *)databaseName {
	if (databaseName == nil) {
		NSString *aName = [self.settings valueForKey:@"DatabaseName"];		
        self.databaseName = aName;
	}
	return databaseName;
}
-(NSManagedObjectContext *)managedObjectContext {
	if (managedObjectContext == nil) {
		NSManagedObjectContext *aContext = [[NSManagedObjectContext alloc] init];
		[aContext setPersistentStoreCoordinator:self.persistentStoreCoordinator];
		self.managedObjectContext = aContext;
	}
	return managedObjectContext;
}
- (void)save {
    NSError *error = nil;
    if (self.managedObjectContext != nil) {
        if ([self.managedObjectContext hasChanges] && ![self.managedObjectContext save:&error]) {
			DLog(@"Failed to save managedcontext: %@", [error localizedDescription]);
			[[self class] logCoreDataError:error];
        } 
    }
}
-(void)willSave:(NSNotification *)notification {
	// the notifcation object is the ManagedObjectContext that will be saved
	NSManagedObjectContext *moc = (NSManagedObjectContext *)[notification object];
	//TODO: Check if the managedObjectContext is the one doing imports. We don't want to change any values on that moc
	if ([moc hasChanges]){
		NSDate *timestamp = [NSDate date];
		
		NSSet *insertedObjects = [moc insertedObjects];
		for (NSManagedObject *mo in insertedObjects){
			if ([mo isKindOfClass:[CoreResource class]]) {
				NSString *createdAtField = [[mo class] createdAtField];
				if ([[[mo entity]attributesByName] objectForKey:createdAtField]) {
					[mo setPrimitiveValue:timestamp forKey:createdAtField];
				}
			}
		}		
		// Set the updatedAt field for any changed objects
		NSSet *updatedObjects = [moc updatedObjects];
		for (NSManagedObject *mo in updatedObjects) {
			if ([mo isKindOfClass:[CoreResource class]]){ 
				// We have a coreResource based object
				// set the updatedAtField
				NSString *updatedAtField = [[mo class] updatedAtField];
				if ([[[mo entity]attributesByName] objectForKey:updatedAtField]) {
					[mo setPrimitiveValue:timestamp forKey:updatedAtField];
				}
			}
		}
/*		
		NSSet *deletedObjects = [moc deletedObjects];
		for (NSManagedObject *mo in deletedObjects) {
			if ([mo isKindOfClass:[CoreResource class]]){ 
			}
		}
 */
	}
}
-(void)didSave:(NSNotification *)notification {
	DLog(@"Core Manager did Save Notification");
}

- (NSManagedObjectContext*)newContext {
    NSManagedObjectContext* context = [[NSManagedObjectContext alloc] init];
    [context setPersistentStoreCoordinator:persistentStoreCoordinator];
    return context; // note that this is not an autoreleased object
}


- (void) mergeContext:(NSNotification*)notification {
    NSAssert([NSThread mainThread], @"Must be on the main thread!");
    [managedObjectContext mergeChangesFromContextDidSaveNotification:notification];
  //  DLog(@"\n\nMerged context, now has contents:\n\n %@ \n\n", [[Artist findAllLocal] resources]);
}


#pragma mark -
#pragma mark Application's Documents directory

/**
 Returns the path to the application's Documents directory.
 */
- (NSString *)applicationDocumentsDirectory {
	return [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) lastObject];
}


#pragma mark -
#pragma mark Memory management

- (void)dealloc {

	[[NSNotificationCenter defaultCenter]removeObject:self];
    [modelProperties release];
    [modelRelationships release];

    [remoteSiteURL release];

    [managedObjectContext release];
    [managedObjectModel release];
    [persistentStoreCoordinator release];
	[settings release];
	[databaseName release];
	[debugName release];

    [super dealloc];
}


@end

