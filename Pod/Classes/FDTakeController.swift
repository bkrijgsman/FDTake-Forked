//
//  FDTakeController.swift
//  FDTakeExample
//
//  Copyright © 2015 William Entriken. All rights reserved.
//

import Foundation
import MobileCoreServices
import UIKit

/// A class for select and taking photos
open class FDTakeController: NSObject /* , UIImagePickerControllerDelegate, UINavigationControllerDelegate*/ {

    // MARK: - Initializers & Class Convenience Methods

    /// Public initializer
    public override init() {
        super.init()
    }

    /// Convenience method for getting a photo
    open class func getPhotoWithCallback(getPhotoWithCallback callback: @escaping (_ photo: UIImage, _ info: [AnyHashable: Any]) -> Void) {
        let fdTake = FDTakeController()
        fdTake.allowsVideo = false
        fdTake.didGetPhoto = callback
        fdTake.present()
    }

    /// Convenience method for getting a video
    open class func getVideoWithCallback(getVideoWithCallback callback: @escaping (_ video: URL, _ info: [AnyHashable: Any]) -> Void) {
        let fdTake = FDTakeController()
        fdTake.allowsPhoto = false
        fdTake.didGetVideo = callback
        fdTake.present()
    }


    // MARK: - Configuration options

    /// Whether to allow selecting a photo
    open var allowsPhoto = true

    /// Whether to allow selecting a video
    open var allowsVideo = true

    /// Whether to allow capturing a photo/video with the camera
    open var allowsTake = true

    /// Whether to allow selecting existing media
    open var allowsSelectFromLibrary = true

    /// Whether to allow editing the media after capturing/selection
    open var allowsEditing = false

    /// Whether to use full screen camera preview on the iPad
    open var iPadUsesFullScreenCamera = false

    /// Enable selfie mode by default
    open var defaultsToFrontCamera = false

    /// The UIBarButtonItem to present from (may be replaced by a overloaded methods)
    open var presentingBarButtonItem: UIBarButtonItem? = nil

    /// The UIView to present from (may be replaced by a overloaded methods)
    open var presentingView: UIView? = nil

    /// The UIRect to present from (may be replaced by a overloaded methods)
    open var presentingRect: CGRect? = nil

    /// The UITabBar to present from (may be replaced by a overloaded methods)
    open var presentingTabBar: UITabBar? = nil

    /// The UIViewController to present from (may be replaced by a overloaded methods)
    open lazy var presentingViewController: UIViewController = {
        return UIApplication.shared.keyWindow!.rootViewController!
    }()


    // MARK: - Callbacks

    /// A photo was selected
    open var didGetPhoto: ((_ photo: UIImage, _ info: [AnyHashable: Any]) -> Void)?

    /// A video was selected
    open var didGetVideo: ((_ video: URL, _ info: [AnyHashable: Any]) -> Void)?

    /// The user selected did not attempt to select a photo
    open var didDeny: (() -> Void)?

    /// The user started selecting a photo or took a photo and then hit cancel
    open var didCancel: (() -> Void)?

    /// A photo or video was selected but the ImagePicker had NIL for EditedImage and OriginalImage
    open var didFail: (() -> Void)?


    // MARK: - Localization overrides

    /// Custom UI text (skips localization)
    open var takePhotoText: String? = nil

    /// Custom UI text (skips localization)
    open var takeVideoText: String? = nil

    /// Custom UI text (skips localization)
    open var chooseFromLibraryText: String? = nil

    /// Custom UI text (skips localization)
    open var chooseFromPhotoRollText: String? = nil

    /// Custom UI text (skips localization)
    open var cancelText: String? = nil

    /// Custom UI text (skips localization)
    open var noSourcesText: String? = nil


    // MARK: - String constants

    fileprivate let kTakePhotoKey: String = "takePhoto"

    fileprivate let kTakeVideoKey: String = "takeVideo"

    fileprivate let kChooseFromLibraryKey: String = "chooseFromLibrary"

    fileprivate let kChooseFromPhotoRollKey: String = "chooseFromPhotoRoll"

    fileprivate let kCancelKey: String = "cancel"

    fileprivate let kNoSourcesKey: String = "noSources"


    // MARK: - Private

    fileprivate lazy var imagePicker: UIImagePickerController = {
        [unowned self] in
        let retval = UIImagePickerController()
        retval.delegate = self
        retval.allowsEditing = true
        return retval
        }()

    fileprivate lazy var popover: UIPopoverController = {
        [unowned self] in
        return UIPopoverController(contentViewController: self.imagePicker)
        }()

    fileprivate var alertController: UIAlertController? = nil

    // This is a hack required on iPad if you want to select a photo and you already have a popup on the screen
    // see: http://stackoverflow.com/a/34392409/300224
    fileprivate func topViewController(_ rootViewController: UIViewController) -> UIViewController {
        var rootViewController = UIApplication.shared.keyWindow!.rootViewController!
        repeat {
            guard let presentedViewController = rootViewController.presentedViewController else {
                return rootViewController
            }

            if let navigationController = rootViewController.presentedViewController as? UINavigationController {
                rootViewController = navigationController.topViewController ?? navigationController

            } else {
                rootViewController = presentedViewController
            }
        } while true
    }

    // MARK: - Localization

    fileprivate func localize(_ key: String, comment: String) -> String {
        return NSLocalizedString(key, tableName: nil, bundle: Bundle(url: Bundle(for: type(of: self)).resourceURL!.appendingPathComponent("FDTake.bundle"))!, value: key, comment: comment)
    }

    fileprivate func textForButtonWithTitle(_ title: String) -> String {
        switch title {
        case kTakePhotoKey:
            return self.takePhotoText ?? localize(kTakePhotoKey, comment: "Option to take photo using camera")
        case kTakeVideoKey:
            return self.takeVideoText ?? localize(kTakeVideoKey, comment: "Option to take video using camera")
        case kChooseFromLibraryKey:
            return self.chooseFromLibraryText ?? localize(kChooseFromLibraryKey, comment: "Option to select photo/video from library")
        case kChooseFromPhotoRollKey:
            return self.chooseFromPhotoRollText ?? localize(kChooseFromPhotoRollKey, comment: "Option to select photo from photo roll")
        case kCancelKey:
            return self.cancelText ?? localize(kCancelKey, comment: "Decline to proceed with operation")
        case kNoSourcesKey:
            return self.noSourcesText ?? localize(kNoSourcesKey, comment: "There are no sources available to select a photo")
        default:
            NSLog("Invalid title passed to textForButtonWithTitle:")
            return "ERROR"
        }
    }

    /// Presents the user with an option to take a photo or choose a photo from the library
    open func present() {
        //TODO: maybe encapsulate source selection?
        var titleToSource = [(buttonTitle: String, source: UIImagePickerControllerSourceType)]()

        if self.allowsTake && UIImagePickerController.isSourceTypeAvailable(.camera) {
            if self.allowsPhoto {
                titleToSource.append((buttonTitle: kTakePhotoKey, source: .camera))
            }
            if self.allowsVideo {
                titleToSource.append((buttonTitle: kTakeVideoKey, source: .camera))
            }
        }
        if self.allowsSelectFromLibrary {
            if UIImagePickerController.isSourceTypeAvailable(.photoLibrary) {
                titleToSource.append((buttonTitle: kChooseFromLibraryKey, source: .photoLibrary))
            } else if UIImagePickerController.isSourceTypeAvailable(.savedPhotosAlbum) {
                titleToSource.append((buttonTitle: kChooseFromPhotoRollKey, source: .savedPhotosAlbum))
            }
        }

        guard titleToSource.count > 0 else {
            let str: String = self.textForButtonWithTitle(kNoSourcesKey)

            //TODO: Encapsulate this
            //TODO: These has got to be a better way to do this
            let alert = UIAlertController(title: nil, message: str, preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: textForButtonWithTitle(kCancelKey), style: .default, handler: nil))

            // http://stackoverflow.com/a/34487871/300224
            let alertWindow = UIWindow(frame: UIScreen.main.bounds)
            alertWindow.rootViewController = UIViewController()
            alertWindow.windowLevel = UIWindowLevelAlert + 1;
            alertWindow.makeKeyAndVisible()
            alertWindow.rootViewController?.present(alert, animated: true, completion: nil)
            return
        }

        var popOverPresentRect : CGRect = self.presentingRect ?? CGRect(x: 0, y: 0, width: 1, height: 1)
        if popOverPresentRect.size.height == 0 || popOverPresentRect.size.width == 0 {
            popOverPresentRect = CGRect(x: 0, y: 0, width: 1, height: 1)
        }

        alertController = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)
        for (title, source) in titleToSource {
            let action = UIAlertAction(title: textForButtonWithTitle(title), style: .default) {
                (UIAlertAction) -> Void in
                self.imagePicker.sourceType = source
                if source == .camera && self.defaultsToFrontCamera && UIImagePickerController.isCameraDeviceAvailable(.front) {
                    self.imagePicker.cameraDevice = .front
                }
                // set the media type: photo or video
                self.imagePicker.allowsEditing = self.allowsEditing
                var mediaTypes = [String]()
                if self.allowsPhoto {
                    mediaTypes.append(String(kUTTypeImage))
                }
                if self.allowsVideo {
                    mediaTypes.append(String(kUTTypeMovie))
                }
                self.imagePicker.mediaTypes = mediaTypes

                //TODO: Need to encapsulate popover code
                var popOverPresentRect: CGRect = self.presentingRect ?? CGRect(x: 0, y: 0, width: 1, height: 1)
                if popOverPresentRect.size.height == 0 || popOverPresentRect.size.width == 0 {
                    popOverPresentRect = CGRect(x: 0, y: 0, width: 1, height: 1)
                }
                let topVC = self.topViewController(self.presentingViewController)

                //
                if UI_USER_INTERFACE_IDIOM() == .phone || (source == .camera && self.iPadUsesFullScreenCamera) {
                    topVC.present(self.imagePicker, animated: true, completion: { _ in })
                } else {
                    // On iPad use pop-overs.
                    self.popover.present(from: popOverPresentRect, in: topVC.view!, permittedArrowDirections: .any, animated: true)
                }
            }
            alertController!.addAction(action)
        }
        let cancelAction = UIAlertAction(title: textForButtonWithTitle(kCancelKey), style: .cancel) {
            (UIAlertAction) -> Void in
            self.didCancel?()
        }
        alertController!.addAction(cancelAction)

        let topVC = topViewController(presentingViewController)

        alertController?.modalPresentationStyle = .popover
        if let presenter = alertController!.popoverPresentationController {
            presenter.sourceView = presentingView;
            if let presentingRect = self.presentingRect {
                presenter.sourceRect = presentingRect
            }
            //WARNING: on ipad this fails if no SOURCEVIEW AND SOURCE RECT is provided
        }
        topVC.present(alertController!, animated: true, completion: nil)
    }

    /// Dismisses the displayed view. Especially handy if the sheet is displayed while suspending the app,
    open func dismiss() {
        alertController?.dismiss(animated: true, completion: nil)
        imagePicker.dismiss(animated: true, completion: nil)
    }
}

extension FDTakeController : UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    /// Conformance for ImagePicker delegate
    public func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [String : Any]) {
        UIApplication.shared.isStatusBarHidden = true
        let mediaType: String = info[UIImagePickerControllerMediaType] as! String
        var imageToSave: UIImage
        // Handle a still image capture
        if mediaType == kUTTypeImage as String {
            if let editedImage = info[UIImagePickerControllerEditedImage] as? UIImage {
                imageToSave = editedImage
            } else if let originalImage = info[UIImagePickerControllerOriginalImage] as? UIImage {
                imageToSave = originalImage
            } else {
                self.didCancel?()
                return
            }
            self.didGetPhoto?(imageToSave, info)
            if UI_USER_INTERFACE_IDIOM() == .pad {
                self.popover.dismiss(animated: true)
            }
        } else if mediaType == kUTTypeMovie as String {
            self.didGetVideo?(info[UIImagePickerControllerMediaURL] as! URL, info)
        }

        picker.dismiss(animated: true, completion: nil)
    }

    /// Conformance for image picker delegate
    public func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        UIApplication.shared.isStatusBarHidden = true
        picker.dismiss(animated: true, completion: { _ in })
        self.didDeny?()
    }
}
