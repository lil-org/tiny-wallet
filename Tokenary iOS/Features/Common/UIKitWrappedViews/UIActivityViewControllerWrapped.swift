// Copyright © 2022 Tokenary. All rights reserved.

import SwiftUI
import UIKit

struct UIActivityViewControllerWrapper: UIViewControllerRepresentable {
    struct Config {
        let activityItems: [Any]
        var applicationActivities: [UIActivity]?
        var excludedActivityTypes: [UIActivity.ActivityType]?
    }
    
    private class ActivityViewControllerInternalWrapper: UIViewController {
        @Binding
        private var isPresented: Bool
        private let config: Config
        private var activityVCWrapper: UIActivityViewController?
        private var isPreparingForPresentation: Bool = false
        private var bindView: Binding<UIView?>
        
        init(isPresented: Binding<Bool>, config: Config, bindView: Binding<UIView?>) {
            self._isPresented = isPresented
            self.config = config
            self.bindView = bindView
            super.init(nibName: nil, bundle: nil)
        }
        
        required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
        
        fileprivate func prepareActivity() {
            guard self.isPreparingForPresentation == false else { return }
            self.isPreparingForPresentation = true
            DispatchQueue.global().async { [self] in
                guard self.activityVCWrapper == nil else { return }
                self.activityVCWrapper = UIActivityViewController(
                    activityItems: self.config.activityItems,
                    applicationActivities: self.config.applicationActivities
                ).then {
                    $0.completionWithItemsHandler = { _, _, _, _ in
                        self.$isPresented.wrappedValue = false
                    }
                    $0.excludedActivityTypes = self.config.excludedActivityTypes
                }
                DispatchQueue.main.async { [self] in
                    self.showActivity()
                }
            }
        }
        
        fileprivate func showActivity() {
            guard
                self.viewIfLoaded?.window != nil, self.isPresented
            else {
                self.pollForWindow()
                return
            }
            if UIDevice.isPad {
                let presentationVC = self.activityVCWrapper!.popoverPresentationController
                presentationVC?.sourceView = self.bindView.wrappedValue
            }
            self.present(self.activityVCWrapper!, animated: true, completion: {
                self.isPreparingForPresentation = false
                self.activityVCWrapper = nil
            })
        }
        
        private func pollForWindow() {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
                self?.showActivity()
            }
        }
    }

    @Binding
    var isPresented: Bool
    @Binding
    var bindView: UIView?
    
    private let config: Config

    init(isPresented: Binding<Bool>, config: Config, bindView: Binding<UIView?>) {
        self._isPresented = isPresented
        self._bindView = bindView
        self.config = config
    }

    func makeUIViewController(context: Context) -> UIViewController {
        ActivityViewControllerInternalWrapper(isPresented: self.$isPresented, config: self.config, bindView: self.$bindView)
    }

    func updateUIViewController(
        _ uiViewController: UIViewController,
        context: Context
    ) {
        if self.isPresented {
            (uiViewController as? ActivityViewControllerInternalWrapper)?.prepareActivity()
        } else {
            uiViewController.dismissAnimated()
        }
    }
}

extension View {
    func activityShare(
        isPresented: Binding<Bool>,
        config: UIActivityViewControllerWrapper.Config,
        bindView: Binding<UIView?>
    ) -> some View {
        self.background(
            UIActivityViewControllerWrapper(isPresented: isPresented, config: config, bindView: bindView)
        )
    }
}
