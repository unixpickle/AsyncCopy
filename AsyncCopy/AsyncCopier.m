//
//  AsyncCopier.m
//  AsyncCopy
//
//  Created by Alex Nichol on 10/27/11.
//  Copyright (c) 2011 __MyCompanyName__. All rights reserved.
//

#import "AsyncCopier.h"

@interface AsyncCopier (Private)

+ (NSMutableArray *)staticCopierPool;
+ (void)copierPoolPush:(AsyncCopier *)copier;
+ (void)copierPoolPop:(AsyncCopier *)copier;

- (void)unscheduleCopier;
- (void)handleCallback:(NSString *)currentItem status:(FSFileOperationStage)stage progress:(double)progress;

@end

void AsyncCopierCallback (FSFileOperationRef fileOp,
						  const FSRef * currentItem,
						  FSFileOperationStage stage,
						  OSStatus error,
						  CFDictionaryRef statusDictionary,
						  void * info);

@implementation AsyncCopier

@synthesize currentItem;

+ (BOOL)asyncCopySource:(NSString *)source
			destination:(NSString *)destination
			   callback:(CopierCallback)callback {
	AsyncCopier * copier = [[AsyncCopier alloc] initWithSource:source destination:destination callback:callback];
	if (!copier) return NO;
	return YES;
}

- (id)initWithSource:(NSString *)fileSource
		 destination:(NSString *)fileDestination
			callback:(CopierCallback)copierCallback {
	if ((self = [super init])) {
		NSString * destPath;
		NSString * destName;
		if (![[NSFileManager defaultManager] fileExistsAtPath:fileSource]) {
			return nil;
		}
		if ([[NSFileManager defaultManager] fileExistsAtPath:fileDestination]) {
			destPath = fileDestination;
			destName = [fileSource lastPathComponent];
		} else {
			destPath = [fileDestination stringByDeletingLastPathComponent];
			destName = [fileDestination lastPathComponent];
		}
		FSFileOperationClientContext context;
		FSRef sourceRef;
		FSRef destRef;
		
		// setup the FSRefs
		if (FSPathMakeRef((const UInt8 *)[fileSource UTF8String], &sourceRef, NULL) != noErr) {
			return nil;
		}
		if (FSPathMakeRef((const UInt8 *)[destPath UTF8String], &destRef, NULL) != noErr) {
			return nil;
		}
		
		// setup the context
		context.info = (__bridge void *)self;
		context.release = NULL;
		context.retain = NULL;
		context.copyDescription = NULL;
		context.version = 0;
		
		fileOperation = FSFileOperationCreate(NULL);
		
		mainLoop = (CFRunLoopRef)CFRetain(CFRunLoopGetCurrent());
		
		FSCopyObjectAsync(fileOperation, &sourceRef, &destRef, (__bridge CFStringRef)destName, 0, AsyncCopierCallback, 1, &context);
		FSFileOperationScheduleWithRunLoop(fileOperation, mainLoop, kCFRunLoopDefaultMode);
		
		callback = copierCallback;
		
		[[self class] copierPoolPush:self];
	}
	return self;
}

- (void)cancelOperation {
	if (![self isComplete]) {
		FSFileOperationCancel(fileOperation);
	}
	[self unscheduleCopier];
}

- (OSStatus)operationStatus {
	if (fileOperation) {
		FSFileOperationStage stage = 0;
		FSRef fsRef;
		OSStatus errorStatus = noErr;
		CFDictionaryRef statusDict = NULL;
		void * pointerData = NULL;
		
		if (FSFileOperationCopyStatus(fileOperation, &fsRef, &stage, &errorStatus,
									  &statusDict, &pointerData) != noErr) {
			return YES;
		}
		if (statusDict) CFRelease(statusDict);
		return errorStatus;
	}
	return noErr;
}

- (BOOL)isComplete {
	if (fileOperation) {
		FSFileOperationStage stage = 0;
		FSRef fsRef;
		OSStatus errorStatus = noErr;
		CFDictionaryRef statusDict = NULL;
		void * pointerData = NULL;
		
		if (FSFileOperationCopyStatus(fileOperation, &fsRef, &stage, &errorStatus,
									  &statusDict, &pointerData) != noErr) {
			return YES;
		}
		if (statusDict) CFRelease(statusDict);
		
		if (stage == kFSOperationStageComplete || errorStatus != noErr) return YES;
		return NO;
	}
	return YES;
}

- (void)dealloc {
	if (fileOperation) {
		[self cancelOperation];
		CFRelease(fileOperation);
	}
	if (mainLoop) CFRelease(mainLoop);
}

#pragma mark - Private -

- (void)unscheduleCopier {
	if (!wasUnscheduled) {
		FSFileOperationUnscheduleFromRunLoop(fileOperation, mainLoop, kCFRunLoopDefaultMode);
		wasUnscheduled = YES;
		CFRelease(mainLoop);
		mainLoop = nil;
		[[self class] copierPoolPop:self];
	}
}

- (void)handleCallback:(NSString *)currentItem status:(FSFileOperationStage)stage progress:(double)progress {
	if (stage == kFSOperationStageComplete || stage == kFSOperationStageUndefined) {
		if ([self operationStatus] != noErr) {
			callback(self, CopierCallbackTypeFailed, progress);
			[self unscheduleCopier];
		} else {
			callback(self, CopierCallbackTypeDone, progress);
			[self unscheduleCopier];
		}
	} else {
		callback(self, CopierCallbackTypeProgress, progress);
	}
}

#pragma mark Copier Pool

+ (NSMutableArray *)staticCopierPool {
	static NSMutableArray * array = nil;
	static dispatch_once_t onceToken;
	dispatch_once(&onceToken, ^{
		array = [[NSMutableArray alloc] init];
	});
	return array;
}

+ (void)copierPoolPush:(AsyncCopier *)copier {
	[[self staticCopierPool] addObject:copier];
}

+ (void)copierPoolPop:(AsyncCopier *)copier {
	[[self staticCopierPool] removeObject:copier];
}

@end

void AsyncCopierCallback (FSFileOperationRef fileOp,
						  const FSRef * theCurrentItem,
						  FSFileOperationStage stage,
						  OSStatus error,
						  CFDictionaryRef statusDictionary,
						  void * info) {
	NSString * currentItem = nil;
	if (theCurrentItem) {
		CFURLRef theURL = CFURLCreateFromFSRef(kCFAllocatorDefault, theCurrentItem);
		currentItem = [(__bridge_transfer NSURL *)theURL path];
	}
	CFNumberRef bytesCompleted = (CFNumberRef)CFDictionaryGetValue(statusDictionary, kFSOperationBytesCompleteKey);
	CFNumberRef bytesTotal = (CFNumberRef)CFDictionaryGetValue(statusDictionary, kFSOperationTotalBytesKey);
	double dCompleted, dTotal, progress = 0;
	if (bytesCompleted && bytesTotal) {
		CFNumberGetValue(bytesCompleted, kCFNumberDoubleType, &dCompleted);
		CFNumberGetValue(bytesTotal, kCFNumberDoubleType, &dTotal);
		progress = dCompleted / dTotal;
	}
	AsyncCopier * copier = (__bridge AsyncCopier *)info;
	[copier handleCallback:currentItem status:stage progress:progress];
}
