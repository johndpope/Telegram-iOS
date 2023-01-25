import Foundation
import UIKit
import Display
import AsyncDisplayKit
import SwiftSignalKit
import TelegramCore
import TelegramPresentationData
import TelegramUIPreferences
import DeviceAccess
import AccountContext
import AlertUI
import PresentationDataUtils
import TelegramPermissions
import TelegramNotices
import ContactsPeerItem
import SearchUI
import TelegramPermissionsUI
import AppBundle
import StickerResources
import ContextUI
import QrCodeUI
import ContactsUI
import GalleryUI

public class WEVGalleryViewController: GalleryController {
    private let context: AccountContext
    public func accountContext()->AccountContext{
        return context
    }
    private var presentationData: PresentationData
    private var presentationDataDisposable: Disposable?
    private var authorizationDisposable: Disposable?
    private let sortOrderPromise = Promise<ContactsSortOrder>()
    private let isInVoiceOver = ValuePromise<Bool>(false)
    
    private var searchContentNode: NavigationBarSearchContentNode?
    
    public var switchToChatsController: (() -> Void)?
    
    
    
    public override init(context: AccountContext, source: GalleryControllerItemSource, invertItemOrder: Bool = false, streamSingleVideo: Bool = false, fromPlayingVideo: Bool = false, landscape: Bool = false, timecode: Double? = nil, playbackRate: Double? = nil, synchronousLoad: Bool = false, replaceRootController: @escaping (ViewController, Promise<Bool>?) -> Void, baseNavigationController: NavigationController?, actionInteraction: GalleryControllerActionInteraction? = nil) {

        self.context = context
        self.presentationData = context.sharedContext.currentPresentationData.with { $0 }
        super.init(context:context,source:source,invertItemOrder:invertItemOrder,streamSingleVideo: streamSingleVideo,fromPlayingVideo: fromPlayingVideo,landscape: landscape,timecode: timecode,playbackRate: playbackRate,synchronousLoad: synchronousLoad,replaceRootController: replaceRootController,baseNavigationController: baseNavigationController)

   
        
        self.statusBar.statusBarStyle = self.presentationData.theme.rootController.statusBarStyle.style
        
        self.title = "" //"Discover"//self.presentationData.strings.Contacts_Title
        self.tabBarItem.title = "Discover"
        /*if !self.presentationData.reduceMotion {
            self.tabBarItem.animationName = "discover"
            self.tabBarItem.animationOffset = CGPoint(x: 0.0, y: UIScreenPixel)
        }*/
        self.tabBarItem.image =   UIImage(named:"tabbar_discover_unselect")
        self.tabBarItem.selectedImage =  UIImage(named:"tabbar_discover_selected")

        
        self.navigationItem.backBarButtonItem = UIBarButtonItem(title: self.presentationData.strings.Common_Back, style: .plain, target: nil, action: nil)
        
        //self.navigationItem.leftBarButtonItem = UIBarButtonItem(customDisplayNode: self.sortButton)
        //self.navigationItem.rightBarButtonItem = UIBarButtonItem(image: PresentationResourcesRootController.navigationAddIcon(self.presentationData.theme), style: .plain, target: self, action: #selector(self.addPressed))
        self.navigationItem.rightBarButtonItem?.accessibilityLabel = self.presentationData.strings.Contacts_VoiceOver_AddContact
        
//        self.scrollToTop = { [weak self] in
//            if let strongSelf = self {
//                if let searchContentNode = strongSelf.searchContentNode {
//                    searchContentNode.updateExpansionProgress(1.0, animated: true)
//                }
//                strongSelf.contactsNode.scrollToTop()
//            }
//        }
//
        self.presentationDataDisposable = (context.sharedContext.presentationData
                                           |> deliverOnMainQueue).start(next: { [weak self] presentationData in
            if let strongSelf = self {
                let previousTheme = strongSelf.presentationData.theme
                let previousStrings = strongSelf.presentationData.strings
                
                strongSelf.presentationData = presentationData
                
                if previousTheme !== presentationData.theme || previousStrings !== presentationData.strings {
                    strongSelf.updateThemeAndStrings()
                }
            }
        })
        
        if #available(iOSApplicationExtension 10.0, iOS 10.0, *) {
            self.authorizationDisposable = (combineLatest(DeviceAccess.authorizationStatus(subject: .contacts), combineLatest(context.sharedContext.accountManager.noticeEntry(key: ApplicationSpecificNotice.permissionWarningKey(permission: .contacts)!), context.account.postbox.preferencesView(keys: [PreferencesKeys.contactsSettings]), context.sharedContext.accountManager.sharedData(keys: [ApplicationSpecificSharedDataKeys.contactSynchronizationSettings]))
                                                          |> map { noticeView, preferences, sharedData -> (Bool, ContactsSortOrder) in
                let settings: ContactsSettings = preferences.values[PreferencesKeys.contactsSettings]?.get(ContactsSettings.self) ?? ContactsSettings.defaultSettings
                let synchronizeDeviceContacts: Bool = settings.synchronizeContacts
                
                let contactsSettings = sharedData.entries[ApplicationSpecificSharedDataKeys.contactSynchronizationSettings]?.get(ContactSynchronizationSettings.self)
                
                let sortOrder: ContactsSortOrder = contactsSettings?.sortOrder ?? .presence
                if !synchronizeDeviceContacts {
                    return (true, sortOrder)
                }
                let timestamp = noticeView.value.flatMap({ ApplicationSpecificNotice.getTimestampValue($0) })
                if let timestamp = timestamp, timestamp > 0 {
                    return (true, sortOrder)
                } else {
                    return (false, sortOrder)
                }
            })
                                            |> deliverOnMainQueue).start(next: { [weak self] status, suppressedAndSortOrder in
                if let strongSelf = self {
                    let (suppressed, sortOrder) = suppressedAndSortOrder
                    strongSelf.tabBarItem.badgeValue = status != .allowed && !suppressed ? nil : nil
                    strongSelf.sortOrderPromise.set(.single(sortOrder))
                }
            })
        } else {
            self.sortOrderPromise.set(context.sharedContext.accountManager.sharedData(keys: [ApplicationSpecificSharedDataKeys.contactSynchronizationSettings])
                                      |> map { sharedData -> ContactsSortOrder in
                let settings = sharedData.entries[ApplicationSpecificSharedDataKeys.contactSynchronizationSettings]?.get(ContactSynchronizationSettings.self)
                return settings?.sortOrder ?? .presence
            })
        }
        
    }
    
//    public func playUniversalLinkedVideos(videoId: String, type: Int) {
//        self.contactsNode.doGetYoutubeVideoById(videoId: videoId, type: type)
//    }
    
    required public init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
        self.presentationDataDisposable?.dispose()
        self.authorizationDisposable?.dispose()
    }
    
    private func updateThemeAndStrings() {
        //self.sortButton.update(theme: self.presentationData.theme, strings: self.presentationData.strings)
        self.statusBar.statusBarStyle = self.presentationData.theme.rootController.statusBarStyle.style
        self.navigationBar?.updatePresentationData(NavigationBarPresentationData(presentationData: self.presentationData))
        self.searchContentNode?.updateThemeAndPlaceholder(theme: self.presentationData.theme, placeholder: self.presentationData.strings.Common_Search)
        self.title = "" //"Discover" //self.presentationData.strings.Contacts_Title
        self.tabBarItem.title = "Discover"//self.presentationData.strings.Contacts_Title
        
        /*if !self.presentationData.reduceMotion {
            self.tabBarItem.animationName = "discover"
            self.tabBarItem.animationOffset = CGPoint(x: 0.0, y: UIScreenPixel)
        } else {
            self.tabBarItem.animationName = nil
        }*/
        self.navigationItem.backBarButtonItem = UIBarButtonItem(title: self.presentationData.strings.Common_Back, style: .plain, target: nil, action: nil)
        if self.navigationItem.rightBarButtonItem != nil {
            //self.navigationItem.rightBarButtonItem = UIBarButtonItem(image: PresentationResourcesRootController.navigationAddIcon(self.presentationData.theme), style: .plain, target: self, action: #selector(self.addPressed))
            self.navigationItem.rightBarButtonItem?.accessibilityLabel = self.presentationData.strings.Contacts_VoiceOver_AddContact
        }
//        self.contactsNode.presentationData = self.presentationData
//        self.contactsNode.updateThemeAndStrings()
    }
  
    
}

private final class ContactsTabBarContextExtractedContentSource: ContextExtractedContentSource {
    let keepInPlace: Bool = true
    let ignoreContentTouches: Bool = true
    let blurBackground: Bool = true
    let centerActionsHorizontally: Bool = true
    
    private let controller: ViewController
    private let sourceNode: ContextExtractedContentContainingNode
    
    init(controller: ViewController, sourceNode: ContextExtractedContentContainingNode) {
        self.controller = controller
        self.sourceNode = sourceNode
    }
    
    func takeView() -> ContextControllerTakeViewInfo? {
        return ContextControllerTakeViewInfo(containingItem: .node(self.sourceNode), contentAreaInScreenSpace: UIScreen.main.bounds)
    }
    
    func putBack() -> ContextControllerPutBackViewInfo? {
        return ContextControllerPutBackViewInfo(contentAreaInScreenSpace: UIScreen.main.bounds)
    }
}

//


