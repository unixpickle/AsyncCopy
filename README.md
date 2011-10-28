The Premise
===

When copying files, apps like Finder use the `FSFileOperation` API. This is a Carbon API for standard file system operations such as moving, copying, deleting, and renaming files and directories. When copying directories, this API can even give progress updates as to how much of the data it has transferred so far.

Using this functionality, I set out to make an Objective-C wrapper for `FSFileOperation`. This wrapper would utilize blocks to make file copying a one-call operation, that, in turn could provide status updates on the file or folder being copied.

Usage
===

You can see <tt>main.m</tt> for in-depth usage of the `AsyncCopier` class. In short, here is how one might use it:

	BOOL result = [AsyncCopier asyncCopySource:source 
	                               destination:destination
	                                  callback:^(AsyncCopier * copier, CopierCallbackType type, double progress) {
	    // handle progress update
	}];
	if (!result) {
	    NSLog(@"Failed to begin file transfer.");
	}

License
===

None of the code in this project is under license of any kind. Essentially, you can use this code without fearing prosecution in court. For all I care, you can steal this code, and say that you made it while standing on one foot and touching your nose.