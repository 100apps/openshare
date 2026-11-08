#import "OpenShare+System.h"

NSErrorDomain const OSSystemShareErrorDomain = @"us.gfzj.openshare.system";

@implementation OpenShare (System)

+ (NSArray *)systemActivityItemsForMessage:(OSMessage *)message error:(NSError **)error {
    NSMutableArray *items = [NSMutableArray array];
    NSString *reason = nil;
    if (!message) {
        reason = @"A message is required.";
    } else if (message.file.length) {
        reason = @"Use fileURL for system file sharing; keep the file until completion.";
    } else if (message.multimediaType == OSMultimediaTypeApp ||
               message.multimediaType == OSMultimediaTypeMiniApp) {
        reason = @"App and mini-program messages require a platform adapter.";
    } else if (message.multimediaType == OSMultimediaTypeFile && !message.fileURL) {
        reason = @"File messages require a readable fileURL.";
    } else {
        NSCharacterSet *whitespace = NSCharacterSet.whitespaceAndNewlineCharacterSet;
        if ([message.title stringByTrimmingCharactersInSet:whitespace].length) [items addObject:[message.title copy]];
        if ([message.desc stringByTrimmingCharactersInSet:whitespace].length) [items addObject:[message.desc copy]];
        if (message.link.length) {
            NSURL *url = [NSURL URLWithString:message.link];
            if (!url.host.length || ![@[@"http", @"https"] containsObject:url.scheme.lowercaseString]) {
                reason = @"A link must be an absolute HTTP(S) URL.";
            } else {
                [items addObject:url];
            }
        }
        if (message.image) [items addObject:message.image];
        if (message.fileURL) {
            NSNumber *regularFile = nil;
            if (message.fileURL.isFileURL) {
                [message.fileURL getResourceValue:&regularFile forKey:NSURLIsRegularFileKey error:nil];
            }
            if (!message.fileURL.isFileURL || !regularFile.boolValue ||
                ![[NSFileManager defaultManager] isReadableFileAtPath:message.fileURL.path]) {
                reason = @"fileURL must point to a readable local file.";
            } else {
                [items addObject:message.fileURL];
            }
        }
        if (!items.count && !reason) reason = @"The message has no shareable content.";
    }
    if (reason) {
        if (error) *error = [NSError errorWithDomain:OSSystemShareErrorDomain
                                              code:OSSystemShareErrorInvalidMessage
                                          userInfo:@{NSLocalizedDescriptionKey: reason}];
        return nil;
    }
    return [items copy];
}

+ (void)shareMessage:(OSMessage *)message fromViewController:(UIViewController *)presenter
         sourceView:(UIView *)sourceView completion:(OSSystemShareCompletion)completion {
    if (![NSThread isMainThread]) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (completion) completion(NO, [NSError errorWithDomain:OSSystemShareErrorDomain
                                                               code:OSSystemShareErrorInvalidPresenter
                                                           userInfo:@{NSLocalizedDescriptionKey: @"Present sharing on the main thread."}]);
        });
        return;
    }
    NSError *error = nil;
    NSArray *items = [self systemActivityItemsForMessage:message error:&error];
    if (!items) {
        if (completion) completion(NO, error);
        return;
    }
    if (!presenter.viewIfLoaded.window || presenter.presentedViewController ||
        !sourceView || ![sourceView isDescendantOfView:presenter.view]) {
        if (completion) completion(NO, [NSError errorWithDomain:OSSystemShareErrorDomain
                                                           code:OSSystemShareErrorInvalidPresenter
                                                       userInfo:@{NSLocalizedDescriptionKey: @"A visible presenter and its source view are required."}]);
        return;
    }
    UIActivityViewController *controller = [[UIActivityViewController alloc] initWithActivityItems:items applicationActivities:nil];
    controller.popoverPresentationController.sourceView = sourceView;
    controller.popoverPresentationController.sourceRect = sourceView.bounds;
    controller.completionWithItemsHandler = ^(UIActivityType type, BOOL completed, NSArray *returnedItems, NSError *activityError) {
        if (completion) completion(completed, activityError);
    };
    [presenter presentViewController:controller animated:YES completion:nil];
}
@end
