//
//  PapersSearchPluginProtocol.h
//
//  Created by Alexander Griekspoor on Fri Jan 23 2007.
//  Copyright (c) 2007 Mekentosj.com. All rights reserved.
// 
//  For use outside of the Papers application structure, please contact
//  feedback@mekentosj.com
//  DO NOT REDISTRIBUTE WITHOUT ALL THE FILES THAT ARE CONTAINED IN THE PACKAGE THAT INCLUDED THIS FILE

#import <Cocoa/Cocoa.h>

/////////////////////////////////////////////////////////////

/*  Searching repositories
Papers allows you through this protocol to write your own search plugins.

Note that this file contains three protocols:
@protocol PapersSearchPluginProtocol	- REQUIRED
@protocol PapersMatchPluginProtocol		- OPTIONAL
@protocol PapersAutoMatchPluginProtocol	- OPTIONAL
This allows you to create a plugin that can not only be used as search engine,
but also for matching and auto-matching of papers. The first protocol is required,
the other two are optional. Papers will automatically check which features your
plugin supports.

It's important to note that the plugin's method performSearchWithQuery: runs in 
its own thread, although you normally would not have to worry about that, keep 
in mind that if you do fancy stuff you use "performMethodOnMainThread: to prevent
trouble. The plugin signals it's progress to the delegate using a number of delegate 
methods. Make sure you ALWAYS call the delegate methods to signal your progress.
A normal cycle of the plugin would be:

Delegate -> Plugin		- (BOOL) readyToPerformSearch;								// Is the plugin Ready, if not importPreparationError is retrieved.

Delegate -> Plugin		- (NSString *)descriptiveStringForQuery: (NSArray *)tokens;	 // Delegate uses this to update UI

Delegate -> Plugin		- (void) performSearchWithQuery: (NSArray *)query;			// Delegate provides plugin with query, initiates search.
	
		Delegate <- Plugin		- (void)didBeginSearch:(id)sender;					// Plugin informs delegate that it has started.

		Delegate <- Plugin		- (void)didRetrieveObjects:(NSDictionary *)dict;	// Plugin hands over found paper to delegate (optionally repeated).

		Delegate <- Plugin		- (void)didEndSearch: (id)sender;					// Plugin signals it's done.

Delegate -> Plugin		- (BOOL) successfulCompletion;								// Delegate asks plugin if success, if not searchCompletionError is retrieved.

Delegate -> Plugin		- (void) performCleanup;									// Allows the plugin to cleanup and reset for next import.

The structure of the dictionary containing retrieved objects is as follows. Note that you are 
encouraged to fill as many of these fields as you can. You can also provide other fields if 
you wish but these will be ignored within Papers in the current version. Potential 
other programs that also use these plugins might use this info though. 
NOTE: you do not have to list all fields except those marked as obligatory

Note that at the root of the dictionary you can provide one or more arrays named:
- papers, an array containing dictionaries representing a paper.
- authors, an array containing dictionaries representing an author.
- journals, an array containing dictionaries representing a journal.
- keywords, an array containing dictionaries representing a keyword.
- publicationTypes, an array containing dictionaries representing a publication type.

Each can only occur once (!) and contains an array of the corresponding model dictionaries below.
Usually you will only return Papers, but in case you would like to import a list of journals
or authors irrespective outside the context of a paper this is the way to do it.

NOTE: IF YOU ADD AN AUTHOR, JOURNAL, KEYWORD, OR PUBLICATION TYPE TO A PAPER, DON'T ADD IT
SEPARATELY AGAIN IN THE AUTHORS, JOURNALS, KEYWORDS, or PUBLICATION TYPES ARRAYS!! ONLY USE
THE OTHER CATEGORIES IF YOU DON'T IMPORT PAPERS OR IF YOU ADD EXTRA MODEL OBJECTS NOT 
ASSOCIATED TO THE PAPERS YOU IMPORTED.

Below follows an example for each category
Unless otherwise noted NSStrings are expected for all field  

////////////////
IMPORTANT NOTE
Papers does not yet support different types than journal articles, 
this will change in version 2.0 and we will adapt some of the fields for this.
////////////////

AUTHORS
- correspondence
- email
- firstName
- homepage
- initials
- lastName - required
- mugshot (NSImage)
- nickName
- notes

Example: 

<key>authors</key>
<array>
	<dict>
		<key>correspondence</key>
		<string>The European Bioinformatics Institute</string>
		<key>email</key>
		<string>mek@mekentosj.com</string>
		<key>firstName</key>
		<string>Alexander</string>
		<key>homepage</key>
		<string>http://mekentosj.com</string>
		<key>initials</key>
		<string>AC</string>
		<key>lastName</key>
		<string>Griekspoor</string>
		<key>mugshot</key>
		NSImage object
		<key>nickName</key>
		<string>Mek</string>
		<key>notes</key>
		<string>These are example notes</string>
	</dict>
	<dict>
		.. next author ..
	</dict>
</array>


JOURNALS
- abbreviation
- archives
- authorGuidelines
- cover (NSImage)
- currentissue
- etoc
- homepage
- impactFactor (NSNumber - Float)
- issn
- language
- name - required
- nlmID
- notes
- openAccess (NSNumber - BOOL)
- publisher
- startYear (NSNumber - Int)
- summary

Example: 

<key>journals</key>
<array>
	<dict>
		<key>abbreviation</key>
		<string>PLoS Biol.</string>
		<key>archives</key>
		<string>http://biology.plosjournals.org/perlserv/?request=get-archive&amp;issn=1545-7885</string>
		<key>authorGuidelines</key>
		<string>http://journals.plos.org/plosbiology/guidelines.php</string>
		<key>cover</key>
		NSImage object
		<key>currentissue</key>
		<string>Vol. 4(12) December 2006</string>
		<key>etoc</key>
		<string>http://biology.plosjournals.org/perlserv/?request=get-toc&amp;issn=1545-7885</string>
		<key>homepage</key>
		<string>http://biology.plosjournals.org/</string>
		<key>impactFactor</key>
		<real>14.2</real>
		<key>issn</key>
		<string>1545-7885</string>
		<key>language</key>
		<string>eng</string>
		<key>name</key>
		<string>PLoS Biology</string>
		<key>nlmID</key>
		<string>101183755</string>
		<key>notes</key>
		<string>More info here...</string>
		<key>openAccess</key>
		<true/>
		<key>publisher</key>
		<string>Public Library of Science</string>
		<key>startYear</key>
		<integer>2003</integer>
		<key>summary</key>
		<string>PLoS Biology is an open-access, peer-reviewed general biology journal published by the Public Library of Science (PLoS), a nonprofit organization of scientists and physicians committed to making the world's scientific and medical literature a public resource. New articles are published online weekly; issues are published monthly.</string>
	</dict>
	<dict>
		.. next journal ..
	</dict>
</array>


KEYWORDS
- identifier
- name - required
- qualifier
- type
- subtype

Example: 

<key>keywords</key>
<array>
	<dict>
		<key>identifier</key>
		<string>an identifier</string>
		<key>name</key>
		<string>Breast Cancer</string>
		<key>qualifier</key>
		<string>a qualifier</string>
		<key>subtype</key>
		<string>Major Topic</string>
		<key>type</key>
		<string>MeSH Heading</string>
	</dict>
	<dict>
	.. next keyword ..
	</dict>
</array>


PUBLICATION TYPES
- name - required

Example: 

<key>publicationTypes</key>
<array>
	<dict>
		<key>name</key>
		<string>Journal Article</string>
	</dict>
	<dict>
	.. next publication type ..
	</dict>
</array>


PAPERS
-abstract
-acceptedDate (NSDate)
-affiliation
-authors (NSArray of author dictionaries - see above)
-category
-doi
-image (NSImage)
-issue
-journal (NSArray with a single journal dictionaries - see above)
-keywords (NSArray of keywords dictionaries - see above)
-label
-language
-notes
-openAccess (NSNumber - BOOL)
-pages
-path (NOTE that providing a path to a pdf file will automatically invoke auto-archiving if enabled)
-pii
-identifier (like pmid)
-publicationTypes (NSArray of publication type dictionaries - see above)
-publishedDate (NSDate)
-receivedDate (NSDate)
-revisedDate (NSDate)
-status
-timesCited (NSNumber - Int)
-title
-url
-volume
-year (NSNumber - Int)

-tempAuthorString (SEE MATCHING PROTOCOL BELOW)
-tempJournalString (SEE MATCHING PROTOCOL BELOW)

Example: 

<key>Papers</key>
<array>
	<dict>
		<key>abstract</key>
		<string>MicroRNAs (miRNAs) interact with target...</string>
		<key>acceptedDate</key>
		NSDate object
		<key>affiliation</key>
		<string>Computational Biology Center</string>
		<key>authors</key>
			... HERE AN ARRAY OF AUTHOR DICTIONARIES LIKE ABOVE ...
		<array/>
		<key>category</key>
		<string>Journal Article</string>
		<key>doi</key>
		<string>10.1371/journal.pbio.0020363</string>
		<key>image</key>
		NSImage object
		<key>issue</key>
		<string>3</string>
		<key>journal</key>
			... HERE AN ARRAY WITH A SINGLE JOURNAL DICTIONARY LIKE ABOVE ...
		<array/>
		<key>keywords</key>
			... HERE AN ARRAY OF KEYWORD DICTIONARIES LIKE ABOVE ...
		<array/>
		<key>label</key>
		<string>Cell Biology</string>
		<key>language</key>
		<string>eng</string>
		<key>notes</key>
		<string>Here more info...</string>
		<key>openAccess</key>
		<true/>
		<key>pages</key>
		<string>e363</string>
		<key>path</key>
		<string>/Users/griek/Documents/Papers/1550875.pdf</string>
		<key>pii</key>
		<string>0020363</string>
		<key>identifier</key>
		<string>15502875</string>
		<key>publicationTypes</key>
			... HERE AN ARRAY OF PUBLICATION TYPE DICTIONARIES LIKE ABOVE ...
		<array/>
		<key>publishedDate</key>
		NSDate object
		<key>receivedDate</key>
		NSDate object
		<key>revisedDate</key>
		NSDate object
		<key>status</key>
		<string>In press</string>
		<key>timesCited</key>
		<integer>12</integer>
		<key>title</key>
		<string>Human MicroRNA targets</string>
		<key>url</key>
		<string>http://biology.plosjournals.org/perlserv/?request=get-document&amp;doi=10.1371/journal.pbio.0020363</string>
		<key>volume</key>
		<string>2</string>
		<key>year</key>
		<integer>2006</integer>
	</dict>
</array>

SEE THE COMPLETE EXAMPLE PLIST THAT CAME WITH THIS PACKAGE. 
NOTE THAT WE EXPECT THE ORIGINAL DICTIONARY, NOT A PLIST OR SERIALIZED DICTIONARY

*/

/////////////////////////////////////////////////////////////


/////////////////////////////////////////////////////////////
/*  USING NSERRORS
NSErrors are returned by two of the methods below in order to allow
the main application to inform the user of problems that occur while 
trying to use the plugin.  
The domain should always be "Papers Importer Error"

The user dictionary should have two keys:
"title" and "description".  By default, they will be used to create
 the text of an informative dialog as: "title:  description"
 So design your messages accordingly.  

 PLEASE LOCALIZE YOUR MESSAGES WITHIN YOUR PLUGIN
 Make sure the "title" and "description" keys are in an appropriate language by
 the time the application gets the NSError.  This will allow the bundle to be
 entirely self-contained.
 Even if you don't know any other languages, provide the structure within your
 plugin to allow others to do the localization.
*/

/////////////////////////////////////////////////////////////

// THESE ARE METHODS THE PLUGIN DELEGATE IMPLEMENTS AND YOU SHOULD CALL

@protocol PapersSearchPluginDelegate <NSObject>

// Signal the delegate that you started the search process
// Allows the delegate to prepare the interface before displaying new data
- (void)didBeginSearch:(id)sender;	

// Tell the delegate you received the initial number of Papers for the query
// This will trigger the delegate to call your itemsFound method so make sure you
// have can answer that.
- (void)didFindResults:(id)sender;

// Provide here an autoreleased dictionary containing the results from your search. The structure of what this
// dictionary should look like is shown above. Papers will convert this dictionary in the corresponding model objects for you.
// If you provide no or an empty dictionary Papers will warn the user no records were found. 
// You can post the results one at the time or in batches or all at once. If you provide them all at once, return nil for
// itemsToImport so that an indeterminate progressbar is shown.
- (void)didRetrieveObjects:(NSDictionary *)dict;		

// Signal the delegate that you are done. The delegate will inform how things went so be sure to set any errors and be ready
// to answer didCompleteSuccessfully.
- (void)didEndSearch:(id)sender;					

// Inform the delegate of a status change, use when statusString, foundItems or itemsToRetrieve changes.
// Status updates are automatically issued by calling any of the methods above
- (void)updateStatus:(id)sender;

@end

@protocol PapersSearchPluginProtocol

// gives you a handle to the delegate object to which you deliver results and notify progress (see above)
// do not retain the delegate
- (id)delegate;
- (void)setDelegate: (id)del;

// ================================
#pragma mark Repository Information

// name returns a string which is shown in the source list and used throughout the UI.
// make sure there are no naming collisions with existing plugins and keep the name rather short.
- (NSString *) name;

// allows to return a color for your plugin, like green for google scholar and blue for Pubmed.
// Note: in the plugin test application you can click on the statusbar in the config panel to
// get a color picker that helps you pick a color for the statusbar. The color will be updated and 
// logged into the console so that it can be entered here.
// Important: don't pick a color that is to dark!
- (NSColor *) color;

// return the logo as will be displayed in the search box. take a look at the sample plugins for examples.
// suggested size 250w x 50h
- (NSImage *) logo;

// return an 37w x 31h icon for use in the statusbar (one with the magnifying class)
- (NSImage *) large_icon;

// return an 18w x 16h icon for use in the inspector bar (without a magnifying class)
- (NSImage *) small_icon;

// return a 25w x23h icon for use in the source list (normal setting)
- (NSImage *) sourcelist_icon;

// return a 20w x 18h icon for use in the source list (small setting)
- (NSImage *) sourcelist_icon_small;

// return the weburl to the homepage of the searchengine/repository
- (NSURL *) info_url;

// return a unique identifier in the form of a reverse web address of the search engine
- (NSString *) identifier;

// return whether the search engine requires a subscription
- (BOOL) requiresSubscription;

// return NO if you only wish to use this plugin for matching or automatching
// note that you still need to fullfill the PapersSearchPluginProtocol protocol, 
// you can just leave most of its methods empty in that case.
- (BOOL) actsAsGeneralSearchEngine;
	
// =========================
#pragma mark Preferences

// if your plugin needs to be configured you can return here a preference panel. 
// take a look at the example plugin on how to use this.
// Otherwise return nil.
- (NSView *) preferenceView;

// ==========================
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
- (NSDictionary *)predefinedSearchTerms;  //--> show/hide menu!

// return a dictionary of searchfield codes that show up as choices in the searchtokens
// the dictionary should contain an array under key "order" and a dictionary under the key "fields" containing 
// key-value pairs where the key is the name of the field and the value a code that 
// your plugin can translate into the right parameters. We advise to adopt the pubmed model of
// field codes. Make sure that it is unlikely that any query a user types in will coincidentally correspond to a field 
// code


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
- (NSDictionary *)searchFields;  //--> show/hide!

// ==========================
#pragma mark Auto-completion

// return yes if you wish to autocomplete searchterms
// if you do autocompletion via the internet, be sure to check the server is up!
- (BOOL)autocompletesSearchTerms;
// return an array of strings for the partial string, make sure this stuff works fast!
- (NSArray *)autocompletionsForPartialString: (NSString *)str;

// ==========================
#pragma mark Searching

// a method to make sure everything's set to go before starting, do some setup or tests here if necessary.
// and a method to find out what the problems are if things aren't set. See above for usage of errorCodes.
// for instance return an error when the service is not up.
- (BOOL) readyToPerformSearch;
- (NSError *) searchPreparationError;

// used for the history items and saved folders in the
- (NSString *)descriptiveStringForQuery: (NSArray *)tokens;

// return YES if you support cancelling the current search session (strongly advised).
- (BOOL) canCancelSearch;

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
- (void) performSearchWithQuery: (NSArray *)tokens;

// informs us that we should stop searching. Since we're running in a thread we should check regularly
// if we have been cancelled
- (void) cancelSearch;

// =========================
#pragma mark Saved Searches

// NOT YET IMPLEMENTED

// when a search is saved it will be regularly updated, only return those results that are new since the given date.
// NOTE that this method runs in a separate thread. Signal your progress to the delegate.
- (void) performSavedSearchWithQuery: (NSArray *)tokens afterDate: (NSDate *)date;

// ==========================
#pragma mark Results

// number of items that are fetched per batch, default is set by Papers but can be overridden
// internally.
// NOTE: Only applies to the performSearchWithQuery: method
- (NSNumber *)itemsPerPage;
- (void)setItemsPerPage:(NSNumber *)newItemsPerPage;

// the offset we have to start fetching from. This is set by Papers before the search is started and
// used when the user wishes to get the next page of results. 
// NOTE: Only applies to the performSearchWithQuery: method
- (NSNumber *)itemOffset;
- (void)setItemOffset:(NSNumber *)newItemOffset;

// return the number of items found for this query, this is the total number even if you fetch
// only one page
- (NSNumber *)itemsFound;

// return the number of items you are about to retrieve (batch size). 
// return the number of items you have retrieved. 
// As long as this value is nil an indeterminate progress bar is shown, the moment you return a non-nil value for both the 
// progress will be shown to the user. use in combination with the delegate method updateStatus: to push changes to the 
// delegate and force an update.
- (NSNumber *)itemsToRetrieve;
- (NSNumber *)retrievedItems;

// return the current status of your plugin to inform the user. make sure these strings are localizable!
// use in combination with the delegate method updateStatus: to push changes to the delegate and force an update.
- (NSString *)statusString;

// A method to check whether the search finished properly
// and one to get at any errors that resulted. See above for usage of errorCodes.
- (BOOL) successfulCompletion;
- (NSError *) searchCompletionError;

// let the plugin get rid of any data that needs to be reset for a new search.
- (void) performCleanup;

// ==========================
#pragma mark Meta-data

// return the metadata for the paper with the given identifier
// you will be passed the id as you set it during the search
// return a dictionary with the standard format of a papers entry and the single 
// paper entry or nil if impossible to resolve
// note that this one is asynchronous and you do not signal progress
// to the delegate
// if you want to run asynchronous use the method below with a single 
// identifier in an array
- (NSDictionary *)metadataForID: (NSString *)identifier;

// return the metadata for the papers with the given identifiers
// you will be passed the ids as you set it during the search
// return nil if impossible to resolve
// NOTE that this method runs in a separate thread. Signal your progress to the delegate.
- (void)metadataForIDs: (NSArray *)identifiers;

// ==========================
#pragma mark Follow-up

// return the URL to the paper within the repository
// you will be passed the id as you set it during the search
// return nil if impossible to resolve
- (NSURL *)repositoryURLForID: (NSString *)identifier;

// return the URL to the paper at the publisher's website, preferably fulltext
// you will be passed the id as you set it during the search
// return nil if impossible to resolve
- (NSURL *)publisherURLForID: (NSString *)identifier;

// return the URL to the PDF ofthe paper
// you will be passed the id as you set it during the search
// return nil if impossible to resolve
// IMPORTANT: if you return nil Papers will do its best to automatically retrieve the PDF on the basis of 
// the publisherURLForID as returned above. ONLY return a link for a PDF here if a) you are sure you
// know the location or b) you think you can do some fancy lookup that outperforms Papers build in attempts.
- (NSURL *)pdfURLForID: (NSString *)identifier;

// ==========================
#pragma mark Related Articles

// return whether your plugin supports the retrieval of related articles or not.
- (BOOL) supportsRelatedArticles;

// return related articles in the same way you return search results.
// you will be passed the id as you set it during the search.
// NOTE: that this method runs in a separate thread. Signal your progress to the delegate.
// IMPORTANT: You can optionally add one extra parameter per paper which is a "score" (NSNumber between 0.0 and 1.0).
- (void) getRelatedArticlesForID: (NSString *)identifier;

// ==========================
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
- (void)recentArticlesForAuthor: (NSDictionary *)author;

// return recent articles for the provided journal
// you will be passed a dictionary representation of the journal during the search
// NOTE that this method runs in a separate thread. Signal your progress to the delegate.
- (void)recentArticlesForJournal: (NSDictionary *)journal;

// return recent articles for the provided keyword
// you will be passed a dictionary representation of the keyword during the search
// NOTE that this method runs in a separate thread. Signal your progress to the delegate.
- (void)recentArticlesForKeyword: (NSDictionary *)keyword;

@end

// Optional - By implementing this you will be automatically added to the matching list

@protocol PapersMatchPluginProtocol

// return the logo as will be displayed in the matching search box (this one is smaller than that for the search engine). 
// take a look at the sample plugins for examples.
// suggested size 115w x 40h
- (NSImage *) small_logo;

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
- (void) performMatchWithQuery: (NSArray *)tokens;

// this method is called when the user has selected the right paper, you will be passed the identifier (as you set it
// during the initial search, and you have to return the full metadata for the paper (as rich as possible).
// return the usual dictionary with a papers array containing a SINGLE entry or nil if the identifier cannot be resolved.
// NOTE that this method runs in a separate thread. Signal your progress to the delegate.
// use the above delegate methods
- (void) performMatchForID: (NSString *)identifier;

@end

// Optional - By implementing this your plugin will be automatically added to the matching list

@protocol PapersAutoMatchPluginProtocol

// this method is called when the user wishes to auto match a paper. You will be handed all available
// metadata (including the link to the PDF file if present) in the above described dictionary format.
// it's your task to return one or more (preferably fewer than 5) possible hits. Return nothing if you
// can't find anything. 
// NOTE that in the current implementation it's likely we ignore the results if you return more than 1 hit.
// NOTE that this method runs in a separate thread. Signal your progress to the delegate.
// use the above delegate methods
- (void) performAutoMatchForPaper: (NSDictionary *)paper;

@end


// Below you'll find the interface declaration for the MTQueryTermTokens that are passed to you as the query
// from the tokenfield. It is used to encapsulate the individual parts that make up the query.
// * Token is the string value of the actual subquery token
// * Field is the subfield as selected for each token using the little triangle on a token if you hover over it
// (that is, if you have provided a list of fields)
// * Code is the internal code that represents the selected field, example: [AU] for authors in pubmed
// * OperatorType is the operator as selected from the same triangle, AND, OR, NOT
// * Predefined is a boolean NSNumber that indicates whether the token was generated from a predefined searchterm
// (that is, if you have provided a list of these)
// Furthermore you can use the displayString method to retrieve a pretty reprentation of the subquery (this is what
// is shown in the blue token after entry.

@interface MTQueryTermToken : NSObject {
    NSString *token;
	NSString *field;
	NSString *code;
    NSString *operatorType;
	NSNumber *predefined;
}

- (id)initWithToken:(NSString *)atoken
			  field:(NSString *)afield
			   code:(NSString *)acode
	   operatorType:(NSString *)anoperatorType
		 predefined:(NSNumber *)value;

- (NSString *)token;
- (void)setToken:(NSString *)newToken;

- (NSString *)field;
- (void)setField:(NSString *)newField;

- (NSString *)code;
- (void)setCode:(NSString *)newCode;

- (NSString *)operatorType;
- (void)setOperatorType:(NSString *)newOperatorType;

- (NSNumber *)predefined;
- (void)setPredefined:(NSNumber *)newPredefined;

- (NSString *)searchTerm;
- (NSString *)displayString;

- (NSString *)operatorCode;
- (NSString *)description;

@end