//
//  SwipeBackAnimator.swift
//  SwipeTransition
//
//  Created by Tatsuya Tanaka on 20171222.
//  Copyright © 2017年 tattn. All rights reserved.
//

import UIKit

final class SwipeBackAnimator: NSObject {
    private weak var parent: SwipeBackController!
    private weak var toView: UIView?
    required init(parent: SwipeBackController) {
        super.init()
        self.parent = parent
    }
}

extension SwipeBackAnimator: UIViewControllerAnimatedTransitioning {
    func transitionDuration(using transitionContext: UIViewControllerContextTransitioning?) -> TimeInterval {
        return SwipeBackConfiguration.shared.transitionDuration
    }

    func animateTransition(using transitionContext: UIViewControllerContextTransitioning) {
        guard let to = transitionContext.viewController(forKey: .to),
            let from = transitionContext.viewController(forKey: .from) else { return }
        transitionContext.containerView.insertSubview(to.view, belowSubview: from.view)
        toView = to.view

		let containerWidth = transitionContext.containerView.bounds.width
		let parallaxFactor = SwipeBackConfiguration.shared.parallaxFactor

        // parallax effect
        to.view.transform.tx = -containerWidth * parallaxFactor

        // when hidesBottomBarWhenPushed = true
        let tabBar = to.tabBarController?.tabBar
        let shouldAnimateTabBar = tabBar != nil && from.hidesBottomBarWhenPushed

        if shouldAnimateTabBar {
            tabBar!.frame.origin.x = -containerWidth * parallaxFactor
            transitionContext.containerView.insertSubview(tabBar!, belowSubview: from.view)
        }

        // dim the back view
        let dimmedView = UIView(frame: to.view.bounds)
        dimmedView.backgroundColor = UIColor(white: 0, alpha: SwipeBackConfiguration.shared.backViewDimness)
        to.view.addSubview(dimmedView)

        parent.onStartTransition?(transitionContext)

        UIView.animate(
            withDuration: transitionDuration(using: transitionContext),
            delay: 0,
            options: UIView.AnimationOptions.curveLinear,
            animations: {
				if shouldAnimateTabBar {
                    tabBar!.frame.origin.x = 0
				}

                to.view.transform = .identity
                from.view.transform = CGAffineTransform(translationX: to.view.frame.width, y: 0)
                dimmedView.alpha = 0
        }, completion: { [weak self] _ in
			if shouldAnimateTabBar {
				to.tabBarController!.view.addSubview(tabBar!)
			}

            dimmedView.removeFromSuperview()
            from.view.transform = .identity
            self?.parent.onFinishTransition?(transitionContext)
            transitionContext.completeTransition(!transitionContext.transitionWasCancelled)
        })
    }

    func animationEnded(_ transitionCompleted: Bool) {
        if !transitionCompleted {
            toView?.transform = .identity
        }
    }
}
