#import <dlfcn.h>
#import <objc/runtime.h>
#import <substrate.h>
#import <notify.h>
#import <Foundation/NSTask.h>
#import <CommonCrypto/CommonCrypto.h>
#import <SystemConfiguration/SystemConfiguration.h>
#import <prefs.h>

extern const char *__progname;

#undef HBLogError
#define HBLogError(...)
#define NSLog(...)

@interface LSApplicationProxy : NSObject
- (NSURL*)resourcesDirectoryURL;
@end
@interface InstalledController : UITableViewController
- (LSApplicationProxy *)proxyAtIndexPath:(NSIndexPath *)path;
@end

@interface SettingsExtendfile : PSListController
+ (id) shared;
@end

@interface DocumentsExtendfile : UITableViewController <UITableViewDelegate, UITableViewDataSource, UIAlertViewDelegate>
{
	NSMutableArray *searchData;
}
+ (id) shared;
- (void)Refresh;
@end

const char * origTeamID;
const char * myTeamID;

static BOOL disableTemp = YES;

size_t (*strlen_o)(const char *str);
size_t strlen_r(const char *str)
{
	
	if(!disableTemp &&str&&myTeamID&&origTeamID&&strcmp(str, origTeamID)==0) {
		memcpy((void*)str, (const void *)myTeamID, 10);
	}
	return strlen_o(str);
}


%hook Extender
- (NSArray*)defaultStartPages
{
	NSArray* ret = %orig;
	NSMutableArray* retMut = [ret mutableCopy];
	[retMut addObject:@[@"cyext://documents"]];
	[retMut addObject:@[@"cyext://settings"]];
	return [retMut copy];
}
- (UIViewController *) pageForURL:(NSURL *)url forExternal:(BOOL)external withReferrer:(NSString *)referrer
{
	if(url) {
		NSString *scheme([[url scheme] lowercaseString]);
		if(scheme&&[scheme isEqualToString:@"cyext"]) {
			if([[url absoluteString] isEqualToString:@"cyext://documents"]) {
				return (UIViewController*)[DocumentsExtendfile shared];
			} else if([[url absoluteString] isEqualToString:@"cyext://settings"]) {
				return (UIViewController*)[SettingsExtendfile shared];
			}
		}	
	}	
	return %orig;
}
%end
%hook CyextTabBarController
- (void)setViewControllers:(NSArray*)arg1
{
	
	NSMutableArray *controllers([arg1 mutableCopy]);
	
	UITabBarItem *item = [[UITabBarItem alloc] initWithTabBarSystemItem:UITabBarSystemItemDownloads tag:0];
	UINavigationController *controller([[UINavigationController alloc] init]);
	[controller setTabBarItem:item];
	[controllers addObject:controller];
	
	UITabBarItem *item2 = [[UITabBarItem alloc] initWithTabBarSystemItem:UITabBarSystemItemMore tag:0];
	UINavigationController *controller2([[UINavigationController alloc] init]);
	[controller2 setTabBarItem:item2];
	[controllers addObject:controller2];
	
	
	%orig(controllers);
}
%end


static NSString* teamID;

@implementation SettingsExtendfile
+ (id) shared {
	static __strong SettingsExtendfile* SettingsExtendfileC;
	if (!SettingsExtendfileC) {
		SettingsExtendfileC = [[self alloc] init];
	}
	return SettingsExtendfileC;
}
- (id)readOriginalTeamIDValue:(id)arg1
{
	return teamID;
}
- (id)readCurrentTeamIDValue:(id)arg1
{
	return myTeamID?[NSString stringWithUTF8String:myTeamID]:teamID;
}
- (id)specifiers {
	if (!_specifiers) {
		NSMutableArray* specifiers = [NSMutableArray array];
		PSSpecifier* spec;
		
		spec = [PSSpecifier preferenceSpecifierNamed:@"Original TeamID"
					      target:self
						 set:NULL
						 get:@selector(readOriginalTeamIDValue:)
					      detail:Nil
						cell:PSTitleValueCell
						edit:Nil];
		[spec setProperty:@"OriginalTeamID" forKey:@"key"];
		[spec setProperty:teamID forKey:@"default"];
		[specifiers addObject:spec];
		spec = [PSSpecifier preferenceSpecifierNamed:@"Current TeamID"
					      target:self
						 set:NULL
						 get:@selector(readCurrentTeamIDValue:)
					      detail:Nil
						cell:PSTitleValueCell
						edit:Nil];
		[spec setProperty:@"CurrentTeamID" forKey:@"key"];
		[spec setProperty:myTeamID?[NSString stringWithUTF8String:myTeamID]:teamID forKey:@"default"];
		[specifiers addObject:spec];
		
		
		spec = [PSSpecifier preferenceSpecifierNamed:@"Set/Change TeamID"
						      target:self
											  set:Nil
											  get:Nil
					      detail:Nil
											  cell:PSGroupCell
											  edit:Nil];
		[spec setProperty:@"Set/Change TeamID" forKey:@"label"];
		[spec setProperty:@"Set your Apple Account TeamID.\nTeamID is Spoofed at runtime, don't change files." forKey:@"footerText"];
		[specifiers addObject:spec];
		spec = [PSSpecifier preferenceSpecifierNamed:@"TeamID:"
					      target:self
											  set:@selector(setCurrentTeamIDValue:specifier:)
											  get:@selector(readValue:)
					      detail:Nil
											  cell:PSEditTextCell
											  edit:Nil];
		[spec setProperty:@"TeamID" forKey:@"key"];
		[specifiers addObject:spec];
		
		spec = [PSSpecifier emptyGroupSpecifier];
        [spec setProperty:@"Extendlife © 2017 julioverne" forKey:@"footerText"];
        [specifiers addObject:spec];
		_specifiers = [specifiers copy];
	}
	return _specifiers;
}
- (void)refresh:(UIRefreshControl *)refresh
{
	[self reloadSpecifiers];
	if(refresh) {
		[refresh endRefreshing];
	}	
}
- (void)showErrorFormat
{
	UIAlertView *alert = [[UIAlertView alloc] initWithTitle:self.title message:@"TeamID has wrong format.\n\nFormat accept:\nABCDEF1234" delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil];
	[alert show];
}
- (void)showSucess
{
	UIAlertView *alert = [[UIAlertView alloc] initWithTitle:self.title message:@"Success, Please Reopen Cydia Extender to Apply Changes." delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil];
	[alert show];
}

- (void)setCurrentTeamIDValue:(id)value specifier:(PSSpecifier *)specifier
{
	@autoreleasepool {
		if(value&&[value length]==10) {
			value = [value stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
			value = [value uppercaseString];
			[[NSUserDefaults standardUserDefaults] setObject:value forKey:@"myTeamID"];
			[[NSUserDefaults standardUserDefaults] synchronize];
			notify_post("com.julioverne.extendlife/Settings");
			[self performSelector:@selector(refresh:) withObject:nil afterDelay:0.4f];
			[self showSucess];
		} else {
			[self showErrorFormat];
		}
		
		
		
	}
}
- (id)readValue:(PSSpecifier*)specifier
{
	return nil;
}
- (void)_returnKeyPressed:(id)arg1
{
	[super _returnKeyPressed:arg1];
	[self.view endEditing:YES];
}

- (void) loadView
{
	[super loadView];
	self.title = @"Spoof TeamID";	
	static __strong UIRefreshControl *refreshControl;
	if(!refreshControl) {
		refreshControl = [[UIRefreshControl alloc] init];
		[refreshControl addTarget:self action:@selector(refresh:) forControlEvents:UIControlEventValueChanged];
		refreshControl.tag = 8654;
	}	
	if(UITableView* tableV = (UITableView *)object_getIvar(self, class_getInstanceVariable([self class], "_table"))) {
		if(UIView* rem = [tableV viewWithTag:8654]) {
			[rem removeFromSuperview];
		}
		[tableV addSubview:refreshControl];
	}
}

- (void)viewWillAppear:(BOOL)animated
{
	[super viewWillAppear:animated];
	[self refresh:nil];
}

- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath 
{
	return (indexPath.section == 0);
}
- (BOOL)tableView:(UITableView *)tableView shouldShowMenuForRowAtIndexPath:(NSIndexPath *)indexPath
{
    return (indexPath.section == 0);
}
- (BOOL)tableView:(UITableView *)tableView canPerformAction:(SEL)action forRowAtIndexPath:(NSIndexPath *)indexPath withSender:(id)sender
{
    return (action == @selector(copy:));
}
- (void)tableView:(UITableView *)tableView performAction:(SEL)action forRowAtIndexPath:(NSIndexPath *)indexPath withSender:(id)sender
{
    if (action == @selector(copy:)) {
        UITableViewCell *cell = [tableView cellForRowAtIndexPath:indexPath];
        UIPasteboard *pasteBoard = [UIPasteboard generalPasteboard];
        [pasteBoard setString:cell.textLabel.text];
    }
}				
@end


@interface Extender : NSObject
- (BOOL)application:(UIApplication *)application openURL:(NSURL *)url sourceApplication:(NSString *)sourceApplication annotation:(id)annotation;
@end

@implementation DocumentsExtendfile
+ (id) shared {
	static __strong DocumentsExtendfile* DocumentsExtendfileC;
	if (!DocumentsExtendfileC) {
		DocumentsExtendfileC = [[self alloc] init];
	}
	return DocumentsExtendfileC;
}

- (void)Refresh
{
	NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
	NSString *documentsDirectory = paths[0];
	NSString *dataPath = [documentsDirectory stringByAppendingPathComponent:@"Inbox"];
	searchData = [[[NSFileManager defaultManager] contentsOfDirectoryAtPath:dataPath error:nil]?:@[] copy];
	if(self.tableView) {
		[self.tableView reloadData];
	}	
}

- (void) loadView
{
	[super loadView];
	self.title = @"IPA Imported";
	UIRefreshControl *refreshControl = [[UIRefreshControl alloc] init];
	[refreshControl addTarget:self action:@selector(refreshView:) forControlEvents:UIControlEventValueChanged];
	[self.tableView addSubview:refreshControl];
	[self Refresh];
}

- (void)refreshView:(UIRefreshControl *)refresh
{
	[self Refresh];
	[refresh endRefreshing];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    static __strong NSString *simpleTableIdentifier = @"Documents";
	UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:simpleTableIdentifier];
	if(cell== nil) {
	    cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:simpleTableIdentifier];			
    }
	
	cell.imageView.image = nil;
	cell.detailTextLabel.text = searchData[indexPath.row];
	cell.textLabel.text = nil;
	cell.accessoryType = UITableViewCellAccessoryNone;
	
	return cell;
}

- (NSIndexPath *)tableView:(UITableView *)tableView willSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
	@try {
		NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
		NSString *documentsDirectory = paths[0];
		NSString *dataPath = [documentsDirectory stringByAppendingPathComponent:@"Inbox"];
		NSString * IPASt = [dataPath stringByAppendingPathComponent:searchData[indexPath.row]];
		NSURL * urlIpa = [NSURL fileURLWithPath:IPASt];
		if([(Extender*)[UIApplication sharedApplication] application:[UIApplication sharedApplication] openURL:urlIpa sourceApplication:nil annotation:nil]) {
			//
		}
	} @catch (NSException * e) {
	}
	return nil;
}
- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath 
{
	return	YES;
}
- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath
{
	@try {
		NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
		NSString *documentsDirectory = paths[0];
		NSString *dataPath = [documentsDirectory stringByAppendingPathComponent:@"Inbox"];
		NSString * IPASt = [dataPath stringByAppendingPathComponent:searchData[indexPath.row]];
		[[NSFileManager defaultManager] removeItemAtPath:IPASt error:nil];
		[self Refresh];
		return;
	} @catch (NSException * e) {
	}
}
- (NSString *)tableView:(UITableView *)tableView titleForDeleteConfirmationButtonForRowAtIndexPath:(NSIndexPath *)indexPath
{
	return [[NSBundle bundleWithPath:@"/System/Library/Frameworks/UIKit.framework"] localizedStringForKey:@"Delete" value:@"Delete" table:nil];
}
- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section
{
	return @"Documents/Inbox/";
}
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
	return [searchData count];
}
- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return 1;
}
- (NSURL *)navigationURL
{
	return [NSURL URLWithString:@"cyext://documents"];
}
@end



static void settingsChangedExtendlife(CFNotificationCenterRef center, void *observer, CFStringRef name, const void *object, CFDictionaryRef userInfo)
{	
	@autoreleasepool {
		if(NSString *teamIDValue = [[NSUserDefaults standardUserDefaults] stringForKey:@"myTeamID"]) {
			myTeamID = teamIDValue.UTF8String;
		}		
	}
}


__attribute__((constructor)) static void initialize_WidPlayer()
{
	@autoreleasepool {
		
		MSHookFunction((void *)(dlsym(RTLD_DEFAULT, "strlen")), (void *)strlen_r, (void **)&strlen_o);
		
		CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(), NULL, settingsChangedExtendlife, CFSTR("com.julioverne.extendlife/Settings"), NULL, CFNotificationSuspensionBehaviorCoalesce);
		settingsChangedExtendlife(NULL, NULL, NULL, NULL, NULL);
		
		NSDictionary *query = [NSDictionary dictionaryWithObjectsAndKeys:
                           (__bridge NSString *)kSecClassGenericPassword, (__bridge NSString *)kSecClass,
                           @"bundleSeedID", kSecAttrAccount,
                           @"", kSecAttrService,
                           (id)kCFBooleanTrue, kSecReturnAttributes,
                           nil];
		CFDictionaryRef result = nil;
		OSStatus status = SecItemCopyMatching((__bridge CFDictionaryRef)query, (CFTypeRef *)&result);
		if (status == errSecItemNotFound) {
			status = SecItemAdd((__bridge CFDictionaryRef)query, (CFTypeRef *)&result);
		}
		if (status == errSecSuccess) {
			NSString *accessGroup = [(__bridge NSDictionary *)result objectForKey:(__bridge NSString *)kSecAttrAccessGroup];
			NSArray *components = [accessGroup componentsSeparatedByString:@"."];
			NSString *AppIdentifierPrefix = [[components objectEnumerator] nextObject];
			teamID = [AppIdentifierPrefix copy];
			origTeamID = (const char*)(malloc(11));
			memcpy((void*)origTeamID,(const void*)AppIdentifierPrefix.UTF8String, 10);
			
			disableTemp = NO;
		}		
	}
}


