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

	// caches
	NSDictionary *cachedPredefinedSearchTerms;
	NSDictionary *cachedSearchFields;
	NSArray *cachedStopwords;
@end

@interface mmDBLPSearchEngine (dblp_methods)
-(NSArray*)parseArticleData:(NSDictionary*)data withAuthors:(NSDictionary*)authorData andAbstract:(NSDictionary*)abstractData;
@end


// here is where the implementation of the plugin starts and where the different
// protocol methods are provided.
@implementation mmDBLPSearchEngine

#pragma mark - 
#pragma mark Init

-(id)init {
    self = [super init];
	if (self != nil) {
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

-(void)awakeFromNib {
	// setup nib if necessary, here we initialize the preferences
	NSUserDefaults *prefs = [NSUserDefaults standardUserDefaults];
	if (![prefs objectForKey:@"mm_dblp_itemsPerPage"])
		[prefs setObject:[NSNumber numberWithInt:30] 
				  forKey:@"mm_dblp_itemsPerPage"];
	if (![prefs objectForKey:@"mm_dblp_shouldAutocomplete"])
		[prefs setObject:[NSNumber numberWithBool:NO] 
				  forKey:@"mm_dblp_shouldAutocomplete"];
}

-(void)dealloc {
    // cleanup last items here
	// 
	// NOTE: most items are cleaned in the performCleanup:method, which is 
	// called after each run. The dealloc method is only called when the plugin 
	// is unloaded, which is only when the app quits.
	
	// clear the caches
	[cachedPredefinedSearchTerms release];
	[cachedSearchFields release];
	[cachedStopwords release];
	
    [super dealloc];
}



#pragma mark -
#pragma mark Accessors

// gives you a handle to the delegate object to which you deliver results and 
// notify progress (see above) - do not retain the delegate
-(id)delegate {
	return delegate;
}

-(void)setDelegate:(id)newDelegate {
	delegate = newDelegate;
}

// number of items that are fetched per batch, default is set by Papers but can 
// be overridden internally.
// 
// NOTE: Only applies to the performSearchWithQuery:method
-(NSNumber*)itemsPerPage {
	return (itemsPerPage ? itemsPerPage:[[NSUserDefaults standardUserDefaults]objectForKey:@"mm_dblp_itemsPerPage"]);
}

-(void)setItemsPerPage:(NSNumber*)newItemsPerPage {
	[newItemsPerPage retain];
	[itemsPerPage release];
	itemsPerPage = newItemsPerPage;
}

// the offset we have to start fetching from. This is set by Papers before the 
// search is started and used when the user wishes to get the next page of results. 
// 
// NOTE: Only applies to the performSearchWithQuery:method
-(NSNumber*)itemOffset {
	return itemOffset;
}

-(void)setItemOffset:(NSNumber*)newItemOffset {
	[newItemOffset retain];
	[itemOffset release];
	itemOffset = newItemOffset;
}

// return the number of items found for this query, this is the total number 
// even if you fetch only one page
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
// As long as this value is nil an indeterminate progress bar is shown, the 
// moment you return a non-nil value for both the progress will be shown to the 
// user. Use in combination with the delegate method updateStatus:to push 
// changes to the delegate and force an update.
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

// here we keep track of what we have retrieved thusfar since we work in batches
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

-(void)incrementRetrievedItemsWith:(int)value {
	int old = [[self retrievedItems]intValue];
	[self setRetrievedItems:[NSNumber numberWithInt:old+value]];
}

// Return the current status of your plugin to inform the user. We use it in 
// combination with the delegate method updateStatus: to push changes to the 
// delegate and force an update.
//
// The statusstring is stored here such that the delegate can retrieve it
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

// A method to check whether the search finished properly and one to get at any 
// errors that resulted. See above for usage of errorCodes.
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

// Name returns a string which is shown in the source list and used throughout 
// the UI. Make sure there are no naming collisions with existing plugins and 
// keep the name rather short.
-(NSString*)name {
	return NSLocalizedStringFromTableInBundle(@"DBLP", nil, [NSBundle bundleForClass:[self class]], @"Localized name of the service");
}

// Allows to return a color for your plugin, here blue for Pubmed.
// 
// Note: In the plugin test application you can click on the statusbar in the 
// config panel to get a color picker that helps you pick a color for the 
// statusbar. The color will be updated and logged into the console so that it 
// can be entered here.
-(NSColor*)color {
	return [NSColor colorWithCalibratedRed:136.0/255.0
									 green:169.0/255.0
									  blue:249.0/255.0
									 alpha:1.0];	
}

// return the logo as will be displayed in the search box. take a look at the 
// sample plugins for examples. Suggested size 250w x 50h.
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
// the key is the meny item name, if the value is a dictionary it will create a 
// submenu, if the value is a string it will be the searchterm that will be 
// filled in upon selection.
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
-(NSDictionary*)predefinedSearchTerms {
	if (!cachedPredefinedSearchTerms) {
		NSString *dictpath = [[NSBundle bundleForClass:[self class]] pathForResource:@"DBLPPredefinedTokens" ofType:@"plist"];
		cachedPredefinedSearchTerms = [[NSDictionary alloc]initWithContentsOfFile:dictpath];
	}
	return cachedPredefinedSearchTerms;
}

// return a dictionary of searchfield codes that show up as choices in the 
// searchtokens the dictionary should contain an array under key "order" and a 
// dictionary under the key "fields" containing key-value pairs where the key 
// is the name of the field and the value a code that your plugin can translate 
// into the right parameters. We advise to adopt the dblp model of field codes.

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
-(NSDictionary*)searchFields {
	if (!cachedSearchFields) {
		NSString *dictpath = [[NSBundle bundleForClass:[self class]] pathForResource:@"DBLPSearchFields" ofType:@"plist"];
		cachedSearchFields = [[NSDictionary alloc]initWithContentsOfFile:dictpath];
	}
	return cachedSearchFields;
}



#pragma mark Auto-completion

// return yes if you wish to autocomplete searchterms
// if you do autocompletion via the internet, be sure to check the server is up!
- (BOOL)autocompletesSearchTerms {
	return NO;
}
// return an array of strings for the partial string, make sure this stuff works fast!
- (NSArray*)autocompletionsForPartialString:(NSString*)str {
	return [NSArray new];
}



#pragma mark -
#pragma mark Searching

// a method to make sure everything's set to go before starting, do some setup 
// or tests here if necessary. and a method to find out what the problems are 
// if things aren't set. See above for usage of errorCodes. for instance return 
// an error when the service is not up.
-(BOOL)readyToPerformSearch {
	// do some setup here if necessary
	shouldContinueSearch = YES;
	[self setSearchError:nil];
	[self setItemsFound:[NSNumber numberWithInt:0]];
	[self setRetrievedItems:[NSNumber numberWithInt:0]];
	return YES;	
}

-(NSError*)searchPreparationError {
	// here we simple return searchError, if something went wrong before we 
	// would have set it to a non-nil value.
	return searchError;
}

// used for the history items and saved folders in the
-(NSString*)descriptiveStringForQuery:(NSArray*)tokens {
	if (tokens)
		return [[tokens valueForKey:@"displayString"]componentsJoinedByString:@"+"];
	else
		return @"";
}

// return YES if you support cancelling the current search session (strongly advised).
-(BOOL)canCancelSearch {
	return YES; 
}

// this method is the main worker method and launches the search process, here 
// you are handed over the MTQueryTermTokens that were entered in the searchfield. 
// the tokens have the following key-value compliant fields:
//   NSString *token;        - The searchterm like the user entered it
//   NSString *field;        - The field that was selected
//   NSString *code;         - The code that belongs to the selected field
//   NSString *operatorType; - The operator type (AND, NOT, OR)
//   NSNumber *predefined;   - A boolean NSNumber that indicates whether the 
//                             token was predefined.
//
// also you are handed the offset you have to start from, the first time for a 
// new query this will always be 0 subsequent pages are fetched by calling this 
// method with an offset which represents the last number of the last number of 
// items you returned. So if you fetched the first time 30 papers, the next 
// time the offset will be 30 for the next page of results. 
//
// IMPORTANT: try to always sort results on publication date!
//
// NOTE: that this method runs in a separate thread. Signal your progress to 
//       the delegate.
-(void)performSearchWithQuery:(NSArray*)tokens {
	// Since we run threaded we need the autorelease pool!
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc]init];
	
	// Are we already searching?
	if (isSearching) {
		// Warning: CHECK WHAT HAPPENS IF CALLED AGAIN, AND CANCEL PREVIOUS ONE
	}
	// Now we are
	isSearching = YES;
	
	// Generate the query from the tokens
	/*
	NSString *currentQuery = [self queryStringFromTokens:tokens prefix:nil];
	if (!currentQuery) {
		NSMutableDictionary *userInfo = [NSMutableDictionary dictionary];
		[userInfo setObject:NSLocalizedStringFromTableInBundle(@"Could not create query from searchfield input", nil, [NSBundle bundleForClass:[self class]], @"Error message when query can't be created") forKey:NSLocalizedDescriptionKey];
		[userInfo setObject:NSLocalizedStringFromTableInBundle(@"Please ensure you have created a proper query.", nil, [NSBundle bundleForClass:[self class]], @"Recovery suggestion when query can't be created") forKey:NSLocalizedRecoverySuggestionErrorKey];		
		[self setSearchError:[NSError errorWithDomain:@"DBLPSearchController" code:1 userInfo:userInfo]];
		goto cleanup;
	}
	*/
	
	NSMutableString *currentQuery = [[NSMutableString alloc] init];
	NSEnumerator *e = [tokens objectEnumerator];
	id token;
	while (token = [e nextObject]) {
		[currentQuery appendString:[token valueForKey:@"token"]];
		[currentQuery appendString:@" "];
		//NSLog(@"%@", [token valueForKey:@"token"]);
		//NSLog(@"%@", [token valueForKey:@"code"]);
		//NSLog(@"%@", [token valueForKey:@"operatorCode"]);
	}
	if (!currentQuery) {
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
	
	all_publications_keywords_year* ws = [[all_publications_keywords_year alloc] init];
	[ws setParameters:currentQuery 
		 in_startYear:[NSNumber numberWithInteger:0] 
		   in_endYear:[NSNumber numberWithInteger:0] 
			 in_limit:[NSNumber numberWithInteger:1000]];
	NSDictionary *result = [ws resultValue];
	
	[self setStatusString:NSLocalizedStringFromTableInBundle(@"Connected to DBLP...", nil, [NSBundle bundleForClass:[self class]], @"Status message shown when the plugin has succesfully connected to the service")];
	
	// Store the number of total articles matching the query
	if ([result count] > 0) {
		[self setItemsFound:[NSNumber numberWithInteger:[result count]]];
		[del didFindResults:self];
	}
	
	// Check whether we got anything at all
	if ([result count] == 0) {
		[self setStatusString:NSLocalizedStringFromTableInBundle(@"No Papers found.", nil, [NSBundle bundleForClass:[self class]], @"Status message shown when no results were found for the query")];
		goto cleanup;	
	}
	
	////////////////////////////////////////
	// FETCHING ACTUAL RESULTS (METADATA)
	////////////////////////////////////////
	
	[self setStatusString:NSLocalizedStringFromTableInBundle(@"Fetching Papers...", nil, [NSBundle bundleForClass:[self class]], @"Status message shown while fetching the metadata for the found papers")];
	
	NSEnumerator *enumerator = [result objectEnumerator];
	id current = nil;
	[self setRetrievedItems:[NSNumber numberWithInt:0]];
	[self setItemsToRetrieve:[NSNumber numberWithInteger:[result count]]];	
	while ([[self itemsToRetrieve] integerValue] > 0) {
		current = [enumerator nextObject];
		// update status
		[self setStatusString:[NSString stringWithFormat:NSLocalizedStringFromTableInBundle(@"Fetching Paper %d of %d...", nil, [NSBundle bundleForClass:[self class]], @"Status message shown while fetching the metadata for the specified papers"), 
							   [[self retrievedItems] integerValue], [[self itemsFound] integerValue]]];
		
		// check whether we have been cancelled
		if(!shouldContinueSearch){	
			goto cleanup;	
		}
		
		// fetch authors
		NSDictionary *authors = nil;
		if ([current objectForKey:@"dblp_key"]) {
			publication_authors* ws = [[publication_authors alloc] init];
			[ws setParameters:[current objectForKey:@"dblp_key"]];
			authors = [ws resultValue];
		} 
		
		// fetch abstract (and bibtex)
		NSDictionary *abstract = nil;
		if ([current objectForKey:@"dblp_key"]) {
			publication_data2* ws = [[publication_data2 alloc] init];
			[ws setParameters:[current objectForKey:@"dblp_key"]];
			abstract = [ws resultValue];
		} 
		
		// Parse the data
		NSArray *papers = [self parseArticleData:current withAuthors:authors andAbstract:abstract];
		
		// Check whether we got anything at all
		if ([papers count] == 0) {
			[self setStatusString:NSLocalizedStringFromTableInBundle(@"No Papers found.", nil, [NSBundle bundleForClass:[self class]], @"Status message shown when no results were found for the query")];
			goto cleanup;	
		}
		
		// Hand them to the delegate
		[del didRetrieveObjects:[NSDictionary dictionaryWithObject:papers forKey:@"papers"]];
		
		// Update count
		[self incrementRetrievedItemsWith:[[self retrievedItems] intValue]+1];		
		[self setItemsToRetrieve:[NSNumber numberWithInt:[[self itemsFound] intValue]-[[self retrievedItems] intValue]]];
	}
	
cleanup:
	
	[self setStatusString:NSLocalizedStringFromTableInBundle(@"Done.", nil, [NSBundle bundleForClass:[self class]], @"Status message shown after all metadata has been retrieved")];
	
	// done, let the delegate know
	del = [self delegate];
	[del didEndSearch:self];
	
	[ws release];
	[currentQuery release];
	
	isSearching = NO;
	
	// cleanup nicely
	[pool release];
}

// informs us that we should stop searching. Since we're running in a thread we 
// should check regularly if we have been cancelled
-(void)cancelSearch {
	// we simply set the bool that is checked after each batch in the 
	// respective query methods
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
	
}

// return recent articles for the provided journal
// you will be passed a dictionary representation of the journal during the search
// NOTE that this method runs in a separate thread. Signal your progress to the delegate.
-(void)recentArticlesForJournal:(NSDictionary*)journal{
	
}

// return recent articles for the provided keyword
// you will be passed a dictionary representation of the keyword during the search
// NOTE that this method runs in a separate thread. Signal your progress to the delegate.
-(void)recentArticlesForKeyword:(NSDictionary*)keyword{
	
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
	[itemsPerPage release], itemsPerPage = nil;
	[itemOffset release], itemOffset = nil;
	[itemsFound release], itemsFound = nil;
	[itemsToRetrieve release], itemsToRetrieve = nil;
	[retrievedItems release], retrievedItems = nil;
	[statusString release], statusString = nil;
	[searchError release], searchError = nil;
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
	return [NSDictionary new];
}

// return the metadata for the paper with the given identifier
// you will be passed the id as you set it during the search
// return nil if impossible to resolve
// NOTE that this method runs in a separate thread. Signal your progress to the delegate.
-(void)metadataForIDs:(NSArray*)identifiers{
	
}



#pragma mark Follow-up

// return the URL to the paper within the repository
// you will be passed the id as you set it during the search
// return nil if impossible to resolve
-(NSURL*)repositoryURLForID:(NSString*)identifier {
	return [NSURL new];
}

// return the URL to the paper at the publisher's website, preferably fulltext
// you will be passed the id as you set it during the search
// return nil if impossible to resolve
- (NSURL*)publisherURLForID:(NSString*)identifier {
	return [NSURL new];
}

// return the URL to the PDF ofthe paper
// you will be passed the id as you set it during the search
// return nil if impossible to resolve
// IMPORTANT: if you return nil Papers will do its best to automatically retrieve the PDF on the basis of 
// the publisherURLForID as returned above. ONLY return a link for a PDF here if a) you are sure you
// know the location or b) you think you can do some fancy lookup that outperforms Papers build in attempts.
- (NSURL*)pdfURLForID: (NSString *)identifier {
	return [NSURL new];
}

#pragma mark -
#pragma mark Matching methods

// return the logo as will be displayed in the search box (this one is smaller than that for the search engine). 
// take a look at the sample plugins for examples. Suggested size 115w x 40h
-(NSImage*)small_logo {
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
	
}

// this method is called when the user has selected the right paper, you will be passed the identifier (as you set it
// during the initial search, and you have to return the full metadata for the paper (as rich as possible).
// return the usual dictionary with a papers array containing a SINGLE entry or nil if the identifier cannot be resolved.
// NOTE that this method runs in a separate thread. Signal your progress to the delegate.
// use the above delegate methods
-(void) performMatchForID:(NSString*)identifier{
	
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
	
}

@end

@implementation mmDBLPSearchEngine (dblp_methods)

-(NSArray*)parseArticleData:(NSDictionary*)data withAuthors:(NSDictionary*)authorData andAbstract:(NSDictionary*)abstractData {
	NSEnumerator *enumerator = nil;
	NSDictionary *item = nil;
	
	NSMutableArray *papers = [NSMutableArray arrayWithCapacity:100];
	NSMutableDictionary *paper = [NSMutableDictionary dictionaryWithCapacity:50];
	
	// built in keys
	
	if ([data objectForKey:@"title"] && ![@"" isEqualToString:[data objectForKey:@"title"]]) {
		//NSLog(@"%@", [data objectForKey:@"title"]);
		[paper setValue:[data objectForKey:@"title"] forKey:@"title"];
	}
	
	if ([data objectForKey:@"year"] && ![@"" isEqualToString:[data objectForKey:@"year"]]) {
		//NSLog(@"%@", [data objectForKey:@"year"]);
		[paper setValue:[NSNumber numberWithInteger:[[data objectForKey:@"year"] integerValue]] forKey:@"year"];
	}
	
	if ([data objectForKey:@"month"] && ![@"" isEqualToString:[data objectForKey:@"month"]]) {
		//NSLog(@"%@", [data objectForKey:@"month"]);
		//[paper setValue:[NSNumber numberWithInteger:[[data objectForKey:@"month"] integerValue]] forKey:@"month"];
		[paper setValue:[data objectForKey:@"month"] forKey:@"month"];
	}
	
	if ([data objectForKey:@"doi"] && ![@"" isEqualToString:[data objectForKey:@"doi"]]) {
		//NSLog(@"%@", [data objectForKey:@"doi"]);
		[paper setValue:[data objectForKey:@"doi"] forKey:@"doi"];
	}
	
	if ([data objectForKey:@"pages"] && ![@"" isEqualToString:[data objectForKey:@"pages"]]) {
		//NSLog(@"%@", [data objectForKey:@"pages"]);
		[paper setValue:[data objectForKey:@"pages"] forKey:@"pages"];
	}
	
	if ([data objectForKey:@"conference"] && ![@"" isEqualToString:[data objectForKey:@"conference"]]) {
		//NSLog(@"%@", [data objectForKey:@"conference"]);
		[paper setValue:[data objectForKey:@"conference"] forKey:@"conference"];
	}
	
	/*if ([data objectForKey:@"volume"] != nil && ![@"" isEqualToString:[data objectForKey:@"volume"]]) {
		NSLog(@"volume: --%@--", [data objectForKey:@"volume"]);
		[paper setValue:[data objectForKey:@"volume"] forKey:@"volume"];
	 }*/
	
	if ([data objectForKey:@"ee"] && ![@"" isEqualToString:[data objectForKey:@"ee"]]) {
		//NSLog(@"%@", [data objectForKey:@"ee"]);
		[paper setValue:[data objectForKey:@"ee"] forKey:@"url"];
		
		// if PDF is available
		NSString *regex = @"^.*pls$";
		NSPredicate *regextest = [NSPredicate predicateWithFormat:@"SELF MATCHES %@", regex];
		if ([regextest evaluateWithObject:[data objectForKey:@"ee"]] == YES) {
			[paper setValue:[data objectForKey:@"ee"] forKey:@"path"];
		}
	}
	
	
	
	// additional
	
	if ([data objectForKey:@"dblp_key"] && ![@"" isEqualToString:[data objectForKey:@"dblp_key"]]) {
		//NSLog(@"%@", [data objectForKey:@"dblp_key"]);
		[paper setValue:[data objectForKey:@"dblp_key"] forKey:@"dblp_key"];
	}
	
	
	// abstract
	
	if ([abstractData valueForKey:@"abstract"] != nil && [[abstractData valueForKey:@"abstract"] objectAtIndex:0]) {
		//NSLog(@"%@", [abstractData valueForKey:@"abstract"]);
		[paper setValue:[[abstractData valueForKey:@"abstract"] objectAtIndex:0] forKey:@"abstract"];
	}
	
	/*
	if ([abstractData valueForKey:@"abstract"] && ![@"<null>\n" isEqualToString:[abstractData valueForKey:@"abstract"]]) {
		//NSLog(@"%@", [abstractData valueForKey:@"abstract"]);
		[paper setValue:[NSString stringWithFormat:@"%@",[[abstractData valueForKey:@"abstract"] objectAtIndex:0]] forKey:@"abstract"];
	}
	*/
	/*
	// bibtex
	// just save it, maybe I need it later for export...
	if ([abstractData objectForKey:@"bibtex"] && ![@"" isEqualToString:[abstractData objectForKey:@"bibtex"]]) {
		NSLog(@"%@", [abstractData objectForKey:@"bibtex"]);
		[paper setValue:[abstractData objectForKey:@"bibtex"] forKey:@"bibtex"];
	}
	*/
	
	
	// authors array
	
	NSMutableArray *authors = [NSMutableArray arrayWithCapacity:100];
	enumerator = [authorData objectEnumerator];
	while ((item = [enumerator nextObject])) {
		NSMutableDictionary *author = [NSMutableDictionary dictionaryWithCapacity:50];
		
		if ([item objectForKey:@"author"] && ![@"" isEqualToString:[item objectForKey:@"author"]]) {
			//NSLog(@"%@", [item objectForKey:@"author"]);
			
			NSCharacterSet *whitespace = [NSCharacterSet whitespaceCharacterSet];
			NSArray *parts = [[item objectForKey:@"author"] componentsSeparatedByCharactersInSet:whitespace];
			
			int n = [parts count];
			if (n == 1) {
				[author setValue:[item objectForKey:@"author"] forKey:@"lastName"];
			} else if (n >= 2) {
				int last = n - 1;
				
				NSMutableString *firstNames = [NSMutableString stringWithString:@""];
				NSMutableString *initials = [NSMutableString stringWithString:@""];
				int i = 0;
				for (i=0; i<last; i++) {
					[firstNames appendString:[parts objectAtIndex:i]];
					[initials appendString:[[parts objectAtIndex:i] substringToIndex:1]];
				}
				[author setValue:firstNames forKey:@"firstName"];
				[author setValue:initials forKey:@"initials"];
				
				[author setValue:[parts objectAtIndex:last] forKey:@"lastName"];
			} else {
				[author setValue:[item objectForKey:@"author"] forKey:@"lastName"];
			}
		}
		
		
		
		
		/*AUTHORS
		 - correspondence
		 - email
		 - firstName
		 - homepage
		 - initials
		 - lastName - required
		 - mugshot (NSImage)
		 - nickName
		 - notes*/
		
		// test
		if (author)
			[authors addObject:author];
		
	}
	if ([authors count] > 0)
		[paper setValue:authors forKey:@"authors"];
	
	
	
	// journals array
	
	NSMutableArray *journals = [NSMutableArray arrayWithCapacity:100];
	enumerator = [authorData objectEnumerator];
	while ((item = [enumerator nextObject])) {
		NSMutableDictionary *journal = [NSMutableDictionary dictionaryWithCapacity:50];
		
		if ([item objectForKey:@"source"] && ![@"" isEqualToString:[item objectForKey:@"source"]]) {
			//NSLog(@"%@", [item objectForKey:@"source"]);
			[journal setValue:[item objectForKey:@"source"] forKey:@"name"];
		}
		
		if ([item objectForKey:@"publisher"] && ![@"" isEqualToString:[item objectForKey:@"publisher"]]) {
			//NSLog(@"%@", [item objectForKey:@"publisher"]);
			[journal setValue:[item objectForKey:@"publisher"] forKey:@"publisher"];
		}
		
		if ([item objectForKey:@"number"] && ![@"" isEqualToString:[item objectForKey:@"number"]]) {
			//NSLog(@"%@", [item objectForKey:@"number"]);
			[journal setValue:[item objectForKey:@"number"] forKey:@"currentissue"];
		}
		
		// test
		if (journal)
			[journals addObject:journal];
		
	}
	if ([journals count] > 0)
		[paper setValue:journals forKey:@"journals"];
	
	
	// publicationTypes array
	/*
	NSMutableArray *publicationTypes = [NSMutableArray arrayWithCapacity:100];
	enumerator = [authorData objectEnumerator];
	while ((item = [enumerator nextObject])) {
		NSMutableDictionary *publicationType = [NSMutableDictionary dictionaryWithCapacity:50];
		
		if ([item objectForKey:@"type"] && ![@"" isEqualToString:[item objectForKey:@"type"]]) {
			//NSLog(@"%@", [item objectForKey:@"type"]);
			[publicationType setValue:[item objectForKey:@"type"] forKey:@"name"];
		}
		
		// test
		if (publicationType)
			[publicationTypes addObject:publicationType];
		
	}
	if ([publicationTypes count] > 0)
		[paper setValue:publicationTypes forKey:@"publicationTypes"];
	*/
	
	
	// complete... let's return it
	if (paper)
		[papers addObject:paper];
	
	return papers;
}

@end
