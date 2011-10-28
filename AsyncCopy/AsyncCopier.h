//
//  AsyncCopier.h
//  AsyncCopy
//
//  Created by Alex Nichol on 10/27/11.
//  Copyright (c) 2011 __MyCompanyName__. All rights reserved.
//

#import <Foundation/Foundation.h>

@class AsyncCopier;

typedef enum {
	CopierCallbackTypeProgress,
	CopierCallbackTypeFailed,
	CopierCallbackTypeDone
} CopierCallbackType;

typedef void (^CopierCallback)(AsyncCopier * copier, CopierCallbackType type, double progress);

@interface AsyncCopier : NSObject {
	FSFileOperationRef fileOperation;
	CopierCallback callback;
	NSString * currentItem;
	BOOL wasUnscheduled;
	CFRunLoopRef mainLoop;
}

@property (readonly) NSString * currentItem;

+ (BOOL)asyncCopySource:(NSString *)source
			destination:(NSString *)destination
			   callback:(CopierCallback)callback;
- (id)initWithSource:(NSString *)fileSource
		 destination:(NSString *)fileDestination
			callback:(CopierCallback)copierCallback;
- (void)cancelOperation;
- (BOOL)isComplete;
- (OSStatus)operationStatus;

@end
