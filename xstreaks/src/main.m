/*
 * Copyright (c) 2025 Bastiaan van der Plaat
 *
 * SPDX-License-Identifier: MIT
 */

#import <Cocoa/Cocoa.h>
#include "secrets.h"

@interface AppDelegate : NSObject <NSApplicationDelegate>
    @property (strong, nonatomic) NSString *username;
    @property NSInteger userId;
    @property (strong, nonatomic) NSImage *statusOffIcon;
    @property (strong, nonatomic) NSImage *statusOnIcon;
    @property (strong, nonatomic) NSStatusItem *statusItem;
@end

@implementation AppDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)notification {
    // Load settings
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    self.username = [defaults stringForKey:@"username"];
    self.userId = [defaults integerForKey:@"userId"];

    // Schedule updateStreak to run every half hour
    [NSTimer scheduledTimerWithTimeInterval:30 * 60 target:self selector:@selector(updateStreakTimer:) userInfo:nil repeats:YES];

    // Load icons
    self.statusOffIcon = [NSImage imageNamed:@"status_off_icon"];
    [self.statusOffIcon setTemplate:YES];
    self.statusOnIcon = [NSImage imageNamed:@"status_on_icon"];
    [self.statusOnIcon setTemplate:YES];

    // Create system menu bar item
    self.statusItem = [[NSStatusBar systemStatusBar] statusItemWithLength:NSSquareStatusItemLength];
    self.statusItem.button.image = self.statusOffIcon;
    NSMenu *menu = [NSMenu new];
    self.statusItem.menu = menu;
    if (self.userId != 0) {
        [menu addItemWithTitle:NSLocalizedString(@"Loading streak...", @"Menu streak loading") action:nil keyEquivalent:@""];
    } else {
        [menu addItemWithTitle:NSLocalizedString(@"No username set...", @"Menu no username") action:nil keyEquivalent:@""];
    }
    [menu addItem:[NSMenuItem separatorItem]];
    [menu addItemWithTitle:NSLocalizedString(@"Settings", @"Settings") action:@selector(openSettings:) keyEquivalent:@","];
    [menu addItem:[NSMenuItem separatorItem]];
    [menu addItemWithTitle:NSLocalizedString(@"About XStreaks", @"Menu about") action:@selector(openAbout:) keyEquivalent:@""];
    [menu addItemWithTitle:NSLocalizedString(@"Quit XStreaks", @"Menu quit") action:@selector(terminate:) keyEquivalent:@"q"];

    // Load streak days from settings
    if (self.userId != 0) {
        NSString *streakUpdateTime = [defaults stringForKey:@"streakUpdateTime"];
        if (streakUpdateTime) {
            NSDateFormatter *isoDateFormatter = [[NSDateFormatter new] autorelease];
            [isoDateFormatter setDateFormat:@"yyyy-MM-dd'T'HH:mm:ss.SSS'Z'"];
            if ([[NSDate date] timeIntervalSinceDate:[isoDateFormatter dateFromString:streakUpdateTime]] < 60 * 60) {
                NSInteger streakDays = [defaults integerForKey:@"streakDays"];
                NSLog(@"[INFO] Use cached streak days: %ld", streakDays);
                [self updateStreakLabel:streakDays];
                return;
            }
        }
        [self updateStreak:false];
    }
}

- (void)updateStreakLabel:(NSInteger)streakDays {
    NSMenuItem *firstMenuItem = [self.statusItem.menu itemAtIndex:0];
    if (streakDays == -1) {
        self.statusItem.button.image = self.statusOffIcon;
        [firstMenuItem setTitle:NSLocalizedString(@"Loading streak...", @"Menu streak loading")];
        [firstMenuItem setAction:nil];
    } else if (streakDays > 0) {
        self.statusItem.button.image = self.statusOnIcon;
        if (streakDays == 1) {
            [firstMenuItem setTitle:[NSString stringWithFormat:NSLocalizedString(@"Current streak: %ld day", @"Menu streak single ('%ld' is a placeholder where the number is put)"), streakDays]];
        } else {
            [firstMenuItem setTitle:[NSString stringWithFormat:NSLocalizedString(@"Current streak: %ld days", @"Menu streak plural ('%ld' is a placeholder where the number is put)"), streakDays]];
        }
        [firstMenuItem setAction:@selector(streakMenuItemClicked)];
    } else {
        self.statusItem.button.image = self.statusOffIcon;
        [firstMenuItem setTitle:NSLocalizedString(@"No streak, start posting!", @"Menu no streak")];
        [firstMenuItem setAction:nil];
    }
}

- (void)openSettings:(id)sender {
    // Show settings dialog
    NSAlert *alert = [NSAlert new];
    [alert setMessageText:NSLocalizedString(@"Settings", @"Settings")];
    [alert setInformativeText:NSLocalizedString(@"Enter your X profile username:", @"Settings description")];

    NSTextField *inputField = [[NSTextField alloc] initWithFrame:NSMakeRect(0, 0, 200, 24)];
    [inputField setPlaceholderString:NSLocalizedString(@"Username", @"Settings username placeholder")];
    if (self.username) {
        [inputField setStringValue:self.username];
    }
    [alert setAccessoryView:inputField];

    [alert addButtonWithTitle:NSLocalizedString(@"OK", @"OK")];
    [alert addButtonWithTitle:NSLocalizedString(@"Cancel", @"Cancel")];

    NSModalResponse response = [alert runModal];
    if (response == NSAlertFirstButtonReturn) {
        [self updateUsername:inputField.stringValue];
    }
}

- (void)openAbout:(id)sender {
    [NSApp orderFrontStandardAboutPanel:nil];
    [NSApp activateIgnoringOtherApps:YES];
}

- (void)updateUsername:(NSString *)username {
    // Fetch user ID for username
    NSString *encodedUsername = [username stringByAddingPercentEncodingWithAllowedCharacters:[NSCharacterSet URLQueryAllowedCharacterSet]];
    NSURL *url = [NSURL URLWithString:[NSString stringWithFormat:@"https://api.x.com/2/users/by/username/%@", encodedUsername]];
    NSLog(@"[INFO] Fetching %@...", url);
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];
    [request setValue:[NSString stringWithFormat:@"Bearer %s", API_KEY] forHTTPHeaderField:@"Authorization"];
    [request setCachePolicy:NSURLRequestReloadIgnoringLocalCacheData];
    NSURLSessionDataTask *dataTask = [[NSURLSession sharedSession] dataTaskWithRequest:request completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        (void)response;
        if (error) {
            NSLog(@"[ERROR] Fetching user ID: %@", error);
            return;
        }

        NSError *jsonError = nil;
        NSDictionary *json = [NSJSONSerialization JSONObjectWithData:data options:0 error:&jsonError];
        if (jsonError) {
            NSLog(@"[ERROR] Parsing JSON: %@", jsonError);
            return;
        }

        if ([json[@"status"] integerValue] == 429) {
            NSLog(@"[WARN] Too many requests");
            dispatch_async(dispatch_get_main_queue(), ^{
                [self openToManyRequestsAlert];
            });
            return;
        }

        NSDictionary *userData = json[@"data"];
        if (userData) {
            NSLog(@"[INFO] %@'s user ID: %ld", username, [userData[@"id"] integerValue]);

            dispatch_async(dispatch_get_main_queue(), ^{
                self.username = username;
                self.userId = [userData[@"id"] stringValue].integerValue;

                NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
                [defaults setObject:self.username forKey:@"username"];
                [defaults setInteger:self.userId forKey:@"userId"];
                [defaults synchronize];

                [self updateStreakLabel:-1];
                [self updateStreak:true];
            });
        }
    }];
    [dataTask resume];
}

- (void)streakMenuItemClicked {
    [self updateStreak:true];
}

- (void)updateStreakTimer:(NSTimer *)timer {
    [self updateStreak:false];
}

- (void)updateStreak:(bool)userInitiated {
    if (self.userId == 0) {
        return;
    }

    // FIXME: This will break after 100 posts
    NSURL *url = [NSURL URLWithString:[NSString stringWithFormat:@"https://api.x.com/2/users/%ld/tweets?max_results=100&tweet.fields=created_at", (long)self.userId]];
    NSLog(@"[INFO] Fetching %@...", url);
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];
    [request setValue:[NSString stringWithFormat:@"Bearer %s", API_KEY] forHTTPHeaderField:@"Authorization"];
    [request setCachePolicy:NSURLRequestReloadIgnoringLocalCacheData];
    NSURLSessionDataTask *dataTask = [[NSURLSession sharedSession] dataTaskWithRequest:request completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        (void)response;
        if (error) {
            NSLog(@"[ERROR] Fetching posts: %@", error);
            return;
        }

        NSError *jsonError = nil;
        NSDictionary *json = [NSJSONSerialization JSONObjectWithData:data options:0 error:&jsonError];
        if (jsonError) {
            NSLog(@"[ERROR] Parsing JSON: %@", jsonError);
            return;
        }

        if ([json[@"status"] integerValue] == 429) {
            NSLog(@"[WARN] Too many requests");
            if (userInitiated) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    [self openToManyRequestsAlert];
                });
            }
            return;
        }

        NSArray *posts = json[@"data"];
        if (posts) {
            NSDateFormatter *isoDateFormatter = [[NSDateFormatter new] autorelease];
            [isoDateFormatter setDateFormat:@"yyyy-MM-dd'T'HH:mm:ss.SSS'Z'"];

            // Count streak days
            NSInteger streakDays = 0;
            NSDate *currentDate = [NSDate date];
            for (;;) {
                bool foundPost = false;
                for (NSDictionary *post in posts) {
                    NSDate *postDate = [isoDateFormatter dateFromString:post[@"created_at"]];
                    if ([[NSCalendar currentCalendar] isDate:postDate inSameDayAsDate:currentDate]) {
                        streakDays++;
                        currentDate = [currentDate dateByAddingTimeInterval:-24 * 60 * 60];
                        foundPost = true;
                        break;
                    }
                }
                if (!foundPost)
                    break;
            }
            NSLog(@"[INFO] Current streak: %ld days", streakDays);

            dispatch_async(dispatch_get_main_queue(), ^{
                [self updateStreakLabel:streakDays];

                NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
                [defaults setInteger:streakDays forKey:@"streakDays"];
                [defaults setObject:[isoDateFormatter stringFromDate:[NSDate date]] forKey:@"streakUpdateTime"];
                [defaults synchronize];
            });
        }
    }];
    [dataTask resume];
}

-(void)openToManyRequestsAlert {
    NSAlert *alert = [NSAlert new];
    [alert setMessageText:NSLocalizedString(@"Too Many Requests", @"Too Many Requests")];
    [alert setInformativeText:NSLocalizedString(@"You have made too many requests. Please try again later.", @"Too Many Requests description")];
    [alert addButtonWithTitle:NSLocalizedString(@"OK", @"OK")];
    [alert runModal];
}

@end

int main(int argc, const char **argv) {
    NSApplication *app = [NSApplication sharedApplication];
    app.delegate = [AppDelegate new];
    return NSApplicationMain(argc, argv);
}
