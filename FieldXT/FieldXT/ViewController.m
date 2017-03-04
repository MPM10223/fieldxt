//
//  ViewController.m
//  FieldXT
//
//  Created by Michael Monteiro on 5/18/16.
//  Copyright © 2016 Michael Monteiro. All rights reserved.
//

#import "ViewController.h"

static NSString *SOCKET_IO_SERVER = @"http://localhost:3000";
static NSString *S3_IMAGE_BUCKET = @"fieldxt.images";

static AWSRegionType AWS_REGION = AWSRegionUSEast1;
static NSString *AWS_IDENTITY_POOL_ID = @"us-east-1:44f864f4-e230-4e59-b00b-037a490e3fa0";

@interface ViewController ()

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    // hide sub-controls
    [audioLabel setHidden:true];
    [photo setHidden:true];
    [audioSwitch setHidden:true];
    
    // initialize the image picker / view
    imageView = [[UIImageView alloc] init];
    imagePicker = [[UIImagePickerController alloc] init];
    imagePicker.delegate = self;
    
    // setup AWS credentials
    AWSCognitoCredentialsProvider *credentialsProvider = [[AWSCognitoCredentialsProvider alloc]
                                                          initWithRegionType:AWS_REGION
                                                          identityPoolId:AWS_IDENTITY_POOL_ID];
    
    AWSServiceConfiguration *configuration = [[AWSServiceConfiguration alloc] initWithRegion:AWS_REGION credentialsProvider:credentialsProvider];
    
    [AWSServiceManager defaultServiceManager].defaultServiceConfiguration = configuration;
    
    s3 = [AWSS3TransferManager defaultS3TransferManager];
    
    NSURL *url = [[NSURL alloc] initWithString:SOCKET_IO_SERVER];
    socket = [[SocketIOClient alloc] initWithSocketURL:url options:@{@"log": @true, @"forcePolling": @true}];
    
    username = @"demo";
    password = @"password";
    companyID = @"atlantic-mechanical";
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (IBAction)connect:(UISwitch *)sender {
    if([sender isOn]) {
        [connectLabel setText:@"Connecting..."];
        [audioLabel setHidden:false];
        [photo setHidden:false];
        [audioSwitch setHidden:false];
        
        // socket.io call to connect
        [socket on:@"connect" callback:^(NSArray *data, SocketAckEmitter *ack) {
            NSLog(@"socket connected!");
            
            [socket emitWithAck:@"login" withItems:@[username, password, companyID]](0, ^(NSArray *data){
                
                userID = [data objectAtIndex:0];
                webrtcUrl = [data objectAtIndex:1];
                
                NSLog(@"registered with server.");
                
                // TODO: connect to webrtc call
                
                [connectLabel setText:@"Connected!"];
                
            });
            
        }];
        
        [socket connect];
        
    } else {
        [connectLabel setText:@"Disconnecting..."];
        [audioLabel setHidden:true];
        [photo setHidden:true];
        [audioSwitch setHidden:true];
        
        [socket on:@"disconnect" callback:^(NSArray *data, SocketAckEmitter *ack) {
            NSLog(@"socket disconnected.");
        }];
        
        // TODO: disconnect from webrtc call
        
        [socket emit:@"logout" withItems:@[userID]];
        
        NSLog(@"de-registered with server.");
            
        [socket disconnect];
            
        [connectLabel setText:@"Disconnected."];
    }
}

- (IBAction)audio:(id)sender {
    if([sender isOn]) {
        // TODO: ensure webrtc audio channel is unmuted
    } else {
        // TODO: ensure webrtc audio channel is muted
    }
}

- (IBAction)photo:(id)sender {
    
    // TODO: initiate photo taking with bluetooth camera accessory
    
    imagePicker.allowsEditing = true;
    if([UIImagePickerController isSourceTypeAvailable:UIImagePickerControllerSourceTypeCamera]) {
        imagePicker.sourceType = UIImagePickerControllerSourceTypeCamera;
        imagePicker.cameraDevice = UIImagePickerControllerCameraDeviceRear;
        imagePicker.showsCameraControls = false;
    } else {
        imagePicker.sourceType = UIImagePickerControllerSourceTypePhotoLibrary;
    }
    
    [self presentViewController:imagePicker animated:true completion:nil];
    
}

-(void)imagePickerController:(UIImagePickerController *)picker didFinishPickingMediaWithInfo:(NSDictionary<NSString *,id> *)info {

    NSLog(@"Finished picking image.");
    
    UIImage *image = [info objectForKey:UIImagePickerControllerEditedImage];
    if(image == nil) {
        image = [info objectForKey:UIImagePickerControllerOriginalImage];
    }
    
    // Save image to file
    NSString *dateKey = [NSString stringWithFormat: @"%.0f",[[NSDate date] timeIntervalSince1970] * 1000.0];
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, true);
    NSString *filePath = [[paths objectAtIndex:0] stringByAppendingPathComponent:[NSString stringWithFormat:@"%@.png", dateKey]];
    [UIImagePNGRepresentation(image) writeToFile:filePath atomically:true];
    
    NSLog(@"Wrote image file to %@", filePath);
    
    NSURL* fileUrl = [NSURL fileURLWithPath:filePath];
    NSString *s3FileName = [NSString stringWithFormat:@"%@.%@.png", username, dateKey];
    
    // Upload photo to S3
    AWSS3TransferManagerUploadRequest *s3ur = [AWSS3TransferManagerUploadRequest new];
    s3ur.body = fileUrl;
    s3ur.bucket = S3_IMAGE_BUCKET;
    s3ur.key = s3FileName;
    s3ur.contentType = @"image/png";
    
    NSLog(@"Uploading local image file at %@ to S3 (%@/%@)", fileUrl, S3_IMAGE_BUCKET, s3FileName);
    
    [[s3 upload:s3ur] continueWithExecutor:[AWSExecutor mainThreadExecutor] withBlock:^id(AWSTask *task) {
        
        NSLog(@"Received callback from AWS...");
        
        if (task.error) {
            if ([task.error.domain isEqualToString:AWSS3TransferManagerErrorDomain]) {
                switch (task.error.code) {
                    case AWSS3TransferManagerErrorCancelled:
                    case AWSS3TransferManagerErrorPaused:
                        NSLog(@"Cancelled or Paused: %@", task.error);
                        break;
                        
                    default:
                        NSLog(@"Error: %@", task.error);
                        break;
                }
            } else {
                // Unknown error.
                NSLog(@"Error: %@", task.error);
            }
        }
        
        if (task.result) {
            //AWSS3TransferManagerUploadOutput *uploadOutput = task.result;
            // The file uploaded successfully.
            NSLog(@"Success!");
            
            NSString *s3FileUrl = [NSString stringWithFormat:@"s3://%@/%@", S3_IMAGE_BUCKET, s3FileName];
            
            NSLog(@"Emitting photo at %@", s3FileUrl);
            [socket emit:@"photo" withItems:@[userID, s3FileUrl]];
            
            [[picker presentingViewController] dismissViewControllerAnimated:YES completion:nil];
            
            imageView.image = image;
        }
        return nil;
    }];
    
}

-(void)imagePickerControllerDidCancel:(UIImagePickerController *)picker {
    [[picker presentingViewController] dismissViewControllerAnimated:YES completion:nil];
}
@end
