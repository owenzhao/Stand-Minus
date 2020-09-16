//
//  PageViewController.swift
//  Stand Minus
//
//  Created by 肇鑫 on 2017-2-13.
//  Copyright © 2017年 ParusSoft.com. All rights reserved.
//

import UIKit

class PageViewController: UIPageViewController {
    private(set) lazy var orderedViewControllers: [UIViewController] = {
        return [
            UIStoryboard(name: "Main", bundle: nil).instantiateViewController(withIdentifier: "StepOneViewController"),
            UIStoryboard(name: "Main", bundle: nil).instantiateViewController(withIdentifier: "StepTwoViewController"),
            UIStoryboard(name: "Main", bundle: nil).instantiateViewController(withIdentifier: "StepThreeViewController"),
            UIStoryboard(name: "Main", bundle: nil).instantiateViewController(withIdentifier: "aboutViewController")
            ]
    }()

    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
        dataSource = self
        delegate = self
        
        let pageControl:UIPageControl = UIPageControl.appearance()
        pageControl.backgroundColor = UIColor.clear
        pageControl.pageIndicatorTintColor = UIColor.systemGray
        pageControl.currentPageIndicatorTintColor = UIColor.label
        self.view.backgroundColor = .systemBackground
        
        if let firstViewController = orderedViewControllers.first {
            setViewControllers([firstViewController],
                               direction: .forward,
                               animated: true,
                               completion: nil)
        }
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    

    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destinationViewController.
        // Pass the selected object to the new view controller.
    }
    */

}

extension PageViewController:UIPageViewControllerDataSource {
    // In terms of navigation direction. For example, for 'UIPageViewControllerNavigationOrientationHorizontal', view controllers coming 'before' would be to the left of the argument view controller, those coming 'after' would be to the right.
    // Return 'nil' to indicate that no more progress can be made in the given direction.
    // For gesture-initiated transitions, the page view controller obtains view controllers via these methods, so use of setViewControllers:direction:animated:completion: is not required.
    @available(iOS 5.0, *)
    public func pageViewController(_ pageViewController: UIPageViewController, viewControllerBefore viewController: UIViewController) -> UIViewController? {
        if let index = orderedViewControllers.firstIndex(of: viewController) {
            if index == 0 { return nil}
            else { return orderedViewControllers[index - 1] }
        }
            
        return nil
    }
    
    @available(iOS 5.0, *)
    public func pageViewController(_ pageViewController: UIPageViewController, viewControllerAfter viewController: UIViewController) -> UIViewController? {
        if let index = orderedViewControllers.firstIndex(of: viewController) {
            if index == orderedViewControllers.count - 1 {
                return nil
            }
            else { return orderedViewControllers[index + 1] }
        }
        
        return nil
    }
    
    
    // A page indicator will be visible if both methods are implemented, transition style is 'UIPageViewControllerTransitionStyleScroll', and navigation orientation is 'UIPageViewControllerNavigationOrientationHorizontal'.
    // Both methods are called in response to a 'setViewControllers:...' call, but the presentation index is updated automatically in the case of gesture-driven navigation.
    @available(iOS 6.0, *)
    public func presentationCount(for pageViewController: UIPageViewController) -> Int { // The number of items reflected in the page indicator.
        return 3
    }
    
    @available(iOS 6.0, *)
    public func presentationIndex(for pageViewController: UIPageViewController) -> Int { // The selected item reflected in the page indicator.
        if let vc = pageViewController.presentedViewController {
            return orderedViewControllers.firstIndex(of: vc)!
        }
        
        return 0
    }
}

extension PageViewController:UIPageViewControllerDelegate {
    func pageViewController(_ pageViewController: UIPageViewController, willTransitionTo pendingViewControllers: [UIViewController]) {
        if pendingViewControllers.first! == orderedViewControllers.last! {
            self.performSegue(withIdentifier: "quitPageViewControllerSegue", sender: self)
        }
    }
}
