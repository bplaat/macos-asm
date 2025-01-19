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

    // Schedule updateStreak to run every hour
    [NSTimer scheduledTimerWithTimeInterval:60 * 60
                                     target:self
                                   selector:@selector(updateStreak)
                                   userInfo:nil
                                    repeats:YES];

    // Load icons
    self.statusOffIcon = [NSImage imageNamed:@"status_off_icon"];
    [self.statusOffIcon setTemplate:YES];
    self.statusOnIcon = [NSImage imageNamed:@"status_on_icon"];
    [self.statusOnIcon setTemplate:YES];

    // Create system menu bar item
    self.statusItem = [[NSStatusBar systemStatusBar] statusItemWithLength:NSSquareStatusItemLength];
    self.statusItem.button.image = self.statusOffIcon;
    NSMenu *menu = [[NSMenu alloc] init];
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
        NSString *streakDate = [defaults stringForKey:@"streakDate"];
        if (streakDate) {
            NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
            [dateFormatter setDateFormat:@"yyyy-MM-dd"];
            if ([[NSCalendar currentCalendar] isDate:[dateFormatter dateFromString:streakDate] inSameDayAsDate:[NSDate date]]) {
                [self updateStreakLabel:[defaults integerForKey:@"streakDays"]];
                return;
            }
        }
        [self updateStreak];
    }
}

- (void)updateStreakLabel:(NSInteger)streakDays {
    NSMenuItem *firstMenuItem = [self.statusItem.menu itemAtIndex:0];
    if (streakDays >= 0) {
        self.statusItem.button.image = self.statusOnIcon;
        if (streakDays == 1) {
            [firstMenuItem setTitle:[NSString stringWithFormat:NSLocalizedString(@"Current streak: %ld day", @"Menu streak single ('%ld' is a placeholder where the number is put)"), streakDays]];
        } else {
            [firstMenuItem setTitle:[NSString stringWithFormat:NSLocalizedString(@"Current streak: %ld days", @"Menu streak plural ('%ld' is a placeholder where the number is put)"), streakDays]];
        }
        [firstMenuItem setAction:@selector(updateStreak)];
    } else {
        self.statusItem.button.image = self.statusOffIcon;
        [firstMenuItem setTitle:NSLocalizedString(@"No streak, start posting!", @"Menu no streak")];
        [firstMenuItem setAction:nil];
    }
}

- (void)openSettings:(id)sender {
    // Show settings dialog
    NSAlert *alert = [[NSAlert alloc] init];
    [alert setMessageText:NSLocalizedString(@"Settings", @"Settings")];
    [alert setInformativeText:NSLocalizedString(@"Enter your X profile username:", @"Settings description")];

    NSTextField *inputField = [[NSTextField alloc] initWithFrame:NSMakeRect(0, 0, 200, 24)];
    [inputField setPlaceholderString:NSLocalizedString(@"Username", @"Settings username placeholder")];
    if (self.username) {
        [inputField setStringValue:self.username];
    }
    [alert setAccessoryView:inputField];

    [alert addButtonWithTitle:NSLocalizedString(@"OK", "Settings OK button")];
    [alert addButtonWithTitle:NSLocalizedString(@"Cancel", "Settings cancel button")];

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
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];
    [request setValue:[NSString stringWithFormat:@"Bearer %s", API_KEY] forHTTPHeaderField:@"Authorization"];

    NSURLSessionDataTask *dataTask = [[NSURLSession sharedSession] dataTaskWithRequest:request completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        (void)response;
        if (error) {
            NSLog(@"Error fetching user ID: %@", error);
            return;
        }

        NSError *jsonError;
        NSDictionary *json = [NSJSONSerialization JSONObjectWithData:data options:0 error:&jsonError];
        if (jsonError) {
            NSLog(@"Error parsing JSON: %@", jsonError);
            return;
        }

        NSDictionary *userData = json[@"data"];
        if (userData) {
            dispatch_async(dispatch_get_main_queue(), ^{
                self.username = username;
                self.userId = [userData[@"id"] stringValue].integerValue;

                NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
                [defaults setObject:self.username forKey:@"username"];
                [defaults setInteger:self.userId forKey:@"userId"];
                [defaults synchronize];

                [self updateStreak];
            });
        }
    }];
    [dataTask resume];
}

- (void)updateStreak {
    if (self.userId == 0) {
        return;
    }

    // FIXME: This will break after 100 tweets, but currently we have 1 call a day :(
    NSURL *url = [NSURL URLWithString:[NSString stringWithFormat:@"https://api.x.com/2/users/%ld/tweets?max_results=100&tweet.fields=created_at", (long)self.userId]];
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];
    [request setValue:[NSString stringWithFormat:@"Bearer %s", API_KEY] forHTTPHeaderField:@"Authorization"];

    NSURLSessionDataTask *dataTask = [[NSURLSession sharedSession] dataTaskWithRequest:request completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        (void)response;

        if (error) {
            NSLog(@"Error fetching tweets: %@", error);
            return;
        }

        NSError *jsonError;
        NSDictionary *json = [NSJSONSerialization JSONObjectWithData:data options:0 error:&jsonError];
        if (jsonError) {
            NSLog(@"Error parsing JSON: %@", jsonError);
            return;
        }

        NSArray *tweets = json[@"data"];
        if (tweets) {
            NSDateFormatter *tweetDateFormatter = [[NSDateFormatter alloc] init];
            [tweetDateFormatter setDateFormat:@"EEE MMM dd HH:mm:ss Z yyyy"];
            NSCalendar *calendar = [NSCalendar currentCalendar];

            // FIXME: Test if this works
            NSInteger streakDays = 0;
            NSDate *currentDate = [NSDate date];
            for (NSDictionary *tweet in tweets) {
                NSDate *tweetDate = [tweetDateFormatter dateFromString:tweet[@"created_at"]];
                NSDate *yesterday = [calendar dateByAddingUnit:NSCalendarUnitDay value:-1 toDate:currentDate options:0];
                if ([calendar isDate:tweetDate inSameDayAsDate:yesterday]) {
                    streakDays++;
                    currentDate = yesterday;
                } else {
                    break;
                }
            }

            dispatch_async(dispatch_get_main_queue(), ^{
                [self updateStreakLabel:streakDays];

                NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
                [defaults setInteger:streakDays forKey:@"streakDays"];
                NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
                [dateFormatter setDateFormat:@"yyyy-MM-dd"];
                [defaults setObject:[dateFormatter stringFromDate:[NSDate date]] forKey:@"streakDate"];
                [defaults synchronize];
            });
        }
    }];
    [dataTask resume];
}

@end

int main(int argc, const char **argv) {
    NSApplication *app = [NSApplication sharedApplication];
    app.delegate = [AppDelegate new];
    return NSApplicationMain(argc, argv);
}
