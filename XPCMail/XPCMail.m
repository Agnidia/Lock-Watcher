//
//  XPCMail.m
//  XPCMail
//
//  Created by Vitalii Parovishnyk on 09.01.2021.
//

#import <CoreLocation/CoreLocation.h>
#import "XPCMail.h"
#import "Mail.h"

@implementation XPCMail

/// send email on trigger via Mail app
/// - Parameters:
///   - to: email of recipient
///   - coordinates: CLLocationCoordinate2D to add to body
///   - attachment: path to image
///   
- (void)sendMail:(NSString *)to coordinates:(CLLocationCoordinate2D)coordinates attachment:(NSString *)attachment {
    
    /* create a Scripting Bridge object for talking to the Mail application */
    MailApplication *mail = [SBApplication applicationWithBundleIdentifier:@"com.apple.Mail"];
    
    /* update message */
    NSDateFormatter *formatter;
    NSString        *dateString;
    
    formatter = [[NSDateFormatter alloc] init];
    [formatter setDateFormat:@"dd/MM/yyyy HH:mm:ss"];
    
    dateString = [formatter stringFromDate:[NSDate date]];
    
    NSString *_messageContent = @"Someone triggered action for Lock Watcher\n\n";
    _messageContent = [_messageContent stringByAppendingFormat:@"Time: %@\n\n", dateString];
    
    if (CLLocationCoordinate2DIsValid(coordinates)) {
        _messageContent = [_messageContent stringByAppendingFormat:@"Location: http://maps.apple.com/?sll=%@,%@&z=10&t=s\n\n", @(coordinates.latitude), @(coordinates.longitude)];
    }
    
    _messageContent = [_messageContent stringByAppendingString:@"--\n"];
    _messageContent = [_messageContent stringByAppendingString:@"Lock Watcher\n"];
    _messageContent = [_messageContent stringByAppendingFormat:@"%@\n\n", @"http://www.Agnidia.com"];
    
    /* create a new outgoing message object */
    MailOutgoingMessage *emailMessage = [[[mail classForScriptingClass:@"outgoing message"] alloc] initWithProperties:
                                         @{@"subject": @"Lock Watcher Security Warning",
                                           @"content" : _messageContent}];
    
    /* Handle a nil value gracefully. */
    if (!emailMessage) {
        return;
    }
    
    /* add the object to the mail app  */
    [[mail outgoingMessages] addObject:emailMessage];
    
    /* set the sender, show the message */
    //emailMessage.visible = NO;
    
    /* Test for errors */
    if ([mail lastError] != nil) {
        return;
    }
                
    /* create a new recipient and add it to the recipients list */
    MailToRecipient *theRecipient = [[[mail classForScriptingClass:@"to recipient"] alloc] initWithProperties:
                                     @{@"address": to}];
    
    /* Handle a nil value gracefully. */
    if (!theRecipient) {
        return;
    }
    
    [emailMessage.toRecipients addObject:theRecipient];
    
    /* Test for errors */
    if ([mail lastError] != nil) {
        return;
    }
    
    /* add an attachment, if one was specified */
    if (attachment.length > 0) {
        MailAttachment *theAttachment = [[[mail classForScriptingClass:@"attachment"] alloc] initWithProperties:
                                         @{@"fileName": [NSURL URLWithString:attachment]}];
        
        /* add it to the list of attachments */
        [[emailMessage.content attachments] addObject:theAttachment];
    }
    
    sleep(1); //Need wait 1 sec for 10.11
    
    /* Test for errors */
    if ([mail lastError] != nil) {
        return;
    }
    
    /* send the message */
    [emailMessage send];
}

@end
