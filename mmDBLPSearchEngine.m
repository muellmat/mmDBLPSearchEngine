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

@interface mmDBLPSearchEngine (private)
BOOL isSearching;
BOOL shouldContinueSearch;

//caches
NSDictionary *cachedPredefinedSearchTerms;
NSDictionary *cachedSearchFields;
@end

// this category provides plugin specific helper methods for this plugin
// the mainly involve working with your specific plugin.
@interface mmDBLPSearchEngine (helpers)

- (NSString *)queryStringFromTokens: (NSArray *)tokens;

- (NSDictionary *)searchTokenForAuthor: (NSDictionary *)author;
- (NSDictionary *)searchTokenForJournal: (NSDictionary *)journal;
- (NSDictionary *)searchTokenForKeyword: (NSDictionary *)keyword;

@end

// here is where the implementation of the plugin starts and where the different
// protocol methods are provided.
@implementation mmDBLPSearchEngine

#pragma mark - 
#pragma mark Init

- (id) init {
    self = [super init];
	if ( self != nil ) {
		// space for early setup
		isSearching = NO;
		shouldContinueSearch = YES;
		// set the caches to nil
		cachedPredefinedSearchTerms = nil;
		cachedSearchFields = nil;
	}
	return self;    
}

- (void) awakeFromNib {
	// setup nib if necessary, here we initialize the preferences
	NSUserDefaults *prefs = [NSUserDefaults standardUserDefaults];
	if(![prefs objectForKey: @"xx_mysearchengine_itemsPerPage"]) [prefs setObject: [NSNumber numberWithInt: 30] forKey: @"xx_mysearchengine_itemsPerPage"];
	if(![prefs objectForKey: @"xx_mysearchengine_shouldAutocomplete"]) [prefs setObject: [NSNumber numberWithBool: NO] forKey: @"xx_mysearchengine_shouldAutocomplete"];
}

- (void) dealloc {
    // cleanup last items here
	// NOTE: most items are cleaned in the performCleanup: method, which is called after each run. 
	// the dealloc method is only called when the plugin is unloaded, which is only when the app quits.
	
	// clear the caches
	[cachedPredefinedSearchTerms release];
	[cachedSearchFields release];
	
    [super dealloc];
}


#pragma mark -
#pragma mark Accessors

// gives you a handle to the delegate object to which you deliver results and notify progress (see above)
// do not retain the delegate
- (id)delegate
{
	return delegate;
}

- (void)setDelegate:(id)newDelegate
{
	delegate = newDelegate;
}

// number of items that are fetched per batch, default is set by Papers but can be overridden
// internally.
// NOTE: Only applies to the performSearchWithQuery: method
- (NSNumber *)itemsPerPage
{
	return (itemsPerPage ? itemsPerPage : [[NSUserDefaults standardUserDefaults]objectForKey: @"xx_mysearchengine_itemsPerPage"]);
}

- (void)setItemsPerPage:(NSNumber *)newItemsPerPage
{
	[newItemsPerPage retain];
	[itemsPerPage release];
	itemsPerPage = newItemsPerPage;
}

// the offset we have to start fetching from. This is set by Papers before the search is started 
// and used when the user wishes to get the next page of results. 
// NOTE: Only applies to the performSearchWithQuery: method
- (NSNumber *)itemOffset
{
	return itemOffset;
}

- (void)setItemOffset:(NSNumber *)newItemOffset
{
	[newItemOffset retain];
	[itemOffset release];
	itemOffset = newItemOffset;
}

// return the number of items found for this query, this is the total number even if you fetch
// only one page
- (NSNumber *)itemsFound
{
	return itemsFound;
}

- (void)setItemsFound:(NSNumber *)newItemsFound
{
	[newItemsFound retain];
	[itemsFound release];
	itemsFound = newItemsFound;
}

// return the number of items you are about to retrieve (batch size). 
// return the number of items you have retrieved. 
// As long as this value is nil an indeterminate progress bar is shown, the moment you return a non-nil value for both the 
// progress will be shown to the user. use in combination with the delegate method updateStatus: to push changes to the 
// delegate and force an update.

- (NSNumber *)itemsToRetrieve
{
	return itemsToRetrieve;
}

- (void)setItemsToRetrieve:(NSNumber *)newItemsToRetrieve
{
	[newItemsToRetrieve retain];
	[itemsToRetrieve release];
	itemsToRetrieve = newItemsToRetrieve;
	
	// inform our delegate to update the status
	id <PapersSearchPluginDelegate> del = [self delegate];
	[del updateStatus: self];
}

// here we keep track of what we have retrieved thusfar since we work
// in batches.
- (NSNumber *)retrievedItems
{
	return retrievedItems;
}

- (void)setRetrievedItems:(NSNumber *)newRetrievedItems
{
	[newRetrievedItems retain];
	[retrievedItems release];
	retrievedItems = newRetrievedItems;
	
	// inform our delegate to update the status
	id <PapersSearchPluginDelegate> del = [self delegate];
	[del updateStatus: self];
}

- (void)incrementRetrievedItemsWith: (int)value{
	int old = [[self retrievedItems]intValue];
	[self setRetrievedItems: [NSNumber numberWithInt: old+value]];
}

// return the current status of your plugin to inform the user. we use it in combination with the delegate 
// method updateStatus: to push changes to the delegate and force an update.
//
// the statusstring is stored here such that the delegate can retrieve it
// when we call [delegate updateStatus]. note that we invoke this method
// automatically when we change the value in the setter.
- (NSString *)statusString
{
	return statusString;
}

- (void)setStatusString:(NSString *)newStatusString
{
	[newStatusString retain];
	[statusString release];
	statusString = newStatusString;
	
	// inform our delegate to update the status
	id <PapersSearchPluginDelegate> del = [self delegate];
	[del updateStatus: self];
}

// A method to check whether the search finished properly
// and one to get at any errors that resulted. See above for usage of errorCodes.
- (NSError *)searchError
{
	return searchError;
}

- (void)setSearchError:(NSError *)newSearchError
{
	[newSearchError retain];
	[searchError release];
	searchError = newSearchError;
}


#pragma mark -
#pragma mark Interface interaction methods

// name returns a string which is shown in the source list and used throughout the UI.
// make sure there are no naming collisions with existing plugins and keep the name rather short.
- (NSString *) name{
	return NSLocalizedStringFromTableInBundle(@"mySearchEngine", nil, [NSBundle bundleForClass: [self class]], @"Localized name of the service");
}

// allows to return a color for your plugin, here blue for Pubmed.
// Note: in the plugin test application you can click on the statusbar in the config panel to
// get a color picker that helps you pick a color for the statusbar. The color will be updated and 
// logged into the console so that it can be entered here.
- (NSColor *) color{
	return [NSColor colorWithCalibratedRed:135.0/255.0
									 green:174.0/255.0
									  blue:216.0/255.0
									 alpha:1.0];	
}

// return the logo as will be displayed in the search box. take a look at the sample plugins for examples. Suggested size 250w x 50h.
- (NSImage *) logo{
	NSString *imagepath = [[NSBundle bundleForClass: [self class]] pathForResource: @"logo_mysearchengine" ofType: @"tif"];
	return [[[NSImage alloc]initWithContentsOfFile: imagepath]autorelease];
}

// return an 37w x 31h icon for use in the statusbar (one with the magnifying class)
- (NSImage *) large_icon{
	NSString *imagepath = [[NSBundle bundleForClass: [self class]] pathForResource: @"toolstrip_mysearchengine" ofType: @"tif"];
	return [[[NSImage alloc]initWithContentsOfFile: imagepath]autorelease];
}

// return a 18w x 16 icon for use in the inspector bar (without a magnifying class)
- (NSImage *) small_icon{
	NSString *imagepath = [[NSBundle bundleForClass: [self class]] pathForResource: @"statusbar_mysearchengine" ofType: @"tif"];
	return [[[NSImage alloc]initWithContentsOfFile: imagepath]autorelease];
}

// return a 25w x23h icon for use in the source list (normal setting)
- (NSImage *) sourcelist_icon{
	NSString *imagepath = [[NSBundle bundleForClass: [self class]] pathForResource: @"group_mysearchengine" ofType: @"tif"];
	return [[[NSImage alloc]initWithContentsOfFile: imagepath]autorelease];
}

// return a 20w x 18h icon for use in the source list (small setting)
- (NSImage *) sourcelist_icon_small{
	NSString *imagepath = [[NSBundle bundleForClass: [self class]] pathForResource: @"group_mysearchengine_small" ofType: @"tif"];
	return [[[NSImage alloc]initWithContentsOfFile: imagepath]autorelease];
}

// return the weburl to the homepage of the searchengine/repository
- (NSURL *) info_url{
	return [NSURL URLWithString: @"http://www.mysearchengine.com"];
}

// return a unique identifier in the form of a reverse web address of the search engine
- (NSString *) identifier{
	return @"com.mysearchengine";
}

// return whether the search engine requires a subscription
- (BOOL) requiresSubscription{
	return NO;
}

// return NO if you only wish to use this plugin for matching or automatching
// note that you still need to fullfill the PapersSearchPluginProtocol protocol, 
// you can just leave most of its methods empty in that case.
- (BOOL) actsAsGeneralSearchEngine{
	return YES;
}

#pragma mark -
#pragma mark Preferences

// if your plugin needs to be configured you can return here a preference panel. 
// take a look at the example plugin on how to use this.
// Otherwise return nil.
- (NSView *) preferenceView{
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
- (NSDictionary *)predefinedSearchTerms{
	if(!cachedPredefinedSearchTerms){
		NSString *dictpath = [[NSBundle bundleForClass: [self class]] pathForResource: @"MysearchenginePredefinedTokens" ofType: @"plist"];
		cachedPredefinedSearchTerms = [[NSDictionary alloc]initWithContentsOfFile: dictpath];
	}
	return cachedPredefinedSearchTerms;
}

// return a dictionary of searchfield codes that show up as choices in the searchtokens
// the dictionary should contain an array under key "order" and a dictionary under the key "fields" containing 
// key-value pairs where the key is the name of the field and the value a code that 
// your plugin can translate into the right parameters. We advise to adopt the pubmed model of
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
- (NSDictionary *)searchFields{
	if(!cachedSearchFields){
		NSString *dictpath = [[NSBundle bundleForClass: [self class]] pathForResource: @"MysearchengineSearchFields" ofType: @"plist"];
		cachedSearchFields = [[NSDictionary alloc]initWithContentsOfFile: dictpath];
	}
	return cachedSearchFields;
}


#pragma mark -
#pragma mark Autocompletion

// return yes if you wish to autocomplete searchterms
// if you do autocompletion via the internet, be sure to check the server is up!
- (BOOL)autocompletesSearchTerms{
	return [[NSUserDefaults standardUserDefaults]boolForKey: @"xx_mysearchengine_shouldAutocomplete"];
}


// return an array of strings for the partial string, make sure this stuff works fast!
- (NSArray *)autocompletionsForPartialString: (NSString *)str{
	// do your lookups here. Remember, this should be really fast!
	return [NSArray array];
}


#pragma mark -
#pragma mark Searching

// a method to make sure everything's set to go before starting, do some setup or tests here if necessary.
// and a method to find out what the problems are if things aren't set. See above for usage of errorCodes.
// for instance return an error when the service is not up.
- (BOOL)readyToPerformSearch{
	// do some setup here if necessary
	shouldContinueSearch = YES;
	[self setSearchError: nil];
	[self setItemsFound: [NSNumber numberWithInt: 0]];
	[self setRetrievedItems: [NSNumber numberWithInt: 0]];
	return YES;	
}

- (NSError *)searchPreparationError{
	// here we simple return searchError, if something went wrong before we would have set it to a non-nil value.
	return searchError;
}

// used for the history items and saved folders in the
- (NSString *)descriptiveStringForQuery: (NSArray *)tokens{
	if(tokens){
		return [[tokens valueForKey:@"displayString"]componentsJoinedByString:@"+"];
	}
	return @"";
}

// return YES if you support cancelling the current search session (strongly advised).
- (BOOL) canCancelSearch{
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
// IMPORTANT: try to always sort results on publication date!
//
// NOTE: that this method runs in a separate thread. Signal your progress to the delegate.
- (void) performSearchWithQuery: (NSArray *)tokens{
	
	// Since we run threaded we need the autorelease pool!
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc]init];
	
	// Are we already searching?
	if(isSearching){
		//Warning: CHECK WHAT HAPPENS IF CALLED AGAIN, AND CANCEL PREVIOUS ONE
	}
	// Now we are
	isSearching = YES;
	
	// Generate the query from the tokens
	NSString *currentQuery = [self queryStringFromTokens: tokens];
	if(!currentQuery){
		NSMutableDictionary *userInfo = [NSMutableDictionary dictionary];
		[userInfo setObject: NSLocalizedStringFromTableInBundle(@"Could not create query from searchfield input", nil, [NSBundle bundleForClass: [self class]], @"Error message when query can't be created") forKey:NSLocalizedDescriptionKey];
		[userInfo setObject: NSLocalizedStringFromTableInBundle(@"Please ensure you have created a proper query.", nil, [NSBundle bundleForClass: [self class]], @"Recovery suggestion when query can't be created") forKey:NSLocalizedRecoverySuggestionErrorKey];		
		[self setSearchError: [NSError errorWithDomain: @"MySearchEngineController" code: 1 userInfo: userInfo]];
		goto cleanup;
	}
	
	// Inform delegate we're about to start
	id <PapersSearchPluginDelegate> del = [self delegate];
	[del didBeginSearch: self];
	
	[self setStatusString: NSLocalizedStringFromTableInBundle(@"Connecting with MySearchEngine...", nil, [NSBundle bundleForClass: [self class]], @"Status message shown when plugin is connecting to the service")];
	
	////////////////////////////////////////
	// GET THE RESULTS HERE...
	////////////////////////////////////////

	// Hand them to the delegate
	NSArray *papers = [[NSArray alloc] init];
	[del didRetrieveObjects: [NSDictionary dictionaryWithObject: papers forKey: @"papers"]];
	
	// Update count + batch
	[self incrementRetrievedItemsWith: [papers count]];
	
	////////////////////////////////////////
	
cleanup:
	
	[self setStatusString: NSLocalizedStringFromTableInBundle(@"Done.", nil, [NSBundle bundleForClass: [self class]], @"Status message shown after all metadata has been retrieved")];
	
	// done, let the delegate know
	del = [self delegate];
	[del didEndSearch: self];
	
	isSearching = NO;
	
	// cleanup nicely
	[pool release];
}


// informs us that we should stop searching. Since we're running in a thread we should check regularly
// if we have been cancelled
- (void) cancelSearch{
	// we simply set the bool that is checked after each batch in the respective query methods
	shouldContinueSearch = NO;
	[self setStatusString: NSLocalizedStringFromTableInBundle(@"Cancelling search...", nil, [NSBundle bundleForClass: [self class]], @"Status message shown while cancelling search.")];
}


#pragma mark -
#pragma mark Saved searches 

// NOT YET IMPLEMENTED IN PAPERS

// when a search is saved it will be regularly updated, only return those results that are new since the given date.
// NOTE that this method runs in a separate thread. Signal your progress to the delegate.
- (void) performSavedSearchWithQuery: (NSArray *)tokens afterDate: (NSDate *)date{
	// currently we simply invoke the whole thing:
	[self performSearchWithQuery: tokens];
	// once we implement this in the future we will make use of Pubmed's reldate parameter
	// we calculate the number of days we go back from the input date, we feed that as an
	// additional parameter into fetchInfoForQuery.
}


#pragma mark -
#pragma mark Related articles 

// return whether your plugin supports the retrieval of related articles or not.
- (BOOL) supportsRelatedArticles{
	return YES;
}

// return related articles in the same way you return search results.
// you will be passed the id as you set it during the search.
// NOTE: that this method runs in a separate thread. Signal your progress to the delegate.
// IMPORTANT: You can optionally add one extra parameter per paper which is a "score" (NSNumber between 0.0 and 1.0).
- (void) getRelatedArticlesForID: (NSString *)identifier{
	
	// Since we run threaded we need the autorelease pool!
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc]init];
	
	// Are we already searching?
	if(isSearching){
		//warning: CHECK WHAT HAPPENS IF CALLED AGAIN, AND CANCEL PREVIOUS ONE
	}
	// Now we are
	isSearching = YES;
	
	// Inform delegate we're about to start
	id <PapersSearchPluginDelegate> del = [self delegate];
	[del didBeginSearch: self];
	
	[self setStatusString: NSLocalizedStringFromTableInBundle(@"Connecting with MySearchEngine...", nil, [NSBundle bundleForClass: [self class]], @"Status message shown when plugin is connecting to the service")];
	
	// Get related articles here, report them to the delegate with:
	// [del didRetrieveObjects: [NSDictionary dictionaryWithObject: papers forKey: @"papers"]];
	
	
cleanup:
	
	[self setStatusString: NSLocalizedStringFromTableInBundle(@"Done.", nil, [NSBundle bundleForClass: [self class]], @"Status message shown after all metadata has been retrieved")];
	
	// done, let the delegate know
	del = [self delegate];
	[del didEndSearch: self];
	
	isSearching = NO;
	
	// cleanup nicely
	[pool release];
}


#pragma mark -
#pragma mark Cited by Articles

// return whether your plugin supports the retrieval of articles that cite a particular paper or not.
- (BOOL) supportsCitedByArticles{
	return NO;
}

// return articles that cite a particular paper in the same way you return search results.
// you will be passed the id as you set it during the search.
// NOTE: that this method runs in a separate thread. Signal your progress to the delegate.
- (void) getCitedByArticlesForID: (NSString *)identifier{}


#pragma mark -
#pragma mark Recent Articles

// These methods are used to find recently published articles for authors, journals or keywords
// Like with matching (see below) you can optimize for speed by returning a limited set of fields:
// - ID, Title, Name, Year, Volume, Issue, Pages, Authors, Journal, Publication Date (these are the minimum)
// In addition you can also return two other variables that replace a number of these
// fields which saves you from parsing complicated strings (this will be done anyway once the match is selected by the user:
// - tempAuthorString -> return a string of authors (see pubmed example) as a whole instead of all authors separately
// - tempJournalString -> return a single string representing the publication (e.g. "Nature 2005, vol. 16(2) pp. 400-123")
// if you return the latter you don't have to return the individual journal, volume, year, issue, pages fields, those will be ignored

// return recent articles for the provided author
// you will be passed a dictionary representation of the author during the search
// NOTE that this method runs in a separate thread. Signal your progress to the delegate.
- (void)recentArticlesForAuthor: (NSDictionary *)author{
	// Here we simply use the matching routines, we prepare a query by creating a tokenarray ourselves based on the author:
	// Since we run threaded we need the autorelease pool!
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc]init];
	
	NSDictionary *token = [self searchTokenForAuthor: author];
	if(token){
		[self performMatchWithQuery: [NSArray arrayWithObject: token]];
	}
	
	// Cleanup
	[pool release];
}

// return recent articles for the provided journal
// you will be passed a dictionary representation of the journal during the search
// NOTE that this method runs in a separate thread. Signal your progress to the delegate.
- (void)recentArticlesForJournal: (NSDictionary *)journal{
	// Here we simply use the matching routines, we prepare a query by creating a tokenarray ourselves based on the journal:
	// Since we run threaded we need the autorelease pool!
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc]init];
	
	NSDictionary *token = [self searchTokenForJournal: journal];
	if(token){
		[self performMatchWithQuery: [NSArray arrayWithObject: token]];
	}
	
	// Cleanup
	[pool release];
}

// return recent articles for the provided keyword
// you will be passed a dictionary representation of the keyword during the search
// NOTE that this method runs in a separate thread. Signal your progress to the delegate.
- (void)recentArticlesForKeyword: (NSDictionary *)keyword{
	// Here we simply use the matching routines, we prepare a query by creating a tokenarray ourselves based on the keyword:
	// Since we run threaded we need the autorelease pool!
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc]init];
	
	NSDictionary *token = [self searchTokenForKeyword: keyword];
	if(token){
		[self performMatchWithQuery: [NSArray arrayWithObject: token]];
	}
	
	// Cleanup
	[pool release];
}


#pragma mark -
#pragma mark Cleanup methods

// A method to check whether the search finished properly
// and one to get at any errors that resulted. See above for usage of errorCodes.
- (BOOL) successfulCompletion{
	// we simply check whether we caught an error
	return (searchError == nil);
}

- (NSError *) searchCompletionError{
	return searchError;
}

// let the plugin get rid of any data that needs to be reset for a new search.
- (void) performCleanup{
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
- (NSDictionary *)metadataForID: (NSString *)identifier{
	
	// do your thing to get the metadata, return them as follows
	// return [NSDictionary dictionaryWithObject: papers forKey:@"papers"];	
}

// return the metadata for the paper with the given identifier
// you will be passed the id as you set it during the search
// return nil if impossible to resolve
// NOTE that this method runs in a separate thread. Signal your progress to the delegate.
- (void)metadataForIDs: (NSArray *)identifiers{
	
	// Since we run threaded we need the autorelease pool!
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc]init];
	
	// Are we already searching?
	if(isSearching){
		//warning: CHECK WHAT HAPPENS IF CALLED AGAIN, AND CANCEL PREVIOUS ONE
	}
	// Now we are
	isSearching = YES;
	
	// Inform delegate we're about to start
	id <PapersSearchPluginDelegate> del = [self delegate];
	[del didBeginSearch: self];
	
	// Get the info for this query
	NSURLResponse *response = nil;
	NSError *err = nil;
	
	[self setStatusString: NSLocalizedStringFromTableInBundle(@"Fetching metadata...", nil, [NSBundle bundleForClass: [self class]], @"Status message shown while fetching metadata for given articles.")];
	
	// Do your stuff here to fetch the metadata asynchronously
	// report them to the delegate as done before (didRetrieveObjects:)
	
cleanup:
	
	[self setStatusString: NSLocalizedStringFromTableInBundle(@"Done.", nil, [NSBundle bundleForClass: [self class]], @"Status message shown after all metadata has been retrieved")];
	
	// done, let the delegate know
	del = [self delegate];
	[del didEndSearch: self];
	
	isSearching = NO;
	
	// cleanup nicely
	[pool release];
}



#pragma mark -
#pragma mark Follow up methods

// return the URL to the paper within the repository
// you will be passed the id as you set it during the search
// return nil if impossible to resolve
- (NSURL *)repositoryURLForID: (NSString *)identifier{
	// simply return a link to the webpage using the pmid
	//NSString *link = [NSString stringWithFormat: MYSEARCHENGINE_URL, identifier];
	NSString *link = [NSString stringWithFormat: @"MYSEARCHENGINE_URL", identifier];
	return [NSURL URLWithString: link];
}

// return the URL to the paper at the publisher's website, preferably fulltext
// you will be passed the id as you set it during the search
// return nil if impossible to resolve
- (NSURL *)publisherURLForID: (NSString *)identifier{
	return nil;
}

// return the URL to the PDF ofthe paper
// you will be passed the id as you set it during the search
// return nil if impossible to resolve
// IMPORTANT: if you return nil Papers will do its best to automatically retrieve the PDF on the basis of 
// the publisherURLForID as returned above. ONLY return a link for a PDF here if a) you are sure you
// know the location or b) you think you can do some fancy lookup that outperforms Papers build in attempts.
- (NSURL *)pdfURLForID: (NSString *)identifier{
	return nil;
}



/////////////////////////////////////////////////////////
#pragma mark -
#pragma mark Matching methods
/////////////////////////////////////////////////////////

// return the logo as will be displayed in the search box (this one is smaller than that for the search engine). 
// take a look at the sample plugins for examples. Suggested size 115w x 40h
- (NSImage *) small_logo{
	NSString *imagepath = [[NSBundle bundleForClass: [self class]] pathForResource: @"logo_mysearchengine_basic" ofType: @"tif"];
	return [[[NSImage alloc]initWithContentsOfFile: imagepath]autorelease];
}

// this method is the main worker method and launches the search process for matches.
// there's no difference with the performSearchWithQuery method above (you could use the same one),
// except that you can optimize for speed by returning a limited set of fields:
// - ID, Title, Name, Year, Volume, Issue, Pages, Authors, Journal, Publication Date (these are the minimum)
//
// In addition there a unique situation here that you can also return two other variable that replace a number of these
// fields which saves you from parsing complicated strings (this will be done anyway once the match is selected by the user:
// - tempAuthorString -> return a string of authors (see pubmed example) as a whole instead of all authors separately
// - tempJournalString -> return a single string representing the publication (e.g. "Nature 2005, vol. 16(2) pp. 400-123")
// if you return the latter you don't have to return the individual journal, volume, year, issue, pages fields, those will be ignored
//
// NOTE that this method runs in a separate thread. Signal your progress to the delegate.
// use the search protocols delegate methods
- (void) performMatchWithQuery: (NSArray *)tokens{
	
	// this closely follows the general performSearchWithQuery: except that we use the faster retrieval of summary (skipping things like
	// the abstract, and we only fetch a single batch of results.
	
	// alternatively if there's no easy way to generate more compact results, just use the general performSearchWithQuery.
	
	// Since we run threaded we need the autorelease pool!
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc]init];
	// Are we already searching?
	if(isSearching){
		//Warning: CHECK WHAT HAPPENS IF CALLED AGAIN, AND CANCEL PREVIOUS ONE
	}
	// Now we are
	isSearching = YES;
	
	// Generate the query from the tokens
	NSString *currentQuery = [self queryStringFromTokens: tokens prefix: nil];
	
	if(!currentQuery){
		NSMutableDictionary *userInfo = [NSMutableDictionary dictionary];
		[userInfo setObject: NSLocalizedStringFromTableInBundle(@"Could not create query from searchfield input", nil, [NSBundle bundleForClass: [self class]], @"Error message when query can't be created") forKey:NSLocalizedDescriptionKey];
		[userInfo setObject: NSLocalizedStringFromTableInBundle(@"Please ensure you have created a proper query.", nil, [NSBundle bundleForClass: [self class]], @"Recovery suggestion when query can't be created") forKey:NSLocalizedRecoverySuggestionErrorKey];		
		[self setSearchError: [NSError errorWithDomain: @"MySearchEngineController" code: 1 userInfo: userInfo]];
		goto cleanup;
	}
	
	// Inform delegate we're about to start
	id <PapersSearchPluginDelegate> del = [self delegate];
	[del didBeginSearch: self];
	
	[self setStatusString: NSLocalizedStringFromTableInBundle(@"Connecting with PubMed...", nil, [NSBundle bundleForClass: [self class]], @"Status message shown when plugin is connecting to the service")];
	
	////////////////////////////////////////
	// GET THE RESULTS HERE
	////////////////////////////////////////
	
cleanup:
	
	[self setStatusString: NSLocalizedStringFromTableInBundle(@"Done.", nil, [NSBundle bundleForClass: [self class]], @"Status message shown after all metadata has been retrieved")];
	
	// done, let the delegate know
	del = [self delegate];
	[del didEndSearch: self];
	
	isSearching = NO;
	
	// cleanup nicely
	[pool release];
}

// this method is called when the user has selected the right paper, you will be passed the identifier (as you set it
// during the initial search, and you have to return the full metadata for the paper (as rich as possible).
// return the usual dictionary with a papers array containing a SINGLE entry or nil if the identifier cannot be resolved.
// NOTE that this method runs in a separate thread. Signal your progress to the delegate.
// use the above delegate methods
- (void) performMatchForID: (NSString *)identifier{
	// Since we run threaded we need the autorelease pool!
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc]init];
	
	// This is the same as the metadataForIds method, we use that one
	[self metadataForIDs: [NSArray arrayWithObject: identifier]];
	
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
- (void) performAutoMatchForPaper: (NSDictionary *)paper{
	
	// Since we run threaded we need the autorelease pool!
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc]init];
	
	NSString *pmid = nil;
	
	// Inform delegate we're about to start
	id <PapersSearchPluginDelegate> del = [self delegate];
	[del didBeginSearch: self];
	
	// DO YOUR AUTOMATCHING HERE
success:
	// send the result over (if we found one), skipping the other options
	if(pmid){
		// get the metadata
		NSDictionary *metadata = [self metadataForID: pmid];
		if(metadata){
			// Hand them to the delegate in the usual format
			[del didRetrieveObjects: [NSDictionary dictionaryWithObject: [NSArray arrayWithObject: metadata] forKey: @"papers"]];
		}
	}
	
	[self setStatusString: NSLocalizedStringFromTableInBundle(@"Done.", nil, [NSBundle bundleForClass: [self class]], @"Status message shown after all metadata has been retrieved")];
	
	// done, let the delegate know
	del = [self delegate];
	[del didEndSearch: self];
	
	isSearching = NO;
	
	[pool release];
	
}

@end



/////////////////////////////////////////////////////////
#pragma mark -
// these are methods that are specific to this plugin and 
// are not required per se by the plugin protocol
/////////////////////////////////////////////////////////


@implementation mmDBLPSearchEngine (private)


// this method converts the raw MTSearchToken objects as we get them from the search field into a 
// query string
- (NSString *)queryStringFromTokens: (NSArray *)tokens 
							 prefix: (NSString *)prefix{
	
	NSMutableString *the_query = [NSMutableString stringWithCapacity: 1024];
	
	// iterate over the tokens to generate the querystring
	NSEnumerator *e = [tokens objectEnumerator];
	id token;
	BOOL first = YES;
	while(token = [e nextObject]){
		// convert your tokens here to a string or any other representation you need.
	}
	return the_query;
}




/////////////////////////////////////////////////////////
#pragma mark Helper Methods
/////////////////////////////////////////////////////////

// Examples of how to create a fake "token" as a convenience
// method for the recentArticlesFor methods.

- (NSDictionary *)searchTokenForAuthor: (NSDictionary *)author{
	if(!author || ![author valueForKey: @"lastName"]) return nil;
	
	NSString *lastname  = [author valueForKey: @"lastName"];
	NSString *firstname = [author valueForKey: @"firstName"];
	NSString *initials = [author valueForKey: @"initials"];
	
	NSString *query = nil;
	if(firstname && [firstname length]>1)
		query = [NSString stringWithFormat: @"%@, %@", lastname, firstname];
	else if(initials && [initials length]>1)
		query = [NSString stringWithFormat: @"%@ %@", lastname, initials];
	else
		query = lastname;
	
	// we mimic a real MTQueryTermToken (see protocol) by creating a dictionary with the same keys so like an MTQueryTermToken the object will
	// listen to valueForKey: @"query" for example. This way we can reuse the performSearchWithQuery method.
	NSDictionary *dict = [[NSDictionary alloc]initWithObjectsAndKeys: [query stringByRemovingAccents], @"token", 
						  @"Author", @"field", 
						  @"[AU]", @"code", 
						  @"Include", @"operatorType", 
						  @"AND", @"operatorCode", 
						  [NSNumber numberWithBool: NO], @"predefined", nil];
	
	return [dict autorelease];
}

- (NSDictionary *)searchTokenForJournal: (NSDictionary *)journal{
	if(!journal) return nil;
	
	NSString *name  = [journal valueForKey: @"name"];
	NSString *abbr = [journal valueForKey: @"abbreviation"];
	
	NSString *query = nil;
	if(abbr && [abbr length]>1)
		query = abbr;
	else
		query = name;
	
	// we mimic a real MTQueryTermToken (see protocol) by creating a dictionary with the same keys so like an MTQueryTermToken the object will
	// listen to valueForKey: @"query" for example. This way we can reuse the performSearchWithQuery method.
	NSDictionary *dict = [[NSDictionary alloc]initWithObjectsAndKeys: query, @"token", 
						  @"Journal", @"field", 
						  @"[TA]", @"code", 
						  @"Include", @"operatorType", 
						  @"AND", @"operatorCode", 
						  [NSNumber numberWithBool: NO], @"predefined", nil];
	
	return [dict autorelease];
}

- (NSDictionary *)searchTokenForKeyword: (NSDictionary *)keyword{
	if(!keyword) return nil;
	
	// we mimic a real MTQueryTermToken (see protocol) by creating a dictionary with the same keys so like an MTQueryTermToken the object will
	// listen to valueForKey: @"query" for example. This way we can reuse the performSearchWithQuery method.
	NSDictionary *dict = [[NSDictionary alloc]initWithObjectsAndKeys: [keyword valueForKey: @"name"], @"token", 
						  @"MeSH Term", @"field", 
						  @"[MH]", @"code", 
						  @"Include", @"operatorType", 
						  @"AND", @"operatorCode", 
						  [NSNumber numberWithBool: NO], @"predefined", nil];
	
	return [dict autorelease];
}

@end


