//
//  ViewController.h
//  FieldXT
//
//  Created by Michael Monteiro on 5/18/16.
//  Copyright © 2016 Michael Monteiro. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <AWSCore/AWSCore.h>
#import <AWSCognito/AWSCognito.h>
#import <AWSS3/AWSS3.h>
#import <SocketIOClientSwift/SocketIOClientSwift-Swift.h>

@interface ViewController : UIViewController<UINavigationControllerDelegate,UIImagePickerControllerDelegate>
{
    IBOutlet UILabel *connectLabel;
    IBOutlet UILabel *audioLabel;
    IBOutlet UIButton *photo;
    IBOutlet UISwitch *audioSwitch;
    IBOutlet UIImageView *imageView;
    
    UIImagePickerController *imagePicker;
    AWSS3TransferManager *s3;
    SocketIOClient *socket;
    
    NSString *username;
    NSString *password;
    NSString *companyID;
    
    NSString *userID;
    NSString *webrtcUrl;
}



- (IBAction)connect:(UISwitch *)sender;
- (IBAction)audio:(id)sender;
- (IBAction)photo:(id)sender;

@end

