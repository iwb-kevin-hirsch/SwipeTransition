//
//  SwipeBackController.swift
//  SwipeTransition
//
//  Created by Tatsuya Tanaka on 20171222.
//  Copyright © 2017年 tattn. All rights reserved.
//

import UIKit

@objcMembers
public final class SwipeBackController: NSObject {
    public var onStartTransition: ((UIViewControllerContextTransitioning) -> Void)?
    public var onFinishTransition: ((UIViewControllerContextTransitioning) -> Void)?
    private var isFirstPageOfPageViewController: (() -> Bool)?
	public var isCustomBackButton: ((UIBarButtonItem) -> Bool) {
		get { context.isCustomBackButton }
		set { context.isCustomBackButton = newValue }
	}

    public var isEnabled: Bool {
        get { return context.isEnabled }
        set {
            context.isEnabled = newValue
            
            switch newValue {
            case true where panGestureRecognizer.view == nil:
                navigationController?.view.addGestureRecognizer(panGestureRecognizer)
            case true:
                // If already added gesture, do nothing
                break
            case false:
                panGestureRecognizer.view?.removeGestureRecognizer(panGestureRecognizer)
            }
        }
    }

    private lazy var animator = SwipeBackAnimator(parent: self)
    private let context: SwipeBackContext
    private lazy var panGestureRecognizer = OneFingerDirectionalPanGestureRecognizer(direction: .right, target: self, action: #selector(handlePanGesture(_:)))
    private weak var navigationController: UINavigationController?

    public required init(navigationController: UINavigationController) {
        context = SwipeBackContext(target: navigationController)
        super.init()

        self.navigationController = navigationController
        panGestureRecognizer.delegate = self

        navigationController.view.addGestureRecognizer(panGestureRecognizer)
        setNavigationControllerDelegate(navigationController.delegate)

        // Prioritize the default edge swipe over the custom swipe back
        navigationController.interactivePopGestureRecognizer.map { panGestureRecognizer.require(toFail: $0) }
    }

    deinit {
        panGestureRecognizer.view?.removeGestureRecognizer(panGestureRecognizer)
    }

    public func setNavigationControllerDelegate(_ delegate: UINavigationControllerDelegate?) {
        context.navigationControllerDelegateProxy = NavigationControllerDelegateProxy(delegates: [self] + (delegate.map { [$0] } ?? []) )
    }

    public func observePageViewController(_ pageViewController: UIPageViewController, isFirstPage: @escaping () -> Bool) {
        let scrollView = pageViewController.view.subviews
            .lazy
            .compactMap { $0 as? UIScrollView }
            .first
        scrollView?.panGestureRecognizer.require(toFail: panGestureRecognizer)
        context.pageViewControllerPanGestureRecognizer = scrollView?.panGestureRecognizer
        isFirstPageOfPageViewController = isFirstPage
    }

    @objc private func handlePanGesture(_ recognizer: OneFingerDirectionalPanGestureRecognizer) {
        switch recognizer.state {
        case .began:
            context.startTransition()
        case .changed:
            context.updateTransition(recognizer: recognizer)
        case .ended:
            if context.allowsTransitionFinish(recognizer: recognizer) {
                context.finishTransition()
            } else {
                fallthrough
            }
        case .cancelled:
            context.cancelTransition()
        default:
            break
        }
    }
}

extension SwipeBackController: UIGestureRecognizerDelegate {
    public func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        guard context.pageViewControllerPanGestureRecognizer == nil else {
            if gestureRecognizer != context.pageViewControllerPanGestureRecognizer,
                let isFirstPage = isFirstPageOfPageViewController?(), isFirstPage,
                let view = gestureRecognizer.view, panGestureRecognizer.translation(in: view).x > 0 {
                return true
            }
            return false
        }
        return context.allowsTransitionStart
    }

	public func gestureRecognizer(
		_ gestureRecognizer: UIGestureRecognizer,
		shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer
	) -> Bool {
		guard gestureRecognizer == panGestureRecognizer,
			let scrollView = otherGestureRecognizer.view as? UIScrollView
			else { return false }

		return scrollView.contentSize.width > 0 // is scrollable horizontally
	}

	// This will fail the swipe back recognition if swiping left on a horizontal scroll view that is not at origin
	public func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRequireFailureOf otherGestureRecognizer: UIGestureRecognizer) -> Bool {
		guard gestureRecognizer == panGestureRecognizer,
			let scrollView = otherGestureRecognizer.view as? UIScrollView
			else { return false }

		return scrollView.contentSize.width > 0 // is scrollable horizontally
			&& scrollView.contentOffset.x > 0 // is not at origin
	}

	// This will fail the a swiping left on a horizontal scroll view that is at origin in favor of swipe back
	public func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldBeRequiredToFailBy otherGestureRecognizer: UIGestureRecognizer) -> Bool {
		guard gestureRecognizer == panGestureRecognizer,
			let scrollView = otherGestureRecognizer.view as? UIScrollView
			else { return false }

		return scrollView.contentSize.width > 0 // is scrollable horizontally
			&& scrollView.contentOffset.x <= 0 // is at origin
	}

    public func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
        return !(touch.view is UISlider)
    }
}

extension SwipeBackController: UINavigationControllerDelegate {
    public func navigationController(_ navigationController: UINavigationController, animationControllerFor operation: UINavigationController.Operation, from fromVC: UIViewController, to toVC: UIViewController) -> UIViewControllerAnimatedTransitioning? {
        return operation == .pop && context.isEnabled && context.interactiveTransition != nil ? animator : nil
    }

    public func navigationController(_ navigationController: UINavigationController, interactionControllerFor animationController: UIViewControllerAnimatedTransitioning) -> UIViewControllerInteractiveTransitioning? {
        return context.interactiveTransitionIfNeeded()
    }

    public func navigationController(_ navigationController: UINavigationController, willShow viewController: UIViewController, animated: Bool) {
        if animated, context.isEnabled {
            context.transitioning = true
        }
    }

    public func navigationController(_ navigationController: UINavigationController, didShow viewController: UIViewController, animated: Bool) {
        context.transitioning = false
        panGestureRecognizer.isEnabled = navigationController.viewControllers.count > 1
    }
}
