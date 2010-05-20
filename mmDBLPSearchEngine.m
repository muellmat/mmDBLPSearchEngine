/* mmDBLPSearchEngine */
//
//  Created by muellmat on 15-05-2010.
//  Copyright (c) 2010 Mekentosj.com. All rights reserved.
//
//  Based on the SDK created by Mekentosj on 17-01-2007.
//  Copyright (c) 2007 Mekentosj.com. All rights reserved.
// 
//  For use outside of the Papers application structure, please contact
//  Mekentosj at feedback@mekentosj.com
//  DO NOT REDISTRIBUTE WITHOUT ALL THE INCLUDED FILES


#import "mmDBLPSearchEngine.h"
#import "NSString_Extensions.h"

@interface mmDBLPSearchEngine (private)
BOOL isSearching;
BOOL shouldContinueSearch;

//caches
NSDictionary *cachedPredefinedSearchTerms;
NSDictionary *cachedSearchFields;
NSArray *cachedStopwords;
@end

// this category provides plugin specific helper methods for this plugin
// the mainly involve working with the dblp eutils.
@interface mmDBLPSearchEngine (dblp_methods)
-(NSArray*)stopwords;
-(NSString*)queryStringFromTokens:(NSArray*)tokens prefix:(NSString*)prefix;

-(NSString*)eUtilsBaseURL;
-(NSData*)fetchInfoForQuery:(NSString*)query retmax:(int)max extra:(NSString*)additional_terms response:(NSURLResponse**)response error:(NSError**)err;
-(NSData*)fetchArticleSummaryForQueryKey:(NSString*)querykey WebEnv:(NSString*)webenv range:(NSRange)range response:(NSURLResponse**)response error:(NSError**)err;
-(NSData*)fetchArticleDataForQueryKey:(NSString*)querykey WebEnv:(NSString*)webenv range:(NSRange)range response:(NSURLResponse**)response error:(NSError**)err;
-(NSData*)fetchArticleLinksForQueryKey:(NSString*)querykey WebEnv:(NSString*)webenv command:(NSString*)cmd range:(NSRange)range response:(NSURLResponse**)response error:(NSError**)err;
-(NSData*)fetchRelatedArticlesForIdentifier:(NSString*)identifier response:(NSURLResponse**)response error:(NSError**)err;
-(NSArray*)fetchIdentifiersForQueryString:(NSString*)query;

-(NSArray*)parseInfoData:(NSData*)data QueryKey:(NSString**)querykey WebEnv:(NSString**)webenv count:(NSNumber**)count error:(NSError**)err;
-(NSArray*)parseSummaryData:(NSData*)data error:(NSError**)err;
-(NSArray*)parseArticleData:(NSData*)data error:(NSError**)err;
-(NSArray*)parseLinksData:(NSData*)data error:(NSError**)err;
-(NSArray*)parseRelatedArticleData:(NSData*)data error:(NSError**)err;
-(NSDictionary*)parseArticleNode:(NSXMLElement*)aNode error:(NSError**)err;
-(NSDictionary*)parseSummaryNode:(NSXMLElement*)summary error:(NSError**)err;
-(NSDictionary*)parseLinkNode:(NSXMLElement*)aNode  error:(NSError**)err;
-(NSDictionary*)parseRelatedArticleNode:(NSXMLElement*)aNode error:(NSError**)err;

-(NSCalendarDate*)dateFromDBLPDateNode:(NSXMLElement*)aNode;
-(NSCalendarDate*)dateFromDBLPDateString:(NSString*)str;

-(NSDictionary*)searchTokenForAuthor:(NSDictionary*)author;
-(NSDictionary*)searchTokenForJournal:(NSDictionary*)journal;
-(NSDictionary*)searchTokenForKeyword:(NSDictionary*)keyword;

@end

// here is where the implementation of the plugin starts and where the different
// protocol methods are provided.
@implementation mmDBLPSearchEngine

#pragma mark - 
#pragma mark Init

-(id) init {
    self = [super init];
	if ( self != nil ) {
		// space for early setup
		isSearching = NO;
		shouldContinueSearch = YES;
		// set the caches to nil
		cachedPredefinedSearchTerms = nil;
		cachedSearchFields = nil;
		cachedStopwords = nil;
	}
	return self;    
}

-(void) awakeFromNib {
	// setup nib if necessary, here we initialize the preferences
	NSUserDefaults *prefs = [NSUserDefaults standardUserDefaults];
	if(![prefs objectForKey:@"mm_dblp_itemsPerPage"]) [prefs setObject:[NSNumber numberWithInt:30] forKey:@"mm_dblp_itemsPerPage"];
	if(![prefs objectForKey:@"mm_dblp_shouldAutocomplete"]) [prefs setObject:[NSNumber numberWithBool:NO] forKey:@"mm_dblp_shouldAutocomplete"];
}

-(void) dealloc {
    // cleanup last items here
	// NOTE:most items are cleaned in the performCleanup:method, which is called after each run. 
	// the dealloc method is only called when the plugin is unloaded, which is only when the app quits.
	
	// clear the caches
	[cachedPredefinedSearchTerms release];
	[cachedSearchFields release];
	[cachedStopwords release];
	
    [super dealloc];
}


#pragma mark -
#pragma mark Accessors

// gives you a handle to the delegate object to which you deliver results and notify progress (see above)
// do not retain the delegate
-(id)delegate {
	return delegate;
}

-(void)setDelegate:(id)newDelegate {
	delegate = newDelegate;
}

// number of items that are fetched per batch, default is set by Papers but can be overridden
// internally.
// NOTE:Only applies to the performSearchWithQuery:method
-(NSNumber*)itemsPerPage {
	return (itemsPerPage ? itemsPerPage:[[NSUserDefaults standardUserDefaults]objectForKey:@"mm_dblp_itemsPerPage"]);
}

-(void)setItemsPerPage:(NSNumber*)newItemsPerPage {
	[newItemsPerPage retain];
	[itemsPerPage release];
	itemsPerPage = newItemsPerPage;
}

// the offset we have to start fetching from. This is set by Papers before the search is started 
// and used when the user wishes to get the next page of results. 
// NOTE:Only applies to the performSearchWithQuery:method
-(NSNumber*)itemOffset {
	return itemOffset;
}

-(void)setItemOffset:(NSNumber*)newItemOffset {
	[newItemOffset retain];
	[itemOffset release];
	itemOffset = newItemOffset;
}

// return the number of items found for this query, this is the total number even if you fetch
// only one page
-(NSNumber*)itemsFound {
	return itemsFound;
}

-(void)setItemsFound:(NSNumber*)newItemsFound {
	[newItemsFound retain];
	[itemsFound release];
	itemsFound = newItemsFound;
}

// return the number of items you are about to retrieve (batch size). 
// return the number of items you have retrieved. 
// As long as this value is nil an indeterminate progress bar is shown, the moment you return a non-nil value for both the 
// progress will be shown to the user. use in combination with the delegate method updateStatus:to push changes to the 
// delegate and force an update.
-(NSNumber*)itemsToRetrieve {
	return itemsToRetrieve;
}

-(void)setItemsToRetrieve:(NSNumber*)newItemsToRetrieve {
	[newItemsToRetrieve retain];
	[itemsToRetrieve release];
	itemsToRetrieve = newItemsToRetrieve;
	
	// inform our delegate to update the status
	id <PapersSearchPluginDelegate> del = [self delegate];
	[del updateStatus:self];
}

// here we keep track of what we have retrieved thusfar since we work
// in batches.
-(NSNumber*)retrievedItems {
	return retrievedItems;
}

-(void)setRetrievedItems:(NSNumber*)newRetrievedItems {
	[newRetrievedItems retain];
	[retrievedItems release];
	retrievedItems = newRetrievedItems;
	
	// inform our delegate to update the status
	id <PapersSearchPluginDelegate> del = [self delegate];
	[del updateStatus:self];
}

-(void)incrementRetrievedItemsWith:(int)value{
	int old = [[self retrievedItems]intValue];
	[self setRetrievedItems:[NSNumber numberWithInt:old+value]];
}

// return the current status of your plugin to inform the user. we use it in combination with the delegate 
// method updateStatus:to push changes to the delegate and force an update.
//
// the statusstring is stored here such that the delegate can retrieve it
// when we call [delegate updateStatus]. note that we invoke this method
// automatically when we change the value in the setter.
-(NSString*)statusString {
	return statusString;
}

-(void)setStatusString:(NSString*)newStatusString {
	[newStatusString retain];
	[statusString release];
	statusString = newStatusString;
	
	// inform our delegate to update the status
	id <PapersSearchPluginDelegate> del = [self delegate];
	[del updateStatus:self];
}

// A method to check whether the search finished properly
// and one to get at any errors that resulted. See above for usage of errorCodes.
-(NSError*)searchError {
	return searchError;
}

-(void)setSearchError:(NSError*)newSearchError {
	[newSearchError retain];
	[searchError release];
	searchError = newSearchError;
}


#pragma mark -
#pragma mark Interface interaction methods

// name returns a string which is shown in the source list and used throughout the UI.
// make sure there are no naming collisions with existing plugins and keep the name rather short.
-(NSString*)name {
	return NSLocalizedStringFromTableInBundle(@"DBLP", nil, [NSBundle bundleForClass:[self class]], @"Localized name of the service");
}

// allows to return a color for your plugin, here blue for Pubmed.
// Note:in the plugin test application you can click on the statusbar in the config panel to
// get a color picker that helps you pick a color for the statusbar. The color will be updated and 
// logged into the console so that it can be entered here.
-(NSColor*)color {
	return [NSColor colorWithCalibratedRed:136.0/255.0
									 green:169.0/255.0
									  blue:249.0/255.0
									 alpha:1.0];	
}

// return the logo as will be displayed in the search box. take a look at the sample plugins for examples. Suggested size 250w x 50h.
-(NSImage*)logo {
	NSString *imagepath = [[NSBundle bundleForClass:[self class]] pathForResource:@"logo_dblp" ofType:@"tif"];
	return [[[NSImage alloc]initWithContentsOfFile:imagepath]autorelease];
}

// return an 37w x 31h icon for use in the statusbar (one with the magnifying class)
-(NSImage*)large_icon {
	NSString *imagepath = [[NSBundle bundleForClass:[self class]] pathForResource:@"toolstrip_dblp" ofType:@"tif"];
	return [[[NSImage alloc]initWithContentsOfFile:imagepath]autorelease];
}

// return a 18w x 16 icon for use in the inspector bar (without a magnifying class)
-(NSImage*)small_icon {
	NSString *imagepath = [[NSBundle bundleForClass:[self class]] pathForResource:@"statusbar_dblp" ofType:@"tif"];
	return [[[NSImage alloc]initWithContentsOfFile:imagepath]autorelease];
}

// return a 25w x23h icon for use in the source list (normal setting)
-(NSImage*)sourcelist_icon {
	NSString *imagepath = [[NSBundle bundleForClass:[self class]] pathForResource:@"group_dblp" ofType:@"tif"];
	return [[[NSImage alloc]initWithContentsOfFile:imagepath]autorelease];
}

// return a 20w x 18h icon for use in the source list (small setting)
-(NSImage*)sourcelist_icon_small {
	NSString *imagepath = [[NSBundle bundleForClass:[self class]] pathForResource:@"group_dblp_small" ofType:@"tif"];
	return [[[NSImage alloc]initWithContentsOfFile:imagepath]autorelease];
}

// return the weburl to the homepage of the searchengine/repository
-(NSURL*)info_url {
	return [NSURL URLWithString:@"http://dblp.uni-trier.de/"];
}

// return a unique identifier in the form of a reverse web address of the search engine
-(NSString*)identifier {
	return @"de.uni-trier.dblp";
}

// return whether the search engine requires a subscription
-(BOOL)requiresSubscription {
	return NO;
}

// return NO if you only wish to use this plugin for matching or automatching
// note that you still need to fullfill the PapersSearchPluginProtocol protocol, 
// you can just leave most of its methods empty in that case.
-(BOOL)actsAsGeneralSearchEngine {
	return YES;
}

#pragma mark -
#pragma mark Preferences

// if your plugin needs to be configured you can return here a preference panel. 
// take a look at the example plugin on how to use this.
// Otherwise return nil.
-(NSView*)preferenceView {
	return [preferenceWindow contentView];
}


#pragma mark -
#pragma mark Query Generation

// return a dictionary of predefinedSearchTerms, can be a one or two levels deep.
// the key is the meny item name, if the value is a dictionary it will create a submenu,
// if the value is a string it will be the searchterm that will be filled in upon selection.
//
// Example:
//	<key>Availability</key>
//	<dict>
//		<key>Free Full Text</key>
//		<string>free full text[sb]</string>
//      ...
//	</dict>
//
// Return nil if not applicable      
-(NSDictionary*)predefinedSearchTerms{
	if(!cachedPredefinedSearchTerms){
		NSString *dictpath = [[NSBundle bundleForClass:[self class]] pathForResource:@"DBLPPredefinedTokens" ofType:@"plist"];
		cachedPredefinedSearchTerms = [[NSDictionary alloc]initWithContentsOfFile:dictpath];
	}
	return cachedPredefinedSearchTerms;
}

// return a dictionary of searchfield codes that show up as choices in the searchtokens
// the dictionary should contain an array under key "order" and a dictionary under the key "fields" containing 
// key-value pairs where the key is the name of the field and the value a code that 
// your plugin can translate into the right parameters. We advise to adopt the dblp model of
// field codes.

// Example:
//	<key>order</key>
//	<array>
//		<string>First Author</string>
//		...
//  </array>
//	<key>fields</key>
//	<dict>
//		<key>First Author</key>
//		<string>[1AU]</string>
//      ...
//	</dict>
//
// Return nil if not applicable
-(NSDictionary*)searchFields{
	if(!cachedSearchFields){
		NSString *dictpath = [[NSBundle bundleForClass:[self class]] pathForResource:@"DBLPSearchFields" ofType:@"plist"];
		cachedSearchFields = [[NSDictionary alloc]initWithContentsOfFile:dictpath];
	}
	return cachedSearchFields;
}


#pragma mark -
#pragma mark Autocompletion

#define EBIOLS_BASE      @"http://www.ebi.ac.uk/ontology-lookup/ajax.view?q=termautocomplete&termname=%@&ontologyname="

// NOT YET IMPLEMENTED

// return yes if you wish to autocomplete searchterms
// if you do autocompletion via the internet, be sure to check the server is up!
-(BOOL)autocompletesSearchTerms{
	return [[NSUserDefaults standardUserDefaults]boolForKey:@"mm_dblp_shouldAutocomplete"];
}


// return an array of strings for the partial string, make sure this stuff works fast!
-(NSArray*)autocompletionsForPartialString:(NSString*)str{
	// this is something we should do still, we can use the mesh suggestions done by Pubmed,
	// the mesh browser, and internal plist or we can use EBI's ontology lookup service' Rest API.
	
	// IMPORTANT, SILENTLY FAIL IF THINGS GO WRONG
	
	// let's do some encoding
	NSString* encodedQuery=(NSString*)CFURLCreateStringByAddingPercentEscapes(NULL, (CFStringRef)str, NULL, NULL, kCFStringEncodingUTF8);
	
	NSError *err = nil;
	NSURLResponse *response = nil;
    NSURLRequest *req = [NSURLRequest requestWithURL :[NSURL URLWithString:[NSString stringWithFormat:EBIOLS_BASE, encodedQuery]]];
	NSData *data = [NSURLConnection sendSynchronousRequest:req returningResponse:&response error:&err];
	
	// cleanup
	CFRelease(encodedQuery);
	
	if(err){ 
		NSLog(@"Error while autocompleting:%@", err);
		return [NSArray array];
	}
	
	// transform data into an xml document
	NSXMLDocument *xmlDoc = [[[NSXMLDocument alloc] initWithData:data
														 options:NSXMLNodePreserveCDATA 
														   error:&err]autorelease]; 
	
	if(err){ 
		NSLog(@"Error while autocompleting:%@", err);
		return [NSArray array];
	}
	//NSLog(@"%@", xmlDoc);
	
	// Get info from XML
	NSMutableDictionary *terms = [NSMutableDictionary dictionaryWithCapacity:30];
	
	NSArray *nodes = [[xmlDoc rootDocument] nodesForXPath:@".//name" error:&err];
	id node = nil;
	NSEnumerator *e = [nodes objectEnumerator];
	while(node = [e nextObject]){
		NSString *term = [node stringValue];
		NSArray *components = [term componentsSeparatedByString:@":"];
		term = ([components count] > 1 ? [components objectAtIndex:1] :term);
		// only keep things that start with this
		if([term hasPrefix:str]) [terms setObject:@"term" forKey:term];
	}
	
	// return the results
	return [[terms allKeys]sortedArrayUsingSelector:@selector(caseInsensitiveCompare:)];
}


#pragma mark -
#pragma mark Searching

// a method to make sure everything's set to go before starting, do some setup or tests here if necessary.
// and a method to find out what the problems are if things aren't set. See above for usage of errorCodes.
// for instance return an error when the service is not up.
-(BOOL)readyToPerformSearch {
	// do some setup here if necessary
	shouldContinueSearch = YES;
	[self setSearchError:nil];
	[self setItemsFound:[NSNumber numberWithInt:0]];
	[self setRetrievedItems:[NSNumber numberWithInt:0]];
	return YES;	
}

-(NSError*)searchPreparationError {
	// here we simple return searchError, if something went wrong before we would have set it to a non-nil value.
	return searchError;
}

// used for the history items and saved folders in the
-(NSString*)descriptiveStringForQuery:(NSArray*)tokens {
	if(tokens){
		return [[tokens valueForKey:@"displayString"]componentsJoinedByString:@"+"];
	}
	return @"";
}

// return YES if you support cancelling the current search session (strongly advised).
-(BOOL)canCancelSearch {
	return YES; 
}

// this method is the main worker method and launches the search process, here you are handed over
// the MTQueryTermTokens that were entered in the searchfield. 
// the tokens have the following key-value compliant fields:
//		NSString *token; - The searchterm like the user entered it
//		NSString *field; - The field that was selected
//      NSString *code; - The code that belongs to the selected field
//		NSString *operatorType; - The operator type (AND, NOT, OR)
//		NSNumber *predefined; - A boolean NSNumber that indicates whether the token was predefined.
//
// also you are handed the offset you have to start from, the first time for a new query this will always be 0
// subsequent pages are fetched by calling this method with an offset which represents the last number of the 
// last number of items you returned. So if you fetched the first time 30 papers, the next time the offset will be 30
// for the next page of results. 
// IMPORTANT:try to always sort results on publication date!
//
// NOTE:that this method runs in a separate thread. Signal your progress to the delegate.
-(void)performSearchWithQuery:(NSArray*)tokens {
	
	// Since we run threaded we need the autorelease pool!
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc]init];
	
	// Are we already searching?
	if(isSearching){
		//Warning:CHECK WHAT HAPPENS IF CALLED AGAIN, AND CANCEL PREVIOUS ONE
	}
	// Now we are
	isSearching = YES;
	
	// Generate the query from the tokens
	NSString *currentQuery = [self queryStringFromTokens:tokens prefix:nil];
	if(!currentQuery){
		NSMutableDictionary *userInfo = [NSMutableDictionary dictionary];
		[userInfo setObject:NSLocalizedStringFromTableInBundle(@"Could not create query from searchfield input", nil, [NSBundle bundleForClass:[self class]], @"Error message when query can't be created") forKey:NSLocalizedDescriptionKey];
		[userInfo setObject:NSLocalizedStringFromTableInBundle(@"Please ensure you have created a proper query.", nil, [NSBundle bundleForClass:[self class]], @"Recovery suggestion when query can't be created") forKey:NSLocalizedRecoverySuggestionErrorKey];		
		[self setSearchError:[NSError errorWithDomain:@"DBLPSearchController" code:1 userInfo:userInfo]];
		goto cleanup;
	}
	
	// Inform delegate we're about to start
	id <PapersSearchPluginDelegate> del = [self delegate];
	[del didBeginSearch:self];
	
	[self setStatusString:NSLocalizedStringFromTableInBundle(@"Connecting with DBLP...", nil, [NSBundle bundleForClass:[self class]], @"Status message shown when plugin is connecting to the service")];
	
	////////////////////////////////////////
	// GETTING INITIAL INFO (COUNT + PMIDS)
	////////////////////////////////////////
	
	// Get the info for this query
	NSURLResponse *response = nil;
	NSError *err = nil;
	
	NSData *resultsData = [self fetchInfoForQuery:currentQuery
										   retmax:100				// hardcoded at the moment, be nice with your search engine!
											extra:nil
										 response:&response
											error:&err];
	
	// Check what we got back
	if(err){
		[self setSearchError:err];
		goto cleanup;	
	}
	
	[self setStatusString:NSLocalizedStringFromTableInBundle(@"Connected to DBLP...", nil, [NSBundle bundleForClass:[self class]], @"Status message shown when the plugin has succesfully connected to the service")];
	
	// Parse the info
	NSString *querykey = nil;
	NSString *webenv = nil;
	NSNumber *count = nil;
	
	NSArray *pmids = [self parseInfoData:resultsData QueryKey:&querykey WebEnv:&webenv count:&count error:&err];
	// Check what we got back from the parsing
	if(err){
		[self setSearchError:err];
		goto cleanup;	
	}	
	// Store the number of total articles matching the query
	if(count){
		[self setItemsFound:count];
		[del didFindResults:self];
	}
	// Check whether we got anything at all
	if([pmids count] == 0){
		[self setStatusString:NSLocalizedStringFromTableInBundle(@"No Papers found.", nil, [NSBundle bundleForClass:[self class]], @"Status message shown when no results were found for the query")];
		goto cleanup;	
	}
	
	////////////////////////////////////////
	// FETCHING ACTUAL RESULTS (METADATA)
	////////////////////////////////////////
	
	[self setStatusString:NSLocalizedStringFromTableInBundle(@"Fetching Papers...", nil, [NSBundle bundleForClass:[self class]], @"Status message shown while fetching the metadata for the found papers")];
	
	// We fetch the results (till we have fulfilled the itemsPerPage) in batches of 10 starting from the offset
	// start with offset and the first batch of 10 (unless we have fewer hits of course)
	int batchsize = 10;
	[self setRetrievedItems:[NSNumber numberWithInt:0]];
	[self setItemsToRetrieve:[NSNumber numberWithInt:MIN(batchsize, [count intValue])]];
	NSRange currentBatch = NSMakeRange([[self retrievedItems]intValue], [[self itemsToRetrieve]intValue]); 
	
	while([[self itemsToRetrieve]intValue] > 0){
		
		// update status
		[self setStatusString:[NSString stringWithFormat:NSLocalizedStringFromTableInBundle(@"Fetching Papers %d-%d...", nil, [NSBundle bundleForClass:[self class]], @"Status message shown while fetching the metadata for the specified papers"), 
							   currentBatch.location + 1, NSMaxRange(currentBatch)]];
		
		// check whether we have been cancelled
		if(!shouldContinueSearch){	
			goto cleanup;	
		}
		
		// fetch the next batch
		NSRange current_range = NSMakeRange(currentBatch.location + [[self itemOffset]intValue], currentBatch.length);
		NSData *papersData = [self fetchArticleDataForQueryKey:querykey WebEnv:webenv range:current_range response:&response error:&err];
		// Check what we got back
		if(err){
			[self setSearchError:err];
			goto cleanup;	
		}
		
		// Parse the data
		NSArray *papers = [self parseArticleData:papersData error:&err];
		// Check what we got back from the parsing
		if(err){
			[self setSearchError:err];
			goto cleanup;	
		}	
		// Check whether we got anything at all
		if([papers count] == 0){
			[self setStatusString:NSLocalizedStringFromTableInBundle(@"No Papers found.", nil, [NSBundle bundleForClass:[self class]], @"Status message shown when no results were found for the query")];
			goto cleanup;	
		}
		
		// Hand them to the delegate
		[del didRetrieveObjects:[NSDictionary dictionaryWithObject:papers forKey:@"papers"]];
		
		// Update count + batch
		[self incrementRetrievedItemsWith:[papers count]];
		
		int remaining = [[self itemsFound]intValue] - [[self itemOffset]intValue] - [[self retrievedItems]intValue];
		remaining = MIN([[self itemsPerPage]intValue] - [[self retrievedItems]intValue], remaining);
		
		[self setItemsToRetrieve:[NSNumber numberWithInt:MIN(batchsize, remaining)]];
		//NSLog(@"Retrieved %@ Remaining %d To Retrieve %@", [self retrievedItems], remaining, [self itemsToRetrieve]);
		
		currentBatch = NSMakeRange([[self retrievedItems]intValue], [[self itemsToRetrieve]intValue]); 
	}
	
cleanup:
	
	[self setStatusString:NSLocalizedStringFromTableInBundle(@"Done.", nil, [NSBundle bundleForClass:[self class]], @"Status message shown after all metadata has been retrieved")];
	
	// done, let the delegate know
	del = [self delegate];
	[del didEndSearch:self];
	
	isSearching = NO;
	
	// cleanup nicely
	[pool release];
}


// informs us that we should stop searching. Since we're running in a thread we should check regularly
// if we have been cancelled
-(void)cancelSearch {
	// we simply set the bool that is checked after each batch in the respective query methods
	shouldContinueSearch = NO;
	[self setStatusString:NSLocalizedStringFromTableInBundle(@"Cancelling search...", nil, [NSBundle bundleForClass:[self class]], @"Status message shown while cancelling search.")];
}


#pragma mark -
#pragma mark Saved searches 

// NOT YET IMPLEMENTED IN PAPERS

// when a search is saved it will be regularly updated, only return those results that are new since the given date.
// NOTE that this method runs in a separate thread. Signal your progress to the delegate.
-(void)performSavedSearchWithQuery:(NSArray*)tokens afterDate:(NSDate*)date {
	// currently we simply invoke the whole thing:
	[self performSearchWithQuery:tokens];
	// once we implement this in the future we will make use of Pubmed's reldate parameter
	// we calculate the number of days we go back from the input date, we feed that as an
	// additional parameter into fetchInfoForQuery.
}


#pragma mark -
#pragma mark Related articles 

// return whether your plugin supports the retrieval of related articles or not.
-(BOOL)supportsRelatedArticles {
	return YES;
}

// return related articles in the same way you return search results.
// you will be passed the id as you set it during the search.
// NOTE:that this method runs in a separate thread. Signal your progress to the delegate.
// IMPORTANT:You can optionally add one extra parameter per paper which is a "score" (NSNumber between 0.0 and 1.0).
-(void)getRelatedArticlesForID:(NSString*)identifier {
	
	// Since we run threaded we need the autorelease pool!
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc]init];
	
	// Are we already searching?
	if(isSearching){
		//warning:CHECK WHAT HAPPENS IF CALLED AGAIN, AND CANCEL PREVIOUS ONE
	}
	// Now we are
	isSearching = YES;
	
	// Inform delegate we're about to start
	id <PapersSearchPluginDelegate> del = [self delegate];
	[del didBeginSearch:self];
	
	[self setStatusString:NSLocalizedStringFromTableInBundle(@"Connecting with DBLP...", nil, [NSBundle bundleForClass:[self class]], @"Status message shown when plugin is connecting to the service")];
	
	// Get the info for this query
	NSURLResponse *response = nil;
	NSError *err = nil;
	
	NSData *resultsData = [self fetchRelatedArticlesForIdentifier:identifier 
														 response:&response
															error:&err];
	
	// Check what we got back
	if(err){
		[self setSearchError:err];
		goto cleanup;	
	}
	
	[self setStatusString:NSLocalizedStringFromTableInBundle(@"Connected to DBLP...", nil, [NSBundle bundleForClass:[self class]], @"Status message shown when the plugin has succesfully connected to the service")];
	
	// Get the articles from the xml
	NSArray *related_articles = [self parseRelatedArticleData:resultsData error:&err];
	
	// Check what we got back from the parsing
	if(err){
		[self setSearchError:err];
		goto cleanup;	
	}	
	
	// Store the scores as dictionary for later addback
	NSMutableDictionary *scores = [NSMutableDictionary dictionaryWithCapacity:[related_articles count]];
	NSEnumerator *e = [related_articles objectEnumerator];
	id article;
	while(article = [e nextObject]){
		[scores setObject:[article valueForKey:@"score"] forKey:[article valueForKey:@"identifier"]];
	}
	
	////////////////////////////////////////
	// FETCHING ACTUAL RESULTS (METADATA)
	////////////////////////////////////////
	
	[self setStatusString:NSLocalizedStringFromTableInBundle(@"Fetching related articles...", nil, [NSBundle bundleForClass:[self class]], @"Status string shown while fetching related articles")];
	
	// build query
	NSArray *pmids = [related_articles valueForKey:@"identifier"];
	
	// we use our own itemsPerPage for related articles as we wish to fetch less 
	// and limit to 30 results currently
	int related_itemsPerPage = 30;
	if([pmids count]>related_itemsPerPage) 
		pmids = [pmids subarrayWithRange:NSMakeRange(0,related_itemsPerPage)];
	
	NSString *query = [[pmids componentsJoinedByString:@"[PMID] OR "]stringByAppendingString:@"[PMID]"];
	
	// from here we do the same thing as with a normal search
	// Get the info for this query
	resultsData = [self fetchInfoForQuery:query
								   retmax:related_itemsPerPage
									extra:nil
								 response:&response
									error:&err];
	
	// Check what we got back
	if(err){
		[self setSearchError:err];
		goto cleanup;	
	}
	
	// Parse the info
	NSString *querykey = nil;
	NSString *webenv = nil;
	NSNumber *count = nil;
	
	pmids = [self parseInfoData:resultsData QueryKey:&querykey WebEnv:&webenv count:&count error:&err];
	// Check what we got back from the parsing
	if(err){
		[self setSearchError:err];
		goto cleanup;	
	}	
	// Store the number of total articles matching the query
	if(count){
		[self setItemsFound:count];
		[del didFindResults:self];
	}
	// Check whether we got anything at all
	if([pmids count] == 0){
		[self setStatusString:NSLocalizedStringFromTableInBundle(@"No Papers found.", nil, [NSBundle bundleForClass:[self class]], @"Status message shown when no results were found for the query")];
		goto cleanup;	
	}
	
	// Set the next batch
	// We fetch the results (till we have fulfilled the 30 related_itemsPerPage) in batches of 10
	int related_batchsize = 10;
	// start with 0 and the first batch of 10 (unless we have fewer hits of course)
	[self setRetrievedItems:[NSNumber numberWithInt:0]];
	[self setItemsToRetrieve:[NSNumber numberWithInt:MIN(related_batchsize, [count intValue])]];
	NSRange currentBatch = NSMakeRange([[self retrievedItems]intValue], [[self itemsToRetrieve]intValue]); 
	
	while([[self itemsToRetrieve]intValue] > 0){
		// update status
		[self setStatusString:[NSString stringWithFormat:NSLocalizedStringFromTableInBundle(@"Fetching Papers %d-%d...", nil, [NSBundle bundleForClass:[self class]], @"Status message shown while fetching the metadata for the specified papers"), 
							   currentBatch.location + 1, NSMaxRange(currentBatch)]];
		
		// check whether we have been cancelled
		if(!shouldContinueSearch){	
			goto cleanup;	
		}
		
		// fetch the next batch
		NSData *papersData = [self fetchArticleDataForQueryKey:querykey WebEnv:webenv range:currentBatch response:&response error:&err];
		// Check what we got back
		if(err){
			[self setSearchError:err];
			goto cleanup;	
		}
		
		// Parse the data
		NSArray *papers = [self parseArticleData:papersData error:&err];
		//NSLog(@"%@", [papers valueForKey:@"title"]);
		
		// Check what we got back from the parsing
		if(err){
			[self setSearchError:err];
			goto cleanup;	
		}	
		// Check whether we got anything at all
		if([papers count] == 0){
			[self setStatusString:NSLocalizedStringFromTableInBundle(@"No Papers found.", nil, [NSBundle bundleForClass:[self class]], @"Status message shown when no results were found for the query")];
			goto cleanup;	
		}
		
		// Add back the scores
		NSEnumerator *f = [papers objectEnumerator];
		id paper;
		while(paper = [f nextObject]){
			NSString *pmid = [paper valueForKey:@"identifier"];
			NSString *score = [scores valueForKey:pmid];
			if(score)
				[paper setObject:score forKey:@"score"];
		}
		
		// Hand them to the delegate
		[del didRetrieveObjects:[NSDictionary dictionaryWithObject:papers forKey:@"papers"]];
		
		// Update count + batch
		[self incrementRetrievedItemsWith:[papers count]];
		
		int remaining = related_itemsPerPage - [[self retrievedItems]intValue];
		[self setItemsToRetrieve:[NSNumber numberWithInt:MIN(related_batchsize, remaining)]];
		
		currentBatch = NSMakeRange([[self retrievedItems]intValue], [[self itemsToRetrieve]intValue]); 
	}
	
cleanup:
	
	[self setStatusString:NSLocalizedStringFromTableInBundle(@"Done.", nil, [NSBundle bundleForClass:[self class]], @"Status message shown after all metadata has been retrieved")];
	
	// done, let the delegate know
	del = [self delegate];
	[del didEndSearch:self];
	
	isSearching = NO;
	
	// cleanup nicely
	[pool release];
}


#pragma mark -
#pragma mark Cited by Articles

// return whether your plugin supports the retrieval of articles that cite a particular paper or not.
-(BOOL) supportsCitedByArticles{
	return NO;
}

// return articles that cite a particular paper in the same way you return search results.
// you will be passed the id as you set it during the search.
// NOTE:that this method runs in a separate thread. Signal your progress to the delegate.
-(void) getCitedByArticlesForID:(NSString*)identifier{}


#pragma mark -
#pragma mark Recent Articles

// These methods are used to find recently published articles for authors, journals or keywords
// Like with matching (see below) you can optimize for speed by returning a limited set of fields:
// - ID, Title, Name, Year, Volume, Issue, Pages, Authors, Journal, Publication Date (these are the minimum)
// In addition you can also return two other variables that replace a number of these
// fields which saves you from parsing complicated strings (this will be done anyway once the match is selected by the user:
// - tempAuthorString -> return a string of authors (see dblp example) as a whole instead of all authors separately
// - tempJournalString -> return a single string representing the publication (e.g. "Nature 2005, vol. 16(2) pp. 400-123")
// if you return the latter you don't have to return the individual journal, volume, year, issue, pages fields, those will be ignored

// return recent articles for the provided author
// you will be passed a dictionary representation of the author during the search
// NOTE that this method runs in a separate thread. Signal your progress to the delegate.
-(void)recentArticlesForAuthor:(NSDictionary*)author{
	// Here we simply use the matching routines, we prepare a query by creating a tokenarray ourselves based on the author:
	// Since we run threaded we need the autorelease pool!
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc]init];
	
	NSDictionary *token = [self searchTokenForAuthor:author];
	if(token){
		[self performMatchWithQuery:[NSArray arrayWithObject:token]];
	}
	
	// Cleanup
	[pool release];
}

// return recent articles for the provided journal
// you will be passed a dictionary representation of the journal during the search
// NOTE that this method runs in a separate thread. Signal your progress to the delegate.
-(void)recentArticlesForJournal:(NSDictionary*)journal{
	// Here we simply use the matching routines, we prepare a query by creating a tokenarray ourselves based on the journal:
	// Since we run threaded we need the autorelease pool!
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc]init];
	
	NSDictionary *token = [self searchTokenForJournal:journal];
	if(token){
		[self performMatchWithQuery:[NSArray arrayWithObject:token]];
	}
	
	// Cleanup
	[pool release];
}

// return recent articles for the provided keyword
// you will be passed a dictionary representation of the keyword during the search
// NOTE that this method runs in a separate thread. Signal your progress to the delegate.
-(void)recentArticlesForKeyword:(NSDictionary*)keyword{
	// Here we simply use the matching routines, we prepare a query by creating a tokenarray ourselves based on the keyword:
	// Since we run threaded we need the autorelease pool!
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc]init];
	
	NSDictionary *token = [self searchTokenForKeyword:keyword];
	if(token){
		[self performMatchWithQuery:[NSArray arrayWithObject:token]];
	}
	
	// Cleanup
	[pool release];
}


#pragma mark -
#pragma mark Cleanup methods

// A method to check whether the search finished properly
// and one to get at any errors that resulted. See above for usage of errorCodes.
-(BOOL) successfulCompletion{
	// we simply check whether we caught an error
	return (searchError == nil);
}

-(NSError*)searchCompletionError{
	return searchError;
}

// let the plugin get rid of any data that needs to be reset for a new search.
-(void) performCleanup{
	[itemsPerPage release];
	itemsPerPage = nil;
	
	[itemOffset release];
	itemOffset = nil;
	
	[itemsFound release];
	itemsFound = nil;
	
	[itemsToRetrieve release];
	itemsToRetrieve = nil;
	
	[retrievedItems release];
	retrievedItems = nil;
	
	[statusString release];
	statusString = nil;
	
	[searchError release];
	searchError = nil;
}


#pragma mark -
#pragma mark Metadata lookup methods

// return the metadata for the paper with the given identifier
// you will be passed the id as you set it during the search
// return a dictionary with the standard format of a papers entry and the single 
// paper entry or nil if impossible to resolve
// note that this one is asynchronous and you do not signal progress
// to the delegate
// if you want to run asynchronous use the method below with a single 
// identifier in an array
-(NSDictionary*)metadataForID:(NSString*)identifier{
	
	NSString *query = [identifier stringByAppendingString:@"[PMID]"];
	
	// Get the info for this query
	NSURLResponse *response = nil;
	NSError *err = nil;
	
	NSData *resultsData = [self fetchInfoForQuery:query
										   retmax:1
											extra:nil
										 response:&response
											error:&err];
	
	// Check what we got back
	if(err){
		[self setSearchError:err];
		return nil;	
	}
	
	// Parse the info
	NSString *querykey = nil;
	NSString *webenv = nil;
	NSNumber *count = nil;
	
	NSArray *pmids = [self parseInfoData:resultsData QueryKey:&querykey WebEnv:&webenv count:&count error:&err];
	// Check what we got back from the parsing
	if(err){
		[self setSearchError:err];
		return nil;	
	}	
	
	// Check whether we got anything at all
	if([pmids count] == 0){
		return nil;		
	}
	
	// fetch the actual metadata
	NSData *papersData = [self fetchArticleDataForQueryKey:querykey WebEnv:webenv range:NSMakeRange(0,1) response:&response error:&err];
	// Check what we got back
	if(err){
		[self setSearchError:err];
		return nil;	
	}
	
	// Parse the data
	NSArray *papers = [self parseArticleData:papersData error:&err];
	//NSLog(@"%@", [papers valueForKey:@"title"]);
	// Check what we got back from the parsing
	if(err){
		[self setSearchError:err];
		return nil;	
	}	
	// Check whether we got anything at all
	if([papers count] == 0){
		return nil;	
	}
	
	return [NSDictionary dictionaryWithObject:papers forKey:@"papers"];	
}

// return the metadata for the paper with the given identifier
// you will be passed the id as you set it during the search
// return nil if impossible to resolve
// NOTE that this method runs in a separate thread. Signal your progress to the delegate.
-(void)metadataForIDs:(NSArray*)identifiers{
	
	// Since we run threaded we need the autorelease pool!
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc]init];
	
	// Are we already searching?
	if(isSearching){
		//warning:CHECK WHAT HAPPENS IF CALLED AGAIN, AND CANCEL PREVIOUS ONE
	}
	// Now we are
	isSearching = YES;
	
	// Inform delegate we're about to start
	id <PapersSearchPluginDelegate> del = [self delegate];
	[del didBeginSearch:self];
	
	// Get the info for this query
	NSURLResponse *response = nil;
	NSError *err = nil;
	
	[self setStatusString:NSLocalizedStringFromTableInBundle(@"Fetching metadata...", nil, [NSBundle bundleForClass:[self class]], @"Status message shown while fetching metadata for given articles.")];
	
	// we use our own itemsPerPage as we wish to fetch all identifiers we're given 
	int metadata_itemsPerPage = [identifiers count];
	
	NSString *query = [[identifiers componentsJoinedByString:@"[PMID] OR "]stringByAppendingString:@"[PMID]"];
	
	// from here we do the same thing as with a normal search
	// Get the info for this query
	NSData *resultsData = [self fetchInfoForQuery:query
										   retmax:metadata_itemsPerPage
											extra:nil
										 response:&response
											error:&err];
	
	// Check what we got back
	if(err){
		[self setSearchError:err];
		goto cleanup;	
	}
	
	// Parse the info
	NSString *querykey = nil;
	NSString *webenv = nil;
	NSNumber *count = nil;
	
	NSArray *pmids = [self parseInfoData:resultsData QueryKey:&querykey WebEnv:&webenv count:&count error:&err];
	// Check what we got back from the parsing
	if(err){
		[self setSearchError:err];
		goto cleanup;	
	}	
	// Store the number of total records
	if(count){
		[self setItemsFound:count];
		[del didFindResults:self];
	}
	// Check whether we got anything at all
	if([pmids count] == 0){
		[self setStatusString:NSLocalizedStringFromTableInBundle(@"No Papers found.", nil, [NSBundle bundleForClass:[self class]], @"Status message shown when no results were found for the query")];
		goto cleanup;	
	}
	
	// Set the next batch
	// We fetch the results (till we have fulfilled the metadata_itemsPerPage) in batches of 10
	int related_batchsize = 10;
	// start with 0 and the first batch of 10 (unless we have fewer hits of course)
	[self setRetrievedItems:[NSNumber numberWithInt:0]];
	[self setItemsToRetrieve:[NSNumber numberWithInt:MIN(related_batchsize, [count intValue])]];
	NSRange currentBatch = NSMakeRange([[self retrievedItems]intValue], [[self itemsToRetrieve]intValue]); 
	
	while([[self itemsToRetrieve]intValue] > 0){
		// update status
		[self setStatusString:[NSString stringWithFormat:NSLocalizedStringFromTableInBundle(@"Fetching Papers %d-%d...", nil, [NSBundle bundleForClass:[self class]], @"Status message shown while fetching the metadata for the specified papers"), 
							   currentBatch.location + 1, NSMaxRange(currentBatch)]];
		
		// check whether we have been cancelled
		if(!shouldContinueSearch){	
			goto cleanup;	
		}
		
		// fetch the next batch
		NSData *papersData = [self fetchArticleDataForQueryKey:querykey WebEnv:webenv range:currentBatch response:&response error:&err];
		// Check what we got back
		if(err){
			[self setSearchError:err];
			goto cleanup;	
		}
		
		// Parse the data
		NSArray *papers = [self parseArticleData:papersData error:&err];
		// NSLog(@"%@", [papers valueForKey:@"title"]);
		// Check what we got back from the parsing
		if(err){
			[self setSearchError:err];
			goto cleanup;	
		}	
		// Check whether we got anything at all
		if([papers count] == 0){
			[self setStatusString:NSLocalizedStringFromTableInBundle(@"No Papers found.", nil, [NSBundle bundleForClass:[self class]], @"Status message shown when no results were found for the query")];
			goto cleanup;	
		}
		
		// Hand them to the delegate
		[del didRetrieveObjects:[NSDictionary dictionaryWithObject:papers forKey:@"papers"]];
		
		// Update count + batch
		[self incrementRetrievedItemsWith:[papers count]];
		
		int remaining = metadata_itemsPerPage - [[self retrievedItems]intValue];
		[self setItemsToRetrieve:[NSNumber numberWithInt:MIN(related_batchsize, remaining)]];
		
		currentBatch = NSMakeRange([[self retrievedItems]intValue], [[self itemsToRetrieve]intValue]); 
	}
	
cleanup:
	
	[self setStatusString:NSLocalizedStringFromTableInBundle(@"Done.", nil, [NSBundle bundleForClass:[self class]], @"Status message shown after all metadata has been retrieved")];
	
	// done, let the delegate know
	del = [self delegate];
	[del didEndSearch:self];
	
	isSearching = NO;
	
	// cleanup nicely
	[pool release];
}



#pragma mark -
#pragma mark Follow up methods

#define PUBMED_URL		@"http://www.ncbi.nlm.nih.gov/sites/entrez?Db=dblp&Cmd=ShowDetailView&TermToSearch=%@"
#define ELINK_URL		@"http://eutils.ncbi.nlm.nih.gov/entrez/eutils/elink.fcgi?dbfrom=dblp&id=%@&retmode=ref&cmd=prlinks"

// return the URL to the paper within the repository
// you will be passed the id as you set it during the search
// return nil if impossible to resolve
-(NSURL*)repositoryURLForID:(NSString*)identifier{
	// simply return a link to the webpage using the pmid
	NSString *link = [NSString stringWithFormat:PUBMED_URL, identifier];
	return [NSURL URLWithString:link];
}

// return the URL to the paper at the publisher's website, preferably fulltext
// you will be passed the id as you set it during the search
// return nil if impossible to resolve
-(NSURL*)publisherURLForID:(NSString*)identifier{
	// we make use of dblp's elink eutil
	// alternatively we could use the fetchLinks method and inspect the links in more detail (note to self, check to what extend we could offer university library support through that, in combination with a preference)
	NSString *link = [NSString stringWithFormat:ELINK_URL, identifier];
	return [NSURL URLWithString:link];
}

// return the URL to the PDF ofthe paper
// you will be passed the id as you set it during the search
// return nil if impossible to resolve
// IMPORTANT:if you return nil Papers will do its best to automatically retrieve the PDF on the basis of 
// the publisherURLForID as returned above. ONLY return a link for a PDF here if a) you are sure you
// know the location or b) you think you can do some fancy lookup that outperforms Papers build in attempts.
-(NSURL*)pdfURLForID:(NSString*)identifier{
	// dblp does not give direct links so we'll let Papers try.	
	return nil;
}



/////////////////////////////////////////////////////////
#pragma mark -
#pragma mark Matching methods
/////////////////////////////////////////////////////////

// return the logo as will be displayed in the search box (this one is smaller than that for the search engine). 
// take a look at the sample plugins for examples. Suggested size 115w x 40h
-(NSImage*)small_logo{
	NSString *imagepath = [[NSBundle bundleForClass:[self class]] pathForResource:@"logo_dblp_basic" ofType:@"tif"];
	return [[[NSImage alloc]initWithContentsOfFile:imagepath]autorelease];
}

// this method is the main worker method and launches the search process for matches.
// there's no difference with the performSearchWithQuery method above (you could use the same one),
// except that you can optimize for speed by returning a limited set of fields:
// - ID, Title, Name, Year, Volume, Issue, Pages, Authors, Journal, Publication Date (these are the minimum)
//
// In addition there a unique situation here that you can also return two other variable that replace a number of these
// fields which saves you from parsing complicated strings (this will be done anyway once the match is selected by the user:
// - tempAuthorString -> return a string of authors (see dblp example) as a whole instead of all authors separately
// - tempJournalString -> return a single string representing the publication (e.g. "Nature 2005, vol. 16(2) pp. 400-123")
// if you return the latter you don't have to return the individual journal, volume, year, issue, pages fields, those will be ignored
//
// NOTE that this method runs in a separate thread. Signal your progress to the delegate.
// use the search protocols delegate methods
-(void) performMatchWithQuery:(NSArray*)tokens{
	
	// this closely follows the general performSearchWithQuery:except that we use the faster retrieval of summary (skipping things like
	// the abstract, and we only fetch a single batch of results.
	
	// Since we run threaded we need the autorelease pool!
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc]init];
	// Are we already searching?
	if(isSearching){
		//Warning:CHECK WHAT HAPPENS IF CALLED AGAIN, AND CANCEL PREVIOUS ONE
	}
	// Now we are
	isSearching = YES;
	
	// Generate the query from the tokens
	NSString *currentQuery = [self queryStringFromTokens:tokens prefix:nil];
	
	if(!currentQuery){
		NSMutableDictionary *userInfo = [NSMutableDictionary dictionary];
		[userInfo setObject:NSLocalizedStringFromTableInBundle(@"Could not create query from searchfield input", nil, [NSBundle bundleForClass:[self class]], @"Error message when query can't be created") forKey:NSLocalizedDescriptionKey];
		[userInfo setObject:NSLocalizedStringFromTableInBundle(@"Please ensure you have created a proper query.", nil, [NSBundle bundleForClass:[self class]], @"Recovery suggestion when query can't be created") forKey:NSLocalizedRecoverySuggestionErrorKey];		
		[self setSearchError:[NSError errorWithDomain:@"DBLPSearchController" code:1 userInfo:userInfo]];
		goto cleanup;
	}
	
	// Inform delegate we're about to start
	id <PapersSearchPluginDelegate> del = [self delegate];
	[del didBeginSearch:self];
	
	[self setStatusString:NSLocalizedStringFromTableInBundle(@"Connecting with DBLP...", nil, [NSBundle bundleForClass:[self class]], @"Status message shown when plugin is connecting to the service")];
	
	////////////////////////////////////////
	// GETTING INITIAL INFO (COUNT + PMIDS)
	////////////////////////////////////////
	
	// Get the info for this query
	NSURLResponse *response = nil;
	NSError *err = nil;
	
	NSData *resultsData = [self fetchInfoForQuery:currentQuery
										   retmax:[[[NSUserDefaults standardUserDefaults]objectForKey:@"mm_dblp_itemsPerPage"]intValue]		
											extra:nil
										 response:&response
											error:&err];
	
	// Check what we got back
	if(err){
		[self setSearchError:err];
		goto cleanup;	
	}
	
	[self setStatusString:NSLocalizedStringFromTableInBundle(@"Connected to DBLP...", nil, [NSBundle bundleForClass:[self class]], @"Status message shown when the plugin has succesfully connected to the service")];
	
	// Parse the info
	NSString *querykey = nil;
	NSString *webenv = nil;
	NSNumber *count = nil;
	
	NSArray *pmids = [self parseInfoData:resultsData QueryKey:&querykey WebEnv:&webenv count:&count error:&err];
	// Check what we got back from the parsing
	if(err){
		[self setSearchError:err];
		goto cleanup;	
	}	
	// Store the number of total articles matching the query
	if(count){
		[self setItemsFound:count];
		[del didFindResults:self];
	}
	// Check whether we got anything at all
	if([pmids count] == 0){
		[self setStatusString:NSLocalizedStringFromTableInBundle(@"No Papers found.", nil, [NSBundle bundleForClass:[self class]], @"Status message shown when no results were found for the query")];
		goto cleanup;	
	}
	
	// check whether we have been cancelled
	if(!shouldContinueSearch){	
		goto cleanup;	
	}
	
	////////////////////////////////////////
	// FETCHING ACTUAL RESULTS (METADATA SUMMARIES)
	////////////////////////////////////////
	
	[self setStatusString:NSLocalizedStringFromTableInBundle(@"Fetching Papers...", nil, [NSBundle bundleForClass:[self class]], @"Status message shown while fetching the metadata for the found papers")];
	
	// We fetch the summaries
	[self setRetrievedItems:[NSNumber numberWithInt:0]];
	[self setItemsToRetrieve:[self itemsPerPage]];
	NSRange currentBatch = NSMakeRange([[self retrievedItems]intValue], [[self itemsToRetrieve]intValue]); 
	
	NSData *summaryData = [self fetchArticleSummaryForQueryKey:querykey WebEnv:webenv range:currentBatch response:&response error:&err];
	// Check what we got back
	if(err){
		[self setSearchError:err];
		goto cleanup;	
	}
	
	// Parse the data
	NSArray *papers = [self parseSummaryData:summaryData error:&err];
	// Check what we got back from the parsing
	if(err){
		[self setSearchError:err];
		goto cleanup;	
	}	
	// Check whether we got anything at all
	if([papers count] == 0){
		[self setStatusString:NSLocalizedStringFromTableInBundle(@"No Papers found.", nil, [NSBundle bundleForClass:[self class]], @"Status message shown when no results were found for the query")];
		goto cleanup;	
	}
	// Hand them to the delegate
	[del didRetrieveObjects:[NSDictionary dictionaryWithObject:papers forKey:@"papers"]];
	
	// Update count + batch
	[self incrementRetrievedItemsWith:[papers count]];
	
cleanup:
	
	[self setStatusString:NSLocalizedStringFromTableInBundle(@"Done.", nil, [NSBundle bundleForClass:[self class]], @"Status message shown after all metadata has been retrieved")];
	
	// done, let the delegate know
	del = [self delegate];
	[del didEndSearch:self];
	
	isSearching = NO;
	
	// cleanup nicely
	[pool release];
}

// this method is called when the user has selected the right paper, you will be passed the identifier (as you set it
// during the initial search, and you have to return the full metadata for the paper (as rich as possible).
// return the usual dictionary with a papers array containing a SINGLE entry or nil if the identifier cannot be resolved.
// NOTE that this method runs in a separate thread. Signal your progress to the delegate.
// use the above delegate methods
-(void) performMatchForID:(NSString*)identifier{
	// Since we run threaded we need the autorelease pool!
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc]init];
	
	// This is the same as the metadataForIds method, we use that one
	[self metadataForIDs:[NSArray arrayWithObject:identifier]];
	
	[pool release];
}


/////////////////////////////////////////////////////////
#pragma mark -
#pragma mark Auto Matching methods
/////////////////////////////////////////////////////////

// this method is called when the user wishes to auto match a paper. You will be handed all available
// metadata (including the link to the PDF file if present) in the above described dictionary format.
// it's your task to return one or more (preferably fewer than 5) possible hits. Return nothing if you
// can't find anything. 
// NOTE that in the current implementation it's likely we ignore the results if you return more than 1 hit.
// NOTE that this method runs in a separate thread. Signal your progress to the delegate.
// use the above delegate methods
-(void) performAutoMatchForPaper:(NSDictionary*)paper{
	
	// Since we run threaded we need the autorelease pool!
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc]init];
	
	NSString *pmid = nil;
	
	// Inform delegate we're about to start
	id <PapersSearchPluginDelegate> del = [self delegate];
	[del didBeginSearch:self];
	
	// we build in delays of 2s to prevent overloading of dblp
	BOOL secondRun = NO;
	
	// Do we have a pmid?
	// NSLog(@"Checking PMID...");
	if([paper valueForKey:@"identifier"]){
		[self setStatusString:NSLocalizedStringFromTableInBundle(@"Checking PMID...", nil, [NSBundle bundleForClass:[self class]], @"Status message shown when plugin is checking the automatch option PMID")];
		NSArray *ids = [self fetchIdentifiersForQueryString:[NSString stringWithFormat:@"%@[PMID]", [paper valueForKey:@"identifier"]]];
		if([ids count] == 1){
			pmid = [ids lastObject];
			goto success;
		}
		secondRun = YES;
		NSLog(@"Found %d candidates", [ids count]);
	}
	
	// Do we have a doi?
	// NSLog(@"Checking DOI...");
	if([paper valueForKey:@"doi"]){
		[self setStatusString:NSLocalizedStringFromTableInBundle(@"Checking DOI...", nil, [NSBundle bundleForClass:[self class]], @"Status message shown when plugin is checking the automatch option DOI")];
		// wait if we already did a search
		if(secondRun) [NSThread sleepUntilDate:[NSDate dateWithTimeIntervalSinceNow:2]];
		// continue
		NSArray *ids = [self fetchIdentifiersForQueryString:[NSString stringWithFormat:@"\"%@\"[DOI]", [paper valueForKey:@"doi"]]];
		if([ids count] == 1){
			pmid = [ids lastObject];
			goto success;
		}
		secondRun = YES;
		NSLog(@"Found %d candidates", [ids count]);
	}
	
	/* UNDER CONSTRUCTION */
	/*
	 // 4 do we find a unique date volume issue combination?
	 NSLog(@"Checking Publication...");
	 if([paper valueForKey:@"volume"] && [paper valueForKey:@"pages"] && [paper valueForKey:@"year"]){
	 [self setStatusString:NSLocalizedStringFromTableInBundle(@"Checking Publication...", nil, [NSBundle bundleForClass:[self class]], @"Status message shown when plugin is checking the automatch option Publication")];
	 
	 
	 // wait if we already did a search
	 if(secondRun) [NSThread sleepUntilDate:[NSDate dateWithTimeIntervalSinceNow:2]];
	 // continue
	 NSArray *ids = [self fetchIdentifiersForQueryString:[NSString stringWithFormat:@"\"%@\"[DOI]", [paper valueForKey:@"doi"]]];
	 if([ids count] == 1){
	 pmid = [ids lastObject];
	 goto success;
	 }
	 secondRun = YES;
	 NSLog(@"Found %d candidates", [ids count]);		
	 }
	 
	 // Do we have a title
	 NSLog(@"Checking Title...");
	 if([paper valueForKey:@"title"]){
	 [self setStatusString:NSLocalizedStringFromTableInBundle(@"Checking Title...", nil, [NSBundle bundleForClass:[self class]], @"Status message shown when plugin is checking the automatch option Title")];
	 
	 // 3a do we have a pmid in the title?
	 
	 // 3b do we have a doi in the title?
	 
	 // 3c do we have a single entry for the full title?
	 
	 // 3d do we have a single entry for the first 5 words of title?
	 
	 // wait if we already did a search
	 if(secondRun) [NSThread sleepUntilDate:[NSDate dateWithTimeIntervalSinceNow:2]];
	 // continue
	 NSArray *ids = [self fetchIdentifiersForQueryString:[NSString stringWithFormat:@"\"%@\"[DOI]", [paper valueForKey:@"doi"]]];
	 if([ids count] == 1){
	 pmid = [ids lastObject];
	 goto success;
	 }
	 secondRun = YES;
	 NSLog(@"Found %d candidates", [ids count]);		
	 }
	 
	 // Do we have a unique set of authors
	 NSLog(@"Checking Authors...");
	 if([paper valueForKey:@"authors"]){
	 [self setStatusString:NSLocalizedStringFromTableInBundle(@"Checking Authors...", nil, [NSBundle bundleForClass:[self class]], @"Status message shown when plugin is checking the automatch option Authors")];
	 
	 // wait if we already did a search
	 if(secondRun) [NSThread sleepUntilDate:[NSDate dateWithTimeIntervalSinceNow:2]];
	 // continue
	 NSArray *ids = [self fetchIdentifiersForQueryString:[NSString stringWithFormat:@"\"%@\"[DOI]", [paper valueForKey:@"doi"]]];
	 if([ids count] == 1){
	 pmid = [ids lastObject];
	 goto success;
	 }
	 secondRun = YES;
	 NSLog(@"Found %d candidates", [ids count]);		
	 }
	 
	 
	 // Do we find a pmid or doi in the PDF?
	 NSLog(@"Checking PDF...");
	 if([paper valueForKey:@"path"]){
	 [self setStatusString:NSLocalizedStringFromTableInBundle(@"Checking PDF...", nil, [NSBundle bundleForClass:[self class]], @"Status message shown when plugin is checking the automatch option PDF")];
	 
	 
	 // wait if we already did a search
	 if(secondRun) [NSThread sleepUntilDate:[NSDate dateWithTimeIntervalSinceNow:2]];
	 // continue
	 NSArray *ids = [self fetchIdentifiersForQueryString:[NSString stringWithFormat:@"\"%@\"[DOI]", [paper valueForKey:@"doi"]]];
	 if([ids count] == 1){
	 pmid = [ids lastObject];
	 goto success;
	 }
	 secondRun = YES;
	 NSLog(@"Found %d candidates", [ids count]);		
	 }	
	 */
	
success:
	// send the result over (if we found one), skipping the other options
	if(pmid){
		// get the metadata
		NSDictionary *metadata = [self metadataForID:pmid];
		if(metadata){
			// Hand them to the delegate in the usual format
			[del didRetrieveObjects:[NSDictionary dictionaryWithObject:[NSArray arrayWithObject:metadata] forKey:@"papers"]];
		}
	}
	
	[self setStatusString:NSLocalizedStringFromTableInBundle(@"Done.", nil, [NSBundle bundleForClass:[self class]], @"Status message shown after all metadata has been retrieved")];
	
	// done, let the delegate know
	del = [self delegate];
	[del didEndSearch:self];
	
	isSearching = NO;
	
	[pool release];
	
}

@end



/////////////////////////////////////////////////////////
#pragma mark -
// these are methods that are specific to this plugin and 
// are not required per se by the plugin protocol
/////////////////////////////////////////////////////////


@implementation mmDBLPSearchEngine (dblp_methods)

/////////////////////////////////////////////////////////
#pragma mark Query Methods
/////////////////////////////////////////////////////////

// this method provides us with a list of stopwords that are filtered from the query
// this list is derived from the dblp handbook
-(NSArray*)stopwords{
	if(!cachedStopwords){
		NSString *arraypath = [[NSBundle bundleForClass:[self class]] pathForResource:@"DBLPStopWords" ofType:@"plist"];
		cachedStopwords = [[NSArray alloc]initWithContentsOfFile:arraypath];
	}
	return cachedStopwords;
}

// this method converts the raw MTSearchToken objects as we get them from the search field into a 
// query string
-(NSString*)queryStringFromTokens:(NSArray*)tokens 
						   prefix:(NSString*)prefix{
	
	NSMutableString *the_query = [NSMutableString stringWithCapacity:1024];
	
	// some queries require a prefix, set it if provided
	if(prefix)
		[the_query appendString:prefix];
	
	// iterate over the tokens to generate the querystring
	NSEnumerator *e = [tokens objectEnumerator];
	id token;
	BOOL first = YES;
	while(token = [e nextObject]){
		
		// get token and filter on illegal characters
		NSString *rawtoken = [token valueForKey:@"token"];
		NSString *rawcode = [token valueForKey:@"code"];
		NSString *filteredToken = [rawtoken filteredDBLPQuery];
		
		// the first one doesn't need the AND or OR operator
		if(!first){
			[the_query appendFormat:@"%@ ", [token valueForKey:@"operatorCode"]];
		}
		// check if it could be a single PMID
		else if([tokens count] == 1){
			if([rawcode isEqualToString:@"[ALL]"]){
				int nr = [rawtoken intValue];
				if(nr > 10000 && nr < INT_MAX) rawcode = @"[PMID]";
			}
		}
		
		// special cases, authors and DOI shouldn't be filtered on illegal stopwords and/or stopwords
		if([rawcode isEqualToString:@"[AU]"] || [rawcode isEqualToString:@"[1AU]"] || [rawcode isEqualToString:@"[LASTAU]"]){
			[the_query appendString:filteredToken];
			[the_query appendString:rawcode];
		}
		else if([[token valueForKey:@"field"]isEqualToString:@"DOI"]){
			[the_query appendString:rawtoken];
		}
		else {
			NSMutableArray *tokenwords = [NSMutableArray arrayWithCapacity:30];
			NSArray *stopwords = [self stopwords];
			NSString *word;
			NSEnumerator *e = [[filteredToken componentsSeparatedByString:@" "] objectEnumerator];
			while(word = [e nextObject]){
				// filter individual words on stopwords
				if(stopwords && ![stopwords containsObject:[word lowercaseString]]){
					[tokenwords addObject:word];
				}
				else {
					//NSLog(@"Found stopword:%@", word);
				}
			}
			// bundle this token as one using brackets
			if([tokenwords count]>1)[the_query appendString:@"("];
			
			[the_query appendString:[tokenwords componentsJoinedByString:[NSString stringWithFormat:@"%@ AND ", rawcode]]];
			[the_query appendString:rawcode];
			
			if([tokenwords count]>1)[the_query appendString:[NSString stringWithFormat:@" OR %@ %@) ", filteredToken, rawcode]];
		}
		//NSLog(@"Query:%@", the_query);
		first = NO;
	}
	return the_query;
}



/////////////////////////////////////////////////////////
#pragma mark Fetching
/////////////////////////////////////////////////////////

#define EUTILS_BASE      @"http://eutils.ncbi.nlm.nih.gov"
#define EUTILS_URL		 @"/entrez/eutils"
#define EUTILS_DB_NAME   @"dblp"
#define EUTILS_FILE_TYPE @"xml"

// this is the base URL for the dblp service
-(NSString*)eUtilsBaseURL{	
	return [NSString stringWithFormat:@"%@%@", EUTILS_BASE, EUTILS_URL];
}

// this method is always the first step in a search and synchronously gets the relevant PMIDs for the query
// we make use of the esearch utility. The results are then passed back as raw data.
-(NSData*)fetchInfoForQuery:(NSString*)query 
					 retmax:(int)max
					  extra:(NSString*)additional_terms 
				   response:(NSURLResponse**)response
					  error:(NSError**)err
{
	NSMutableString* esearch = [NSMutableString stringWithString:[self eUtilsBaseURL]];
    [esearch appendFormat:@"/esearch.fcgi?db=%@", EUTILS_DB_NAME];
	[esearch appendFormat:@"&retmax=%d", max];
	[esearch appendString:@"&usehistory=y"];						//use history so we get a webenv
	[esearch appendString:@"&sort=pub+date"];						//order on publication date
	[esearch appendString:@"&tool=com.mekentosj.papers"];			//send our id
	if(additional_terms) [esearch appendString:additional_terms];	//add additional terms if provided
	[esearch appendFormat:@"&term=%@", query];
	
	// encode the query to prevent problems
 	NSString* encodedQuery=(NSString*)CFURLCreateStringByAddingPercentEscapes(NULL, (CFStringRef)esearch, NULL, NULL, kCFStringEncodingUTF8);
	
	// since we're already in a thread we run synchronously	
    NSURLRequest *req = [NSURLRequest requestWithURL :[NSURL URLWithString:encodedQuery]];
	NSData *data = [NSURLConnection sendSynchronousRequest:req returningResponse:response error:err];
	if(*err) NSLog(@"Error while performing eInfo request:%@", *err);
	
	// cleanup
	CFRelease(encodedQuery);
	
	return data;
}


// this method takes the acquired history items and fetches the article summary info for a range of articles.
// we make use of the esummary utility. The results are then passed back as raw data.
-(NSData*)fetchArticleSummaryForQueryKey:(NSString*)querykey 
								  WebEnv:(NSString*)webenv
								   range:(NSRange)range
								response:(NSURLResponse**)response
								   error:(NSError**)err
{
	NSMutableString* esummary = [NSMutableString stringWithString:[self eUtilsBaseURL]];
	[esummary appendFormat:@"/esummary.fcgi?rettype=%@", EUTILS_FILE_TYPE];
	[esummary appendFormat:@"&retmode=xml&db=%@", EUTILS_DB_NAME];
	[esummary appendFormat:@"&retstart=%d", range.location];
	[esummary appendFormat:@"&retmax=%d", range.length];
	[esummary appendFormat:@"&query_key=%@", querykey];
	[esummary appendFormat:@"&WebEnv=%@", webenv];
	[esummary appendString:@"&sort=pub+date"];						
	[esummary appendString:@"&tool=com.mekentosj.papers"];
	
	if(!querykey || !webenv){
		// warn the user something has gone wrong
		NSMutableDictionary *userInfo = [NSMutableDictionary dictionary];
		[userInfo setObject:NSLocalizedStringFromTableInBundle(@"Could not fetch info for query key (missing parameters)", nil, [NSBundle bundleForClass:[self class]], @"Error message when info cannot be fetched") forKey:NSLocalizedDescriptionKey];
		[userInfo setObject:NSLocalizedStringFromTableInBundle(@"Please try again.", nil, [NSBundle bundleForClass:[self class]], @"Recovery suggestion indicating to try the previous operation again") forKey:NSLocalizedRecoverySuggestionErrorKey];		
		*err = [NSError errorWithDomain:@"DBLPSearchController" code:1 userInfo:userInfo];
		return nil;
	}
	
	// since we're already in a thread we run synchronously	
	NSURLRequest *req = [NSURLRequest requestWithURL :[NSURL URLWithString:esummary]];
	NSData *data = [NSURLConnection sendSynchronousRequest:req returningResponse:response error:err];
	if(*err)	NSLog(@"Error while performing esummary request:%@", *err);
	return data;
}


// this method takes the acquired history items and fetches the complete article info for a range of articles.
// we make use of the efetch utility. The results are then passed back as raw data.
-(NSData*)fetchArticleDataForQueryKey:(NSString*)querykey 
							   WebEnv:(NSString*)webenv
								range:(NSRange)range
							 response:(NSURLResponse**)response
								error:(NSError**)err
{
	NSMutableString* efetch = [NSMutableString stringWithString:[self eUtilsBaseURL]];
    [efetch appendFormat:@"/efetch.fcgi?rettype=%@", EUTILS_FILE_TYPE];
    [efetch appendFormat:@"&retmode=xml&db=%@", EUTILS_DB_NAME];
	[efetch appendFormat:@"&retstart=%d", range.location];
	[efetch appendFormat:@"&retmax=%d", range.length];	
    [efetch appendFormat:@"&query_key=%@", querykey];
    [efetch appendFormat:@"&WebEnv=%@", webenv];
	[efetch appendString:@"&sort=pub+date"];						
	[efetch appendString:@"&tool=com.mekentosj.papers"];
	
	if(!querykey || !webenv){
		// warn the user something has gone wrong
		NSMutableDictionary *userInfo = [NSMutableDictionary dictionary];
		[userInfo setObject:NSLocalizedStringFromTableInBundle(@"Could not fetch data for query key (missing parameters)", nil, [NSBundle bundleForClass:[self class]], @"Error message when data cannot be fetched") forKey:NSLocalizedDescriptionKey];
		[userInfo setObject:NSLocalizedStringFromTableInBundle(@"Please try again.", nil, [NSBundle bundleForClass:[self class]], @"Recovery suggestion indicating to try the previous operation again") forKey:NSLocalizedRecoverySuggestionErrorKey];		
		*err = [NSError errorWithDomain:@"DBLPSearchController" code:1 userInfo:userInfo];
		return nil;
	}
	
	// since we're already in a thread we run synchronously	
	NSURLRequest *req = [NSURLRequest requestWithURL :[NSURL URLWithString:efetch]];
	NSData *data = [NSURLConnection sendSynchronousRequest:req returningResponse:response error:err];
	if(*err)	NSLog(@"Error while performing efetch request:%@", *err);
	return data;
}


// this method takes the acquired history items and fetches the links to an article for a range of articles.
// we make use of the elink utility. The results are then passed back as raw data.
-(NSData*)fetchArticleLinksForQueryKey:(NSString*)querykey 
								WebEnv:(NSString*)webenv 
							   command:(NSString*)cmd
								 range:(NSRange)range
							  response:(NSURLResponse**)response
								 error:(NSError**)err

{	
	NSMutableString* elink = [NSMutableString stringWithString:[self eUtilsBaseURL]];
    [elink appendFormat:@"/elink.fcgi?rettype=%@", EUTILS_FILE_TYPE];
    [elink appendFormat:@"&retmode=xml&db=%@", EUTILS_DB_NAME];
	[elink appendFormat:@"&retstart=%d", range.location];
	[elink appendFormat:@"&retmax=%d", range.length];	
    [elink appendFormat:@"&query_key=%@", querykey];
    [elink appendFormat:@"&WebEnv=%@", webenv];
	[elink appendFormat:@"&cmd=%@", cmd];
	[elink appendString:@"&tool=com.mekentosj.papers"];
	
	if(!querykey || !webenv){
		// warn the user something has gone wrong
		NSMutableDictionary *userInfo = [NSMutableDictionary dictionary];
		[userInfo setObject:NSLocalizedStringFromTableInBundle(@"Could not fetch links for query key (missing parameters)", nil, [NSBundle bundleForClass:[self class]], @"Error message when links cannot be fetched") forKey:NSLocalizedDescriptionKey];
		[userInfo setObject:NSLocalizedStringFromTableInBundle(@"Please try again.", nil, [NSBundle bundleForClass:[self class]], @"Recovery suggestion indicating to try the previous operation again") forKey:NSLocalizedRecoverySuggestionErrorKey];		
		*err = [NSError errorWithDomain:@"DBLPSearchController" code:1 userInfo:userInfo];
		return nil;
	}
	
	// since we're already in a thread we run synchronously	
	NSURLRequest *req = [NSURLRequest requestWithURL :[NSURL URLWithString:elink]];
	NSData *data = [NSURLConnection sendSynchronousRequest:req returningResponse:response error:err];
	if(*err) NSLog(@"Error while performing eLink request:%@", *err);
	return data;
}

// this method is gets the related article IDs given an identifier. 
// the results are then passed back as raw data.
-(NSData*)fetchRelatedArticlesForIdentifier:(NSString*)identifier 
								   response:(NSURLResponse**)response
									  error:(NSError**)err
{
	NSMutableString* elink = [NSMutableString stringWithString:[self eUtilsBaseURL]];
    [elink appendFormat:@"/elink.fcgi?dbfrom=%@", EUTILS_DB_NAME];
    [elink appendFormat:@"&cmd=neighbor_score&id=%@", identifier];
	[elink appendString:@"&tool=com.mekentosj.papers"];
	// encode the query to prevent problems
 	NSString* encodedQuery=(NSString*)CFURLCreateStringByAddingPercentEscapes(NULL, (CFStringRef)elink, NULL, NULL, kCFStringEncodingUTF8);
	
	// since we're already in a thread we run synchronously	
    NSURLRequest *req = [NSURLRequest requestWithURL :[NSURL URLWithString:encodedQuery]];
	NSData *data = [NSURLConnection sendSynchronousRequest:req returningResponse:response error:err];
	
	if(*err) NSLog(@"Error while performing eLink related articles request:%@", *err);
	
	// cleanup
	CFRelease(encodedQuery);
	
	return data;
}


// this helper method does nothing else than getting the results for given query. If we do find only one
// it's likely it's the paper and we return metadata for ID.
-(NSArray*)fetchIdentifiersForQueryString:(NSString*)query{
	
	// Get the info for this query
	NSURLResponse *response = nil;
	NSError *err = nil;
	
	NSData *resultsData = [self fetchInfoForQuery:query
										   retmax:5		// return maximum of 5, not 1 otherwise checks above are always positive
											extra:nil
										 response:&response
											error:&err];
	
	// Check what we got back
	if(err){
		[self setSearchError:err];
		return [NSArray array];	
	}
	
	// Parse the info
	NSString *querykey = nil;
	NSString *webenv = nil;
	NSNumber *count = nil;
	
	NSArray *pmids = [self parseInfoData:resultsData QueryKey:&querykey WebEnv:&webenv count:&count error:&err];
	// Check what we got back from the parsing
	if(err){
		[self setSearchError:err];
		return [NSArray array];	
	}	
	
	return pmids;
}



/////////////////////////////////////////////////////////
#pragma mark Parsing
/////////////////////////////////////////////////////////

// this method parses the raw response data of a fetchInfoForQuery:
// it generates the xml and gets the result, returning an array of PMIDs. 
// it also fills in the querykey, webenv, range parameters
-(NSArray*)parseInfoData:(NSData*)data
				QueryKey:(NSString**)querykey 
				  WebEnv:(NSString**)webenv 
				   count:(NSNumber**)count
				   error:(NSError**)err
{
	// transform data into an xml document
	NSXMLDocument *xmlDoc = [[[NSXMLDocument alloc] initWithData:data
														 options:NSXMLNodePreserveCDATA 
														   error:err]autorelease]; 
	
	if(*err){
		// warn the user that xml file could not be created
		NSMutableDictionary *userInfo = [NSMutableDictionary dictionary];
		[userInfo setObject:NSLocalizedStringFromTableInBundle(@"Error parsing XML data.", nil, [NSBundle bundleForClass:[self class]], @"Error message when XML data cannot be parsed") forKey:NSLocalizedDescriptionKey];
		[userInfo setObject:NSLocalizedStringFromTableInBundle(@"Please try again.", nil, [NSBundle bundleForClass:[self class]], @"Recovery suggestion indicating to try the previous operation again") forKey:NSLocalizedRecoverySuggestionErrorKey];		
		*err = [NSError errorWithDomain:@"DBLPSearchController" code:1 userInfo:userInfo];
		NSLog(@"Error while creating XML file from eSearch request:%@", *err);
		return nil;
	}
	
	if(!xmlDoc){
		// warn the user that service is not available
		NSMutableDictionary *userInfo = [NSMutableDictionary dictionary];
		[userInfo setObject:NSLocalizedStringFromTableInBundle(@"Service Temporarily Unavailable", nil, [NSBundle bundleForClass:[self class]], @"Error message indicating that the service is currently not available") forKey:NSLocalizedDescriptionKey];
		[userInfo setObject:NSLocalizedStringFromTableInBundle(@"Please try again later.", nil, [NSBundle bundleForClass:[self class]], @"Recovery suggestion indicating to try the previous operation again at a later time") forKey:NSLocalizedRecoverySuggestionErrorKey];		
		*err = [NSError errorWithDomain:@"DBLPSearchController" code:1 userInfo:userInfo];
		return nil;
	}
	
	// Get info from XML
	NSArray *nrs = [[xmlDoc rootDocument] nodesForXPath:@"//eSearchResult/Count" error:err];
	NSArray *ids = [[xmlDoc rootDocument] nodesForXPath:@"//Id" error:err];
	NSArray *key = [[xmlDoc rootDocument] nodesForXPath:@"//QueryKey" error:err];
	NSArray *env = [[xmlDoc rootDocument] nodesForXPath:@"//WebEnv" error:err];
	
	// Store info
	if([nrs count]>0 && [[[nrs objectAtIndex:0]stringValue]intValue] > 0){
		*querykey = [[key objectAtIndex:0]stringValue];
		*webenv = [[env objectAtIndex:0]stringValue];
		*count = [NSNumber numberWithInt:[[[nrs objectAtIndex:0]stringValue]intValue]];
	}
	
	// return the results
	return [ids valueForKey:@"stringValue"];
}


// this method parses the raw response data of a fetchArticleSummaryForQueryKey:
// it generates the xml and gets the result, returning an array of paper dictionary objects. 
-(NSArray*)parseSummaryData:(NSData*)data
					  error:(NSError**)err
{
	// transform data into an xml document
	NSXMLDocument *xmlDoc = [[[NSXMLDocument alloc] initWithData:data
														 options:NSXMLNodePreserveCDATA 
														   error:err]autorelease]; 
	
	if(*err){
		// warn the user that xml file could not be created
		NSMutableDictionary *userInfo = [NSMutableDictionary dictionary];
		[userInfo setObject:NSLocalizedStringFromTableInBundle(@"Error parsing XML data.", nil, [NSBundle bundleForClass:[self class]], @"Error message when XML data cannot be parsed") forKey:NSLocalizedDescriptionKey];
		[userInfo setObject:NSLocalizedStringFromTableInBundle(@"Please try again.", nil, [NSBundle bundleForClass:[self class]], @"Recovery suggestion indicating to try the previous operation again") forKey:NSLocalizedRecoverySuggestionErrorKey];		
		*err = [NSError errorWithDomain:@"DBLPSearchController" code:1 userInfo:userInfo];
		NSLog(@"Error while creating XML file from eSummary request:%@", *err);
		return nil;
	}
	
	if(!xmlDoc){
		// warn the user that service is not available
		NSMutableDictionary *userInfo = [NSMutableDictionary dictionary];
		[userInfo setObject:NSLocalizedStringFromTableInBundle(@"Service Temporarily Unavailable", nil, [NSBundle bundleForClass:[self class]], @"Error message indicating that the service is currently not available") forKey:NSLocalizedDescriptionKey];
		[userInfo setObject:NSLocalizedStringFromTableInBundle(@"Please try again later.", nil, [NSBundle bundleForClass:[self class]], @"Recovery suggestion indicating to try the previous operation again at a later time") forKey:NSLocalizedRecoverySuggestionErrorKey];		
		*err = [NSError errorWithDomain:@"DBLPSearchController" code:1 userInfo:userInfo];
		return nil;
	}
	
	// Get info from XML
	NSMutableArray *summaries = [NSMutableArray arrayWithCapacity:100];
	NSArray *nodes = [[xmlDoc rootDocument] nodesForXPath:@"//DocSum" error:err];
	
	id node = nil;
	NSEnumerator *e = [nodes objectEnumerator];
	while(node = [e nextObject]){
		NSDictionary *paper = [self parseSummaryNode:node error:err];
		if(paper) [summaries addObject:paper];
	}
	
	// return the results
	return summaries;
}

// this  method takes a single article summary node and creates an article dictionary
// see protocol file for the different fields
-(NSDictionary*)parseSummaryNode:(NSXMLElement*)summary 
						   error:(NSError**)err
{
	// sanity check
	if(!summary) return nil;
	
	// create an empty paper dictionary to store our stuff
	NSMutableDictionary *result = [NSMutableDictionary dictionaryWithCapacity:50];
	
	// populate
	NSArray *array = nil;
	
	// Title
	array = [summary nodesForXPath:@".//Item[@Name=\"Title\"]" error:err];
	if([array count]>0) [result setValue:[[[array objectAtIndex:0]stringValue]stringByRemovingTrailingPeriodsAndMarks] forKey:@"title"];
	
	// Temporary authorlist
	array = [summary nodesForXPath:@".//Item[@Name=\"Author\"]" error:err];
	if([array count]>0) {
		NSString *temporaryAuthorString = [[array objectAtIndex:0]stringValue];
		if([array count]>1)
			temporaryAuthorString = [NSString stringWithFormat:@"%@ et al.", temporaryAuthorString];
		[result setValue:temporaryAuthorString forKey:@"tempAuthorString"];
	}
	
	// Temporary source string
	array = [summary nodesForXPath:@".//Item[@Name=\"Source\"]" error:err];
	if([array count]>0){
		NSString *temporaryJournalString = [[array objectAtIndex:0]stringValue];
		array = [summary nodesForXPath:@".//Item[@Name=\"SO\"]" error:err];
		if([array count]>0) 
			temporaryJournalString = [temporaryJournalString stringByAppendingFormat:@" %@", [[array objectAtIndex:0]stringValue]];
		[result setValue:temporaryJournalString forKey:@"tempJournalString"];
	}
	
	// PMID
	array = [summary nodesForXPath:@".//Id" error:err];
	if([array count]>0) [result setValue:[[array objectAtIndex:0]stringValue] forKey:@"identifier"];
	
	// PublicationDate
	array = [summary nodesForXPath:@".//Item[@Name=\"History\"]/Item[@Name=\"dblp\"]" error:err];
	if([array count]>0){
		NSCalendarDate *date = [self dateFromDBLPDateString:[[array objectAtIndex:0]stringValue]];
		if(date){
			[result setValue:date forKey:@"publishedDate"];
			[result setValue:[NSNumber numberWithInt:[date yearOfCommonEra]] forKey:@"year"];
		}
	}
	
	// PublicationDate from the journal
	array = [summary nodesForXPath:@".//Item[@Name=\"PubDate\"]" error:err];
	if([array count]>0){
		NSCalendarDate *date = [self dateFromDBLPDateString:[[array objectAtIndex:0]stringValue]];
		if(date){
			[result setValue:date forKey:@"publishedDate"];
			[result setValue:[NSNumber numberWithInt:[date yearOfCommonEra]] forKey:@"year"];
		}
	}
	
	// Language
	array = [summary nodesForXPath:@".//Item[@Name=\"Lang\"]" error:err];
	if([array count]>0) [result setValue:[[array objectAtIndex:0]stringValue] forKey:@"language"];
	
	// Status
	array = [summary nodesForXPath:@".//Item[@Name=\"RecordStatus\"]" error:err];
	if([array count]>0) [result setValue:[[array objectAtIndex:0]stringValue] forKey:@"status"];		
	
	// check if everything went fine and we got something
	if(*err)
		NSLog(@"Error parsing summary:%@", *err);
	
	if([result count]==0) return nil;
	
	// return the parsed entry
	return result;
}


// this method parses the raw response data of a fetchArticleDataForQueryKey:
// it generates the xml and gets the result, returning an array of paper dictionary objects. 
-(NSArray*)parseArticleData:(NSData*)data
					  error:(NSError**)err
{
	// transform data into an xml document
	NSXMLDocument *xmlDoc = [[[NSXMLDocument alloc] initWithData:data
														 options:NSXMLNodePreserveCDATA 
														   error:err]autorelease]; 
	
	if(*err){
		// warn the user that xml file could not be created
		NSMutableDictionary *userInfo = [NSMutableDictionary dictionary];
		[userInfo setObject:NSLocalizedStringFromTableInBundle(@"Error parsing XML data.", nil, [NSBundle bundleForClass:[self class]], @"Error message when XML data cannot be parsed") forKey:NSLocalizedDescriptionKey];
		[userInfo setObject:NSLocalizedStringFromTableInBundle(@"Please try again.", nil, [NSBundle bundleForClass:[self class]], @"Recovery suggestion indicating to try the previous operation again") forKey:NSLocalizedRecoverySuggestionErrorKey];		
		*err = [NSError errorWithDomain:@"DBLPSearchController" code:1 userInfo:userInfo];
		NSLog(@"Error while creating XML file from eFetch request:%@", *err);
		return nil;
	}
	
	if(!xmlDoc){
		// warn the user that service is not available
		NSMutableDictionary *userInfo = [NSMutableDictionary dictionary];
		[userInfo setObject:NSLocalizedStringFromTableInBundle(@"Service Temporarily Unavailable", nil, [NSBundle bundleForClass:[self class]], @"Error message indicating that the service is currently not available") forKey:NSLocalizedDescriptionKey];
		[userInfo setObject:NSLocalizedStringFromTableInBundle(@"Please try again later.", nil, [NSBundle bundleForClass:[self class]], @"Recovery suggestion indicating to try the previous operation again at a later time") forKey:NSLocalizedRecoverySuggestionErrorKey];		
		*err = [NSError errorWithDomain:@"DBLPSearchController" code:1 userInfo:userInfo];
		return nil;
	}
	
	// Get info from XML
	NSMutableArray *papers = [NSMutableArray arrayWithCapacity:100];
	
	NSArray *nodes = [[xmlDoc rootDocument] nodesForXPath:@".//PubmedArticle" error:err];
	id node = nil;
	NSEnumerator *e = [nodes objectEnumerator];
	while(node = [e nextObject]){
		NSDictionary *paper = [self parseArticleNode:node error:err];
		if(paper) [papers addObject:paper];
	}
	
	// return the results
	return papers;
}


// this  method takes a single article summary node and creates an article dictionary
// see protocol file for the different fields
-(NSDictionary*)parseArticleNode:(NSXMLElement*)aNode 
						   error:(NSError**)err
{
	// sanity check
	if(!aNode) return nil;
	
	// create an empty paper dictionary to store our stuff
	NSMutableDictionary *result = [NSMutableDictionary dictionaryWithCapacity:50];
	
	// populate
	NSXMLElement *subNode = nil;
	NSXMLElement *subsubNode = nil;
	
	NSMutableArray *authors = nil;
	NSMutableArray *keywords = nil;
	NSMutableArray *pubtypes = nil;
	
	NSMutableDictionary *journal = nil;	
	NSMutableDictionary *author = nil;
	NSMutableDictionary *keyword = nil;
	NSMutableDictionary *pubtype = nil;
	
	// iterate over children nodes
	while (aNode = (NSXMLElement*)[aNode nextNode]) { 
		NSString *elementName = [aNode name];
		// NSLog(@"%@ -> %@", elementName, [aNode XMLString]);
		
		if ([elementName isEqualToString:@"PMID"] && ![result valueForKey:@"identifier"]) {
			[result setValue:[aNode stringValue] forKey:@"identifier"];
		}
		else if ([elementName isEqualToString:@"PubmedArticle"]) { 
			break;
		}
		else if ([elementName isEqualToString:@"DateCreated"]) { 
			aNode = (NSXMLElement*)[[aNode nextSibling]previousNode]; // skip children
		}
		else if ([elementName isEqualToString:@"DateCompleted"]) { 
			aNode = (NSXMLElement*)[[aNode nextSibling]previousNode]; // skip children
		}
		else if ([elementName isEqualToString:@"DateRevised"]) { 
			aNode = (NSXMLElement*)[[aNode nextSibling]previousNode]; // skip children
		}
		else if ([elementName isEqualToString:@"Journal"]){
			// create the journal dictionary
			if(!journal) journal = [NSMutableDictionary dictionaryWithCapacity:20];
			// populate
			NSEnumerator *e = [[aNode children]objectEnumerator];
			while (subNode = [e nextObject]) { 
				NSString *subElementName = [subNode name];
				if ([subElementName isEqualToString:@"ISSN"]) {
					[journal setValue:[subNode stringValue] forKey:@"issn"];
				}
				else if ([subElementName isEqualToString:@"JournalIssue"]) {
					NSEnumerator *f = [[subNode children]objectEnumerator];
					while (subsubNode = [f nextObject]) { 
						NSString *subsubElementName = [subsubNode name];
						if ([subsubElementName isEqualToString:@"Volume"]) {
							[result setValue:[subsubNode stringValue] forKey:@"volume"];
						}
						else if ([subsubElementName isEqualToString:@"Issue"]) {
							[result setValue:[subsubNode stringValue] forKey:@"issue"];
						}
						else if ([subsubElementName isEqualToString:@"PubDate"]) {
							// date
							NSCalendarDate *date = [self dateFromDBLPDateNode:subsubNode];
							if(date){
								[result setValue:date forKey:@"publishedDate"];
								[result setValue:[NSNumber numberWithInt:[date yearOfCommonEra]] forKey:@"year"];
							}
						}						 
					}
				}
				else if ([subElementName isEqualToString:@"Title"]) {
					[journal setValue:[[subNode stringValue]stringByRemovingPeriodsAndTrailingMarks] forKey:@"name"];
				}
				else if ([subElementName isEqualToString:@"ISOAbbreviation"]) {
					[journal setValue:[[subNode stringValue]stringByRemovingPeriodsAndTrailingMarks] forKey:@"abbreviation"];
				}
			}
			aNode = (NSXMLElement*)[[aNode nextSibling]previousNode]; // skip rest
		}
		else if ([elementName isEqualToString:@"MedlineTA"]){
			if(![journal valueForKey:@"name"])
				[journal setValue:[[aNode stringValue]stringByRemovingPeriodsAndTrailingMarks] forKey:@"name"];
		}
		else if ([elementName isEqualToString:@"ArticleTitle"]){
			[result setValue:[[aNode stringValue]stringByRemovingTrailingPeriodsAndMarks] forKey:@"title"];
		}
		else if ([elementName isEqualToString:@"MedlinePgn"]){
			[result setValue:[aNode stringValue] forKey:@"pages"];
		}
		else if ([elementName isEqualToString:@"Language"]){
			[result setValue:[aNode stringValue] forKey:@"language"];
		}
		else if ([elementName isEqualToString:@"AbstractText"]){
			[result setValue:[aNode stringValue] forKey:@"abstract"];
		}
		else if ([elementName isEqualToString:@"Affiliation"]){
			[result setValue:[aNode stringValue] forKey:@"affiliation"];
		}
		else if ([elementName isEqualToString:@"Author"]){
			// if not already there create authors array
			if(!authors) authors = [NSMutableArray arrayWithCapacity:200];
			// create new author
			author = [NSMutableDictionary dictionaryWithCapacity:20];
			// populate
			NSEnumerator *e = [[aNode children]objectEnumerator];
			while (subNode = [e nextObject]) { 
				NSString *subElementName = [subNode name];
				if ([subElementName isEqualToString:@"LastName"]) {
					[author setValue:[subNode stringValue] forKey:@"lastName"];
				}
				if ([subElementName isEqualToString:@"CollectiveName"]) {
					[author setValue:[subNode stringValue] forKey:@"lastName"];
				}
				if ([subElementName isEqualToString:@"ForeName"]) {
					[author setValue:[subNode stringValue] forKey:@"firstName"];
				}
				if ([subElementName isEqualToString:@"Initials"]) {
					NSString *initials = [subNode stringValue];
					[author setValue:initials forKey:@"initials"];
					// if no firstname set first initial
					if(![author valueForKey:@"firstName"] && [initials length]>0) [author setValue:[initials substringToIndex:1] forKey:@"firstName"];
				}
			}
			// cleanup and store
			if([author valueForKey:@"lastName"]){
				[authors addObject:author];
			}
			else NSLog(@"No lastname for author!");
		}
		else if ([elementName isEqualToString:@"PublicationType"]){
			// if not already there create pubtypes array
			if(!pubtypes) pubtypes = [NSMutableArray arrayWithCapacity:200];
			// create new pubtype
			pubtype = [NSMutableDictionary dictionaryWithCapacity:10];
			// populate
			[pubtype setValue:[aNode stringValue] forKey:@"name"];
			// store
			[pubtypes addObject:pubtype];
		}
		else if ([elementName isEqualToString:@"MeshHeading"]){
			// if not already there create keyword array
			if(!keywords) keywords = [NSMutableArray arrayWithCapacity:200];
			// create new keyword
			keyword = [NSMutableDictionary dictionaryWithCapacity:10];
			// populate
			[keyword setValue:[[[aNode childAtIndex:0]stringValue]filteredKeyword] forKey:@"name"];
			[keyword setValue:@"MeSH Heading" forKey:@"type"];
			
			NSString *keyword_subtype = ([[[(NSXMLElement*)aNode attributeForName:@"MajorTopicYN"]stringValue]isEqualToString:@"Y"]) ? @"Major Topic" :nil;
			if(keyword_subtype)[keyword setValue:keyword_subtype forKey:@"subtype"];
			
			// store
			if([keyword valueForKey:@"name"]){
				[keywords addObject:keyword];
			}
			else NSLog(@"No name for keyword!");
		}
		else if ([elementName isEqualToString:@"DBLPPubDate"]){
			NSString *pubStatus = [[(NSXMLElement*)aNode attributeForName:@"PubStatus"]stringValue];
			NSCalendarDate *date = [self dateFromDBLPDateNode:aNode];
			
			if(date && [pubStatus isEqualToString:@"received"])
				[result setValue:date forKey:@"receivedDate"];
			
			else if(date && [pubStatus isEqualToString:@"revised"])
				[result setValue:date forKey:@"revisedDate"];
			
			else if(date && [pubStatus isEqualToString:@"accepted"])
				[result setValue:date forKey:@"acceptedDate"];
			
			else if(date && [pubStatus isEqualToString:@"dblp"]){
				// only if we don't have one already
				if(![result valueForKey:@"publishedDate"]){
					[result setValue:date forKey:@"publishedDate"];
					[result setValue:[NSNumber numberWithInt:[date yearOfCommonEra]] forKey:@"year"];
				}
			}
		}
		else if ([elementName isEqualToString:@"PublicationStatus"]){
			NSDictionary *statusDictionary = [[NSDictionary dictionaryWithObjectsAndKeys:@"Received", @"received", @"Accepted", @"accepted", @"Electronic publication", @"epublish", @"Printed Publication", @"ppublish", @"Revised", @"revised", @"Ahead of Print", @"aheadofprint", @"Retracted", @"retracted", nil]retain]; 
			[result setValue:[statusDictionary objectForKey:[aNode stringValue]] forKey:@"status"];
		}
		else if ([elementName isEqualToString:@"ArticleId"]){
			NSString *idtype = [[(NSXMLElement*)aNode attributeForName:@"IdType"]stringValue];
			if ([idtype isEqualToString:@"doi"])
				[result setValue:[aNode stringValue] forKey:@"doi"];
			else if ([idtype isEqualToString:@"pii"]){
				[result setValue:[aNode stringValue] forKey:@"pii"];
			}
		}
	} 
	
	// Verify and add journal
	if(journal && [journal count] > 0){
		NSString *journal_name = [journal valueForKey:@"name"];
		NSString *journal_abbr = [journal valueForKey:@"abbreviation"];
		
		if(!journal_abbr && journal_name)
			[journal setValue:journal_name forKey:@"abbreviation"];
		
		if(!journal_name && journal_abbr)
			[journal setValue:journal_abbr forKey:@"name"];
		
		if(journal_name){
			// trim to length
			if([journal_name length] > 255){
				journal_name = [journal_name substringToIndex:255];
				[journal setValue:journal_name forKey:@"name"];
			}
			if([journal_abbr length] > 255){
				journal_abbr = [journal_abbr substringToIndex:255];
				[journal setValue:journal_abbr forKey:@"abbreviation"];
			}
			// store
			[result setValue:[NSArray arrayWithObject:journal] forKey:@"journal"];
		}
	}
	
	// add authors
	if(authors && [authors count] > 0){
		[result setValue:authors forKey:@"authors"];
	}
	
	// add keywords
	if(keywords && [keywords count] > 0){
		[result setValue:keywords forKey:@"keywords"];
	}
	
	// add pubtypes
	if(pubtypes && [pubtypes count] > 0){
		[result setValue:pubtypes forKey:@"publicationTypes"];
	}
	
	// check if everything went fine and we got something
	if(*err)
		NSLog(@"Error parsing article:%@", *err);
	
	if([result count]==0) return nil;
	
	// return the parsed entry
	return result;
}


// this method parses the raw response data of a fetchArticleLinksForQueryKey:
// it generates the xml and gets the result, returning an array of paper dictionary objects. 
-(NSArray*)parseLinksData:(NSData*)data
					error:(NSError**)err
{
	// transform data into an xml document
	NSXMLDocument *xmlDoc = [[[NSXMLDocument alloc] initWithData:data
														 options:NSXMLNodePreserveCDATA 
														   error:err]autorelease]; 
	
	if(*err){
		// warn the user that xml file could not be created
		NSMutableDictionary *userInfo = [NSMutableDictionary dictionary];
		[userInfo setObject:NSLocalizedStringFromTableInBundle(@"Error parsing XML data.", nil, [NSBundle bundleForClass:[self class]], @"Error message when XML data cannot be parsed") forKey:NSLocalizedDescriptionKey];
		[userInfo setObject:NSLocalizedStringFromTableInBundle(@"Please try again.", nil, [NSBundle bundleForClass:[self class]], @"Recovery suggestion indicating to try the previous operation again") forKey:NSLocalizedRecoverySuggestionErrorKey];		
		*err = [NSError errorWithDomain:@"DBLPSearchController" code:1 userInfo:userInfo];
		NSLog(@"Error while creating XML file from eLink request:%@", *err);
		return nil;
	}
	
	if(!xmlDoc){
		// warn the user that service is not available
		NSMutableDictionary *userInfo = [NSMutableDictionary dictionary];
		[userInfo setObject:NSLocalizedStringFromTableInBundle(@"Service Temporarily Unavailable", nil, [NSBundle bundleForClass:[self class]], @"Error message indicating that the service is currently not available") forKey:NSLocalizedDescriptionKey];
		[userInfo setObject:NSLocalizedStringFromTableInBundle(@"Please try again later.", nil, [NSBundle bundleForClass:[self class]], @"Recovery suggestion indicating to try the previous operation again at a later time") forKey:NSLocalizedRecoverySuggestionErrorKey];		
		*err = [NSError errorWithDomain:@"DBLPSearchController" code:1 userInfo:userInfo];
		return nil;
	}
	
	// Get info from XML
	NSMutableArray *links = [NSMutableArray arrayWithCapacity:100];
	
	// currently we only take link #1
	NSArray *nodes = [[xmlDoc rootDocument] nodesForXPath:@"//ObjUrl[1]" error:err];
	id node = nil;
	NSEnumerator *e = [nodes objectEnumerator];
	while(node = [e nextObject]){
		NSDictionary *link = [self parseLinkNode:node error:err];
		if(link) [links addObject:link];
	}
	
	// return the results
	return links;
}


// this  method takes a single link node and creates an url dictionary
-(NSDictionary*)parseLinkNode:(NSXMLElement*)aNode 
						error:(NSError**)err
{
	// sanity check
	if(!aNode) return nil;
	
	// create an empty paper dictionary to store our stuff
	NSMutableDictionary *link = [NSMutableDictionary dictionaryWithCapacity:10];
	
	NSArray *array = [aNode nodesForXPath:@".//Url" error:err];
	if([array count]>0){
		NSString *url = [[array objectAtIndex:0]stringValue];
		NSString *filtered_url = (NSString*)CFURLCreateStringByReplacingPercentEscapes (NULL, (CFStringRef)url, CFSTR(""));
		[link setValue:filtered_url forKey:@"url"];
		CFRelease(filtered_url);
	}
	
	// OpenAccess?
	array = [aNode nodesForXPath:@".//Attribute" error:err];
	if([array count]>0){
		array = [array valueForKey:@"stringValue"];
		BOOL isOpenAccess = ![array containsObject:@"subscription/membership/fee required"];		
		[link setValue:[NSNumber numberWithBool:isOpenAccess] forKey:@"openAccess"];
	}
	
	// check if everything went fine and we got something
	if(*err)
		NSLog(@"Error parsing link:%@", *err);
	
	if([link count]==0) return nil;
	
	// return the parsed entry
	return link;
}


// this method parses the raw response data of a fetchRelatedArticleDataForIdentifier:
// it generates the xml and gets the result, returning an array of pmids. 
-(NSArray*)parseRelatedArticleData:(NSData*)data
							 error:(NSError**)err
{
	// transform data into an xml document
	NSXMLDocument *xmlDoc = [[[NSXMLDocument alloc] initWithData:data
														 options:NSXMLNodePreserveCDATA 
														   error:err]autorelease]; 
	
	if(*err){
		// warn the user that xml file could not be created
		NSMutableDictionary *userInfo = [NSMutableDictionary dictionary];
		[userInfo setObject:NSLocalizedStringFromTableInBundle(@"Error parsing XML data.", nil, [NSBundle bundleForClass:[self class]], @"Error message when XML data cannot be parsed") forKey:NSLocalizedDescriptionKey];
		[userInfo setObject:NSLocalizedStringFromTableInBundle(@"Please try again.", nil, [NSBundle bundleForClass:[self class]], @"Recovery suggestion indicating to try the previous operation again") forKey:NSLocalizedRecoverySuggestionErrorKey];		
		*err = [NSError errorWithDomain:@"DBLPSearchController" code:1 userInfo:userInfo];
		NSLog(@"Error while creating XML file from eLink request:%@", *err);
		return nil;
	}
	
	if(!xmlDoc){
		// warn the user that service is not available
		NSMutableDictionary *userInfo = [NSMutableDictionary dictionary];
		[userInfo setObject:NSLocalizedStringFromTableInBundle(@"Service Temporarily Unavailable", nil, [NSBundle bundleForClass:[self class]], @"Error message indicating that the service is currently not available") forKey:NSLocalizedDescriptionKey];
		[userInfo setObject:NSLocalizedStringFromTableInBundle(@"Please try again later.", nil, [NSBundle bundleForClass:[self class]], @"Recovery suggestion indicating to try the previous operation again at a later time") forKey:NSLocalizedRecoverySuggestionErrorKey];		
		*err = [NSError errorWithDomain:@"DBLPSearchController" code:1 userInfo:userInfo];
		return nil;
	}
	
	// Get info from XML
	NSMutableArray *links = [NSMutableArray arrayWithCapacity:100];
	
	// currently we only take link #1
	NSArray *nodes = [[xmlDoc rootDocument] nodesForXPath:@"//Link" error:err];
	
	id node = nil;
	NSEnumerator *e = [nodes objectEnumerator];
	while(node = [e nextObject]){
		NSDictionary *link = [self parseRelatedArticleNode:node error:err];
		if(link) [links addObject:link];
	}
	
	// return the results
	return links;
}

// this  method takes a single link node and creates an url dictionary
-(NSDictionary*)parseRelatedArticleNode:(NSXMLElement*)aNode 
								  error:(NSError**)err
{
	// sanity check
	if(!aNode) return nil;
	
	// create an empty paper dictionary to store our stuff
	NSMutableDictionary *related_article = [NSMutableDictionary dictionaryWithCapacity:10];
	
	NSArray *array = [aNode nodesForXPath:@".//Id" error:err];
	if([array count]>0){
		NSString *pmid = [[array objectAtIndex:0]stringValue];
		[related_article setValue:pmid forKey:@"identifier"];
	}
	
	// OpenAccess?
	array = [aNode nodesForXPath:@".//Score" error:err];
	if([array count]>0){
		NSString *score = [[array objectAtIndex:0]stringValue];
		[related_article setValue:score forKey:@"score"];
	}
	
	// check if everything went fine and we got something
	if(*err)
		NSLog(@"Error parsing related article:%@", *err);
	
	if([related_article count]==0) return nil;
	
	// return the parsed entry
	return related_article;
}


/////////////////////////////////////////////////////////
#pragma mark Helper Methods
/////////////////////////////////////////////////////////

// this helper method takes a dblp date node, it then goes through the children 
// and several possibilities to create a date object
-(NSCalendarDate*)dateFromDBLPDateNode:(NSXMLElement*)aNode{
	NSCalendarDate *date = nil;
	NSString *str = [[[aNode children] valueForKey:@"stringValue"]componentsJoinedByString:@"/"];
	
	if([[aNode children]count]==5){
		date = [NSCalendarDate dateWithString:str
							   calendarFormat:@"%Y/%b/%e/%H/%M"];
		
		if(!date){
			// try without time
			date = [NSCalendarDate dateWithString:str
								   calendarFormat:@"%Y/%m/%e/%H/%M"];
		}
	} 
	else if([[aNode children]count]==3){
		date = [NSCalendarDate dateWithString:str
							   calendarFormat:@"%Y/%b/%e"];
		
		if(!date){
			// try without time
			date = [NSCalendarDate dateWithString:str
								   calendarFormat:@"%Y/%m/%e"];
		}
	}
	else if([[aNode children]count]==2){
		//NSArray *localemonth = [NSArray arrayWithObjects:@"Jan", @"Feb", @"Mar", @"Apr", @"May", @"Jun", @"Jul", @"Aug", @"Sep", @"Oct", @"Nov", @"Dec", nil];
		date = [NSCalendarDate dateWithString:str
							   calendarFormat:@"%Y/%b"];
		//locale:[NSDictionary dictionaryWithObject:localemonth forKey:NSShortMonthNameArray]];
		
		if(!date){
			// try without time
			date = [NSCalendarDate dateWithString:str
								   calendarFormat:@"%Y/%m"];
		}
	}
	else if([[aNode children]count]==1){
		date = [NSCalendarDate dateWithString:str
							   calendarFormat:@"%Y"];
	}
	return date;
}

// this helper method does the same as above but from a string, it tests several possibilities to create a date object
-(NSCalendarDate*)dateFromDBLPDateString:(NSString*)str{
	
	NSCalendarDate *date = 	[NSCalendarDate dateWithString:str
											calendarFormat:@"%Y/%m/%d %H:%M"];
	
	if(!date){
		date = [NSCalendarDate dateWithString:str
							   calendarFormat:@"%Y %b %e"];
	}
	if(!date){
		date = [NSCalendarDate dateWithString:str
							   calendarFormat:@"%Y %m %e"];
	}
	if(!date){
		date = [NSCalendarDate dateWithString:str
							   calendarFormat:@"%Y %b"];
	}
	
	if(!date){
		date = [NSCalendarDate dateWithString:str
							   calendarFormat:@"%Y %m"];
	}
	if(!date){
		date = [NSCalendarDate dateWithString:str
							   calendarFormat:@"%Y"];
	}
	return date;
}


-(NSDictionary*)searchTokenForAuthor:(NSDictionary*)author {
	if(!author || ![author valueForKey:@"lastName"]) return nil;
	
	NSString *lastname  = [author valueForKey:@"lastName"];
	NSString *firstname = [author valueForKey:@"firstName"];
	NSString *initials = [author valueForKey:@"initials"];
	
	NSString *query = nil;
	if(firstname && [firstname length]>1)
		query = [NSString stringWithFormat:@"%@, %@", lastname, firstname];
	else if(initials && [initials length]>1)
		query = [NSString stringWithFormat:@"%@ %@", lastname, initials];
	else
		query = lastname;
	
	// we mimic a real MTQueryTermToken (see protocol) by creating a dictionary with the same keys so like an MTQueryTermToken the object will
	// listen to valueForKey:@"query" for example. This way we can reuse the performSearchWithQuery method.
	NSDictionary *dict = [[NSDictionary alloc]initWithObjectsAndKeys:[query stringByRemovingAccents], @"token", 
						  @"Author", @"field", 
						  @"[AU]", @"code", 
						  @"Include", @"operatorType", 
						  @"AND", @"operatorCode", 
						  [NSNumber numberWithBool:NO], @"predefined", nil];
	
	return [dict autorelease];
}

-(NSDictionary*)searchTokenForJournal:(NSDictionary*)journal {
	if(!journal) return nil;
	
	NSString *name = [journal valueForKey:@"name"];
	NSString *abbr = [journal valueForKey:@"abbreviation"];
	
	NSString *query = nil;
	if(abbr && [abbr length]>1)
		query = abbr;
	else
		query = name;
	
	// we mimic a real MTQueryTermToken (see protocol) by creating a dictionary with the same keys so like an MTQueryTermToken the object will
	// listen to valueForKey:@"query" for example. This way we can reuse the performSearchWithQuery method.
	NSDictionary *dict = [[NSDictionary alloc]initWithObjectsAndKeys:query, @"token", 
						  @"Journal", @"field", 
						  @"[TA]", @"code", 
						  @"Include", @"operatorType", 
						  @"AND", @"operatorCode", 
						  [NSNumber numberWithBool:NO], @"predefined", nil];
	
	return [dict autorelease];
}

-(NSDictionary*)searchTokenForKeyword:(NSDictionary*)keyword {
	if(!keyword) return nil;
	
	// we mimic a real MTQueryTermToken (see protocol) by creating a dictionary with the same keys so like an MTQueryTermToken the object will
	// listen to valueForKey:@"query" for example. This way we can reuse the performSearchWithQuery method.
	NSDictionary *dict = [[NSDictionary alloc]initWithObjectsAndKeys:[keyword valueForKey:@"name"], @"token", 
						  @"MeSH Term", @"field", 
						  @"[MH]", @"code", 
						  @"Include", @"operatorType", 
						  @"AND", @"operatorCode", 
						  [NSNumber numberWithBool:NO], @"predefined", nil];
	
	return [dict autorelease];
}

@end


