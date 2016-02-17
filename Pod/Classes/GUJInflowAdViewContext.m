/*
 * BSD LICENSE
 * Copyright (c) 2015, Mobile Unit of G+J Electronic Media Sales GmbH, Hamburg All rights reserved.
 * Redistribution and use in source and binary forms, with or without modification,
 * are permitted provided that the following conditions are met:
 * Redistributions of source code must retain the above copyright notice,
 * this list of conditions and the following disclaimer .
 * Redistributions in binary form must reproduce the above copyright notice,
 * this list of conditions and the following disclaimer in the documentation
 * and/or other materials provided with the distribution.
 *
 * THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
 * AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO,
 * THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
 * ARE DISCLAIMED.
 * IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT,
 * INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
 * (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
 * LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
 * ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY,
 * OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
 * OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 *
 */


#import "GUJInflowAdViewContext.h"

@implementation GUJInflowAdViewContext {
    id <UIScrollViewDelegate> originalScrollViewDelegate;
    BOOL adViewExpanded, adsManagerInitialized;
    IMAAdsLoader *_adsLoader;
    IMAAdsManager *_adsManager;

    AVPlayer *avPlayer;
    UIButton *unmuteButton;
    UIButton *closeButton;
    UIImage *endScreenImage;

    TeadsVideo *teadsVideo;
}


- (instancetype)initWithScrollView:(UIScrollView *)scrollView inFlowAdPlaceholderView:(UIView *)inFlowAdPlaceholderView inFlowAdPlaceholderViewHeightConstraint:(NSLayoutConstraint *)inFlowAdPlaceholderViewHeightConstraint {
    self = [super init];
    if (self) {
        self.scrollView = scrollView;
        self.inFlowAdPlaceholderView = inFlowAdPlaceholderView;
        self.inFlowAdPlaceholderViewHeightConstraint = inFlowAdPlaceholderViewHeightConstraint;

        self.inFlowAdPlaceholderView.backgroundColor = [UIColor blackColor];
        self.inFlowAdPlaceholderView.clipsToBounds = YES;

        _adsLoader = [[IMAAdsLoader alloc] initWithSettings:nil];
        _adsLoader.delegate = self;

        [self requestAds];
    }

    return self;
}


+ (instancetype)contextWithScrollView:(UIScrollView *)scrollView inFlowAdPlaceholderView:(UIView *)inFlowAdPlaceholderView inFlowAdPlaceholderViewHeightConstraint:(NSLayoutConstraint *)inFlowAdPlaceholderViewHeightConstraint {
    return [[self alloc] initWithScrollView:scrollView inFlowAdPlaceholderView:inFlowAdPlaceholderView inFlowAdPlaceholderViewHeightConstraint:inFlowAdPlaceholderViewHeightConstraint];
}


- (void)containerViewDidAppear {
    NSLog(@"containerViewDidAppear");

    originalScrollViewDelegate = self.scrollView.delegate;
    self.scrollView.delegate = self;

    if (teadsVideo.isLoaded) {
        [teadsVideo viewControllerAppeared:self.findInFlowAdPlaceholderViewsViewController];
    }
}


- (void)containerViewWillDisappear {
    self.scrollView.delegate = originalScrollViewDelegate;
}


- (void)checkIfScrolledIntoView {

    CGRect adViewRect = self.inFlowAdPlaceholderView.frame;
    CGRect scrollViewRect = CGRectMake(
            self.scrollView.contentOffset.x,
            self.scrollView.contentOffset.y,
            self.scrollView.frame.size.width,
            self.scrollView.frame.size.height);

    if (!adViewExpanded && CGRectIntersectsRect(adViewRect, scrollViewRect)) {
        [self expandAdView:YES];
    }
}


- (void)expandAdView:(BOOL)expand {

    if (expand != adViewExpanded) {

        adViewExpanded = expand;
        self.inFlowAdPlaceholderViewHeightConstraint.constant = expand ? 180 : 0;

        [UIView animateWithDuration:1.0f delay:0.2f options:UIViewAnimationOptionAllowUserInteraction animations:^{
            [self.inFlowAdPlaceholderView.superview layoutIfNeeded];
        }                completion:^(BOOL finished) {
            if (!adsManagerInitialized) {
                [self initAdsManager];
            }
        }];
    }

}


#pragma mark SDK Setup


- (void)requestAds {
    // Create an ad display container for ad rendering.
    IMAAdDisplayContainer *adDisplayContainer =
            [[IMAAdDisplayContainer alloc] initWithAdContainer:self.inFlowAdPlaceholderView companionSlots:nil];


    NSString *const kTestAppAdTagUrl =
            @"https://pubads.g.doubleclick.net/gampad/ads?sz=480x360&iu=/6032/sdktest/preroll&impl=s&gdfp_req=1&env=vp&output=xml_vast2";


    // Create an ad request with our ad tag, display container, and optional user context.
    IMAAdsRequest *request = [[IMAAdsRequest alloc] initWithAdTagUrl:kTestAppAdTagUrl
                                                  adDisplayContainer:adDisplayContainer
                                                     contentPlayhead:self
                                                         userContext:nil];
    [_adsLoader requestAdsWithRequest:request];
}


#pragma mark AdsLoader Delegates

- (void)adsLoader:(IMAAdsLoader *)loader adsLoadedWithData:(IMAAdsLoadedData *)adsLoadedData {

    NSLog(@"adsLoadedWithData");

    _adsManager = adsLoadedData.adsManager;
    _adsManager.delegate = self;

    if (adViewExpanded) {
        [self initAdsManager];
    }
}


- (void)initAdsManager {
    adsManagerInitialized = YES;

    // Create ads rendering settings to tell the SDK to use the in-app browser.
    IMAAdsRenderingSettings *adsRenderingSettings = [[IMAAdsRenderingSettings alloc] init];
    adsRenderingSettings.webOpenerPresentingController = [self findInFlowAdPlaceholderViewsViewController];

    [_adsManager initializeWithAdsRenderingSettings:adsRenderingSettings];

    avPlayer = [self discoverAVPlayer];
    avPlayer.muted = YES;
}


- (AVPlayer *)discoverAVPlayer {
    if (self.inFlowAdPlaceholderView.subviews.count > 0) {
        UIView /*IMAAdView */ *adView = self.inFlowAdPlaceholderView.subviews[0];
        if (adView.subviews.count > 0) {
            UIView /*IMAAdPlayerView*/ *adPlayerView = adView.subviews[0];
            if ([adPlayerView respondsToSelector:@selector(delegate)]) {
                id /*IMAAVPlayerVideoDisplay */ avPlayerVideoDisplay = [adPlayerView performSelector:@selector(delegate)];
                if ([avPlayerVideoDisplay respondsToSelector:@selector(player)]) {
                    return [avPlayerVideoDisplay performSelector:@selector(player)];
                }
            }
        }
    }
    NSLog(@"AVPlayer not found!");
    return nil;
}


- (void)toggleAudioMuting {
    avPlayer.muted = !avPlayer.muted;
    unmuteButton.selected = !avPlayer.muted;
}


- (void)close {
    [self expandAdView:NO];
}


- (void)adsLoader:(IMAAdsLoader *)loader failedWithErrorData:(IMAAdLoadingErrorData *)adErrorData {
    // Something went wrong loading ads. May be no fill.
    NSLog(@"Error loading ads: %@", adErrorData.adError.message);

    NSLog(@"using Teads Ads as fallback...");
    self.teadsPlacementID = @"47140";
    teadsVideo = [[TeadsVideo alloc] initInReadWithPlacementId:self.teadsPlacementID
                                                   placeholder:self.inFlowAdPlaceholderView
                                              heightConstraint:self.inFlowAdPlaceholderViewHeightConstraint
                                                    scrollView:self.scrollView
                                                      delegate:self];

    [teadsVideo load];

}


- (UIViewController *)findInFlowAdPlaceholderViewsViewController {
    UIResponder *responder = self.inFlowAdPlaceholderView;
    while (![responder isKindOfClass:[UIViewController class]]) {
        responder = [responder nextResponder];
        if (nil == responder) {
            break;
        }
    }
    return (UIViewController *) responder;
}


- (UIImage *)screenshotFromPlayer:(AVPlayer *)player {

    CMTime actualTime;
    NSError *error;

    AVAssetImageGenerator *generator = [[AVAssetImageGenerator alloc] initWithAsset:player.currentItem.asset];

    CGImageRef cgIm = [generator copyCGImageAtTime:player.currentTime
                                        actualTime:&actualTime
                                             error:&error];
    UIImage *image = [UIImage imageWithCGImage:cgIm];
    CFRelease(cgIm);

    if (nil != error) {
        NSLog(@"error making screenshot: %@", [error localizedDescription]);
        NSLog(@"actual screenshot time: %f ", CMTimeGetSeconds(actualTime));
        return nil;
    }

    return image;
}


#pragma mark AdsManager Delegate

- (void)adsManager:(IMAAdsManager *)adsManager didReceiveAdEvent:(IMAAdEvent *)event {

    NSLog(@"didReceiveAdEvent: %@", event.typeString);

    if (event.type == kIMAAdEvent_LOADED) {
        [adsManager start];
    }

    if (event.type == kIMAAdEvent_STARTED) {
        unmuteButton = [UIButton buttonWithType:UIButtonTypeCustom];
        [unmuteButton setImage:[UIImage imageNamed:@"gujemsiossdk.bundle/sound_off_white.png"] forState:UIControlStateNormal];
        [unmuteButton setImage:[UIImage imageNamed:@"gujemsiossdk.bundle/sound_on_white.png"] forState:UIControlStateSelected];
        [unmuteButton addTarget:self
                         action:@selector(toggleAudioMuting)
               forControlEvents:UIControlEventTouchUpInside];
        unmuteButton.frame = CGRectMake((CGFloat) (self.inFlowAdPlaceholderView.frame.size.width - 30.0), (CGFloat) (self.inFlowAdPlaceholderView.frame.size.height - 30.0), 20.0, 20.0);
        [self.inFlowAdPlaceholderView addSubview:unmuteButton];
    }

    if (event.type == kIMAAdEvent_COMPLETE) {
        endScreenImage = [self screenshotFromPlayer:avPlayer];

        UIImageView *imageView = [[UIImageView alloc] initWithImage:endScreenImage];
        imageView.frame = CGRectMake(0, 0, self.inFlowAdPlaceholderView.frame.size.width, self.inFlowAdPlaceholderView.frame.size.height);
        imageView.contentMode = UIViewContentModeScaleAspectFit;
        [self.inFlowAdPlaceholderView addSubview:imageView];

        closeButton = [UIButton buttonWithType:UIButtonTypeCustom];
        [closeButton setImage:[UIImage imageNamed:@"gujemsiossdk.bundle/close_white.png"] forState:UIControlStateNormal];
        [closeButton addTarget:self
                        action:@selector(close)
              forControlEvents:UIControlEventTouchUpInside];
        closeButton.frame = CGRectMake((CGFloat) (self.inFlowAdPlaceholderView.frame.size.width - 30.0), 10.0, 20.0, 20.0);
        [self.inFlowAdPlaceholderView addSubview:closeButton];
    }
}


- (void)adsManager:(IMAAdsManager *)adsManager didReceiveAdError:(IMAAdError *)error {
    // Something went wrong with the ads manager after ads were loaded. Log the error.
    NSLog(@"didReceiveAdError: %@", error.message);
}


- (void)adsManagerDidRequestContentPause:(IMAAdsManager *)adsManager {
    // ignored because we don't have an underlying video
}


- (void)adsManagerDidRequestContentResume:(IMAAdsManager *)adsManager {
    // ignored because we don't have an underlying video
}


# pragma mark - UIScrollViewDelegate

// we are only interested in the scrollViewDidScroll: event, original
// delegate methods shall always be called!

- (void)scrollViewDidScroll:(UIScrollView *)scrollView {
    [self checkIfScrolledIntoView];
    [originalScrollViewDelegate scrollViewDidScroll:scrollView];
}

- (void)scrollViewDidZoom:(UIScrollView *)scrollView {
    [originalScrollViewDelegate scrollViewDidZoom:scrollView];
}

- (void)scrollViewWillBeginDragging:(UIScrollView *)scrollView {
    [originalScrollViewDelegate scrollViewWillBeginDragging:scrollView];
}

- (void)scrollViewWillEndDragging:(UIScrollView *)scrollView withVelocity:(CGPoint)velocity targetContentOffset:(inout CGPoint *)targetContentOffset {
    [originalScrollViewDelegate scrollViewWillEndDragging:scrollView withVelocity:velocity targetContentOffset:targetContentOffset];
}

- (void)scrollViewDidEndDragging:(UIScrollView *)scrollView willDecelerate:(BOOL)decelerate {
    [originalScrollViewDelegate scrollViewDidEndDragging:scrollView willDecelerate:decelerate];
}

- (void)scrollViewWillBeginDecelerating:(UIScrollView *)scrollView {
    [originalScrollViewDelegate scrollViewWillBeginDecelerating:scrollView];
}

- (void)scrollViewDidEndDecelerating:(UIScrollView *)scrollView {
    [originalScrollViewDelegate scrollViewDidEndDecelerating:scrollView];
}

- (void)scrollViewDidEndScrollingAnimation:(UIScrollView *)scrollView {
    [originalScrollViewDelegate scrollViewDidEndScrollingAnimation:scrollView];
}

- (UIView *)viewForZoomingInScrollView:(UIScrollView *)scrollView {
    return [originalScrollViewDelegate viewForZoomingInScrollView:scrollView];;
}

- (void)scrollViewWillBeginZooming:(UIScrollView *)scrollView withView:(UIView *)view {
    [originalScrollViewDelegate scrollViewWillBeginZooming:scrollView withView:view];
}

- (void)scrollViewDidEndZooming:(UIScrollView *)scrollView withView:(UIView *)view atScale:(CGFloat)scale {
    [originalScrollViewDelegate scrollViewDidEndZooming:scrollView withView:view atScale:scale];
}

- (BOOL)scrollViewShouldScrollToTop:(UIScrollView *)scrollView {
    return [originalScrollViewDelegate scrollViewShouldScrollToTop:scrollView];;
}

- (void)scrollViewDidScrollToTop:(UIScrollView *)scrollView {
    [originalScrollViewDelegate scrollViewDidScrollToTop:scrollView];
}

@end