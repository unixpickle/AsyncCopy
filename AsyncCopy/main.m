//
//  main.m
//  AsyncCopy
//
//  Created by Alex Nichol on 10/27/11.
//  Copyright (c) 2011 __MyCompanyName__. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "AsyncCopier.h"

#define kBarLength 30

NSString * readLine (FILE * file);

int main (int argc, const char * argv[]) {
	@autoreleasepool {
		NSString * source = nil;
		NSString * destination = nil;
		printf("Source: ");
		source = readLine(stdin);
		printf("Destination: ");
		destination = readLine(stdin);
		BOOL result = [AsyncCopier asyncCopySource:source destination:destination
										  callback:^(AsyncCopier * copier, CopierCallbackType type, double progress) {
			if (type == CopierCallbackTypeDone) {
				printf("\nDone\n");
				exit(0);
			} else if (type == CopierCallbackTypeFailed) {
				printf("\nError!\n");
				exit(1);
			} else {
				int numStars = round(progress * kBarLength);
				printf("|");
				for (int i = 0; i < numStars; i++) {
					printf("*");
				}
				for (int i = numStars; i < kBarLength; i++) {
					printf("-");
				}
				printf("|  (");
				printf("%d%%)  \r", (int)round(progress * 100));
				fflush(stdout);
			}
		}];
		if (!result) {
			printf("Failed to begin\n");
			return -1;
		}
		[[NSRunLoop currentRunLoop] run];
	}
	return 0;
}

NSString * readLine (FILE * file) {
	NSMutableString * string = [[NSMutableString alloc] init];
	int c;
	while ((c = fgetc(file)) != EOF) {
		if (c == '\n') break;
		if (c != '\r') {
			[string appendFormat:@"%c", (char)c];
		}
	}
	return string;
}
