#import "OpenShare.h"

NS_ASSUME_NONNULL_BEGIN

FOUNDATION_EXPORT NSErrorDomain const OSSystemShareErrorDomain;
typedef NS_ENUM(NSInteger, OSSystemShareError) {
    OSSystemShareErrorInvalidMessage = 1,
    OSSystemShareErrorInvalidPresenter,
};

/// completed means the selected activity completed; it is not proof of publication by a service.
typedef void (^OSSystemShareCompletion)(BOOL completed, NSError * _Nullable error);

@interface OpenShare (System)
/// Build items without presenting UI. Returns nil for empty, malformed or unsupported content.
+ (nullable NSArray *)systemActivityItemsForMessage:(OSMessage *)message
                                             error:(NSError * _Nullable * _Nullable)error
    NS_SWIFT_NAME(systemActivityItems(for:));

/// Call on the main thread with a visible presenter and a source view belonging to that presenter.
/// No platform registration or LSApplicationQueriesSchemes entries are needed.
+ (void)shareMessage:(OSMessage *)message
 fromViewController:(UIViewController *)presenter
         sourceView:(UIView *)sourceView
         completion:(nullable OSSystemShareCompletion)completion
    NS_SWIFT_NAME(share(_:from:sourceView:completion:));
@end

NS_ASSUME_NONNULL_END
