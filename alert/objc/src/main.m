#import <Cocoa/Cocoa.h>

int main(void) {
    @autoreleasepool {
        NSAlert* alert = [NSAlert new];
        alert.messageText = @"Hello Cocoa from Objective-C!";
        [alert runModal];
    }
    return EXIT_SUCCESS;
}
