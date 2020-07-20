//
//  SJTestViewController.m
//  SJMediaCacheServer_Example
//
//  Created by BlueDancer on 2020/7/20.
//  Copyright © 2020 changsanjiang@gmail.com. All rights reserved.
//

#import "SJTestViewController.h"
#import <SJMediaCacheServer/SJMediaCacheServer.h>
#import <SJMediaCacheServer/NSURLRequest+MCS.h>
#import <SJMediaCacheServer/MCSUtils.h>

@interface SJTestViewController ()<NSURLSessionDataDelegate>
@property (nonatomic, strong, nullable) NSURLSession *session;
@property (nonatomic) uint64_t startTime;
@end

@implementation SJTestViewController

- (void)viewDidLoad {
    [super viewDidLoad];
     
    [SJMediaCacheServer shared];
    
    NSURLSessionConfiguration *config = NSURLSessionConfiguration.defaultSessionConfiguration;
    _session = [NSURLSession sessionWithConfiguration:config delegate:self delegateQueue:nil];
}

- (IBAction)proxy:(id)sender {
    _startTime = MCSTimerStart();
    NSURLRequest *request = [NSURLRequest mcs_requestWithURL:[NSURL URLWithString:@"https://dh2.v.netease.com/2017/cg/fxtpty.mp4"] range:NSMakeRange(0, 10 * 1024 * 1024)];
    NSURLSessionDataTask *task = [_session dataTaskWithRequest:[request mcs_requestWithRedirectURL:[SJMediaCacheServer.shared playbackURLWithURL:request.URL]]];
    NSLog(@"Task<%ld>.proxy resume", task.taskIdentifier);
    [task resume];
}

- (IBAction)network:(id)sender {
    _startTime = MCSTimerStart();
    NSURLRequest *request = [NSURLRequest mcs_requestWithURL:[NSURL URLWithString:@"https://dh2.v.netease.com/2017/cg/fxtpty.mp4"] range:NSMakeRange(0, 10 * 1024 * 1024)];
    NSURLSessionDataTask *task = [_session dataTaskWithRequest:request];
    NSLog(@"Task<%ld>.network resume", task.taskIdentifier);
    [task resume];
}

#pragma mark -

- (void)URLSession:(NSURLSession *)session dataTask:(NSURLSessionDataTask *)dataTask didReceiveResponse:(NSURLResponse *)response completionHandler:(void (^)(NSURLSessionResponseDisposition))completionHandler {
    NSLog(@"Task<%ld> response after (%lf) seconds.", dataTask.taskIdentifier, MCSTimerMilePost(_startTime));
    completionHandler(NSURLSessionResponseAllow);
}

- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task didCompleteWithError:(NSError *)error {
    NSLog(@"Task<%ld> complete after (%lf) seconds.", task.taskIdentifier, MCSTimerMilePost(_startTime));
    printf("\n");
}

@end
