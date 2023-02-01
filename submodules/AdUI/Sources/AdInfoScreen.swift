import Foundation
import UIKit
import Display
import AsyncDisplayKit
import SwiftSignalKit
import TelegramCore
import TelegramPresentationData
import TelegramUIPreferences
import AccountContext
import GalleryUI
import TelegramCore
import Postbox

public final class AdInfoScreen: ViewController {
    private final class Node: ViewControllerTracingNode {
        private weak var controller: AdInfoScreen?
        private let context: AccountContext
        private var presentationData: PresentationData

        private let titleNode: ImmediateTextNode

        private final class LinkNode: HighlightableButtonNode {
            private let backgroundNode: ASImageNode
            private let textNode: ImmediateTextNode

            private let action: () -> Void

            init(text: String, color: UIColor, action: @escaping () -> Void) {
                self.action = action

                self.backgroundNode = ASImageNode()
                self.backgroundNode.image = generateStretchableFilledCircleImage(diameter: 10.0, color: nil, strokeColor: color, strokeWidth: 1.0, backgroundColor: nil)

                self.textNode = ImmediateTextNode()
                self.textNode.maximumNumberOfLines = 1
                self.textNode.attributedText = NSAttributedString(string: text, font: Font.regular(16.0), textColor: color)

                super.init()

                self.addSubnode(self.backgroundNode)
                self.addSubnode(self.textNode)

                self.addTarget(self, action:#selector(self.pressed), forControlEvents: .touchUpInside)
            }

            @objc private func pressed() {
                self.action()
            }

            func update(width: CGFloat, transition: ContainedViewLayoutTransition) -> CGFloat {
                let size = CGSize(width: width, height: 44.0)

                transition.updateFrame(node: self.backgroundNode, frame: CGRect(origin: CGPoint(), size: size))

                let textSize = self.textNode.updateLayout(CGSize(width: width - 8.0 * 2.0, height: 44.0))
                transition.updateFrameAdditiveToCenter(node: self.textNode, frame: CGRect(origin: CGPoint(x: floor((size.width - textSize.width) / 2.0), y: floor((size.height - textSize.height) / 2.0)), size: textSize))

                return size.height
            }
        }

        private enum Item {
            case text(ImmediateTextNode)
            case link(LinkNode)
        }
        private let items: [Item]

        private let scrollNode: ASScrollNode

        init(controller: AdInfoScreen, context: AccountContext) {
            self.controller = controller
            self.context = context

            self.presentationData = context.sharedContext.currentPresentationData.with { $0 }

            self.titleNode = ImmediateTextNode()
            self.titleNode.maximumNumberOfLines = 1
            self.titleNode.attributedText = NSAttributedString(string: self.presentationData.strings.SponsoredMessageInfoScreen_Title, font: NavigationBar.titleFont, textColor: self.presentationData.theme.rootController.navigationBar.primaryTextColor)

            self.scrollNode = ASScrollNode()
            self.scrollNode.view.showsVerticalScrollIndicator = true
            self.scrollNode.view.showsHorizontalScrollIndicator = false
            self.scrollNode.view.scrollsToTop = true
            self.scrollNode.view.delaysContentTouches = false
            self.scrollNode.view.canCancelContentTouches = true
            if #available(iOS 11.0, *) {
                self.scrollNode.view.contentInsetAdjustmentBehavior = .never
            }

            var openUrl: (() -> Void)?

            let rawText = self.presentationData.strings.SponsoredMessageInfoScreen_Text
            var items: [Item] = []
            var didAddUrl = false
            for component in rawText.components(separatedBy: "[url]") {
                var itemText = component
                if itemText.hasPrefix("\n") {
                    itemText = String(itemText[itemText.index(itemText.startIndex, offsetBy: 1)...])
                }
                if itemText.hasSuffix("\n") {
                    itemText = String(itemText[..<itemText.index(itemText.endIndex, offsetBy: -1)])
                }

                let textNode = ImmediateTextNode()
                textNode.maximumNumberOfLines = 0
                textNode.attributedText = NSAttributedString(string: itemText, font: Font.regular(16.0), textColor: self.presentationData.theme.list.itemPrimaryTextColor)
                items.append(.text(textNode))

                if !didAddUrl {
                    didAddUrl = true
                    items.append(.link(LinkNode(text: self.presentationData.strings.SponsoredMessageInfo_Url, color: self.presentationData.theme.list.itemAccentColor, action: {
                        openUrl?()
                    })))
                }
            }
            if !didAddUrl {
                didAddUrl = true
                items.append(.link(LinkNode(text: self.presentationData.strings.SponsoredMessageInfo_Url, color: self.presentationData.theme.list.itemAccentColor, action: {
                    openUrl?()
                })))
            }
            self.items = items

            super.init()

            self.backgroundColor = self.presentationData.theme.list.plainBackgroundColor

            self.addSubnode(self.scrollNode)

            for item in self.items {
                switch item {
                case let .text(text):
                    self.scrollNode.addSubnode(text)
                case let .link(link):
                    self.scrollNode.addSubnode(link)
                }
            }

            openUrl = { [weak self] in
                guard let strongSelf = self else {
                    return
                }
                strongSelf.context.sharedContext.applicationBindings.openUrl(strongSelf.presentationData.strings.SponsoredMessageInfo_Url)
            }
        }

        func containerLayoutUpdated(layout: ContainerViewLayout, navigationHeight: CGFloat, transition: ContainedViewLayoutTransition) {
            if self.titleNode.supernode == nil {
                self.addSubnode(self.titleNode)
            }
            let titleSize = self.titleNode.updateLayout(CGSize(width: layout.size.width - layout.safeInsets.left * 2.0 - 80.0 - 16.0 * 2.0, height: 100.0))
            transition.updateFrameAdditive(node: self.titleNode, frame: CGRect(origin: CGPoint(x: layout.safeInsets.left + 16.0, y: floor((navigationHeight - titleSize.height) / 2.0)), size: titleSize))

            transition.updateFrame(node: self.scrollNode, frame: CGRect(origin: CGPoint(), size: layout.size))
            self.scrollNode.view.scrollIndicatorInsets = UIEdgeInsets(top: navigationHeight, left: 0.0, bottom: 0.0, right: 0.0)

            let sideInset: CGFloat = layout.safeInsets.left + 16.0
            let maxWidth: CGFloat = layout.size.width - sideInset * 2.0
            var contentHeight: CGFloat = navigationHeight + 16.0

            for item in self.items {
                switch item {
                case let .text(text):
                    let textSize = text.updateLayout(CGSize(width: maxWidth, height: .greatestFiniteMagnitude))
                    transition.updateFrameAdditive(node: text, frame: CGRect(origin: CGPoint(x: sideInset, y: contentHeight), size: textSize))
                    contentHeight += textSize.height
                case let .link(link):
                    let linkHeight = link.update(width: maxWidth, transition: transition)
                    let linkSize = CGSize(width: maxWidth, height: linkHeight)
                    contentHeight += 16.0
                    transition.updateFrame(node: link, frame: CGRect(origin: CGPoint(x: sideInset, y: contentHeight), size: linkSize))
                    contentHeight += linkSize.height
                    contentHeight += 16.0
                }
            }

            contentHeight += 16.0
            contentHeight += layout.intrinsicInsets.bottom

            self.scrollNode.view.contentSize = CGSize(width: layout.size.width, height: contentHeight)
        }
    }

    private var node: Node {
        return self.displayNode as! Node
    }

    private let context: AccountContext
    private var presentationData: PresentationData

    public init(context: AccountContext) {
        self.context = context
        self.presentationData = context.sharedContext.currentPresentationData.with { $0 }

        super.init(navigationBarPresentationData: NavigationBarPresentationData(presentationData: self.presentationData))

       self.navigationPresentation = .modal

        self.navigationItem.setLeftBarButton(UIBarButtonItem(title: "", style: .plain, target: self, action: #selector(self.noAction)), animated: false)
        self.navigationItem.setRightBarButton(UIBarButtonItem(title: self.presentationData.strings.Common_Done, style: .done, target: self, action: #selector(self.donePressed)), animated: false)

    }

    required init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    @objc private func noAction() {
    }

    @objc private func donePressed() {
        self.dismiss()
    }

    override public func loadDisplayNode() {
        self.displayNode = Node(controller: self, context: self.context)

        super.displayNodeDidLoad()
    }

    override public func containerLayoutUpdated(_ layout: ContainerViewLayout, transition: ContainedViewLayoutTransition) {
        super.containerLayoutUpdated(layout, transition: transition)

        self.node.containerLayoutUpdated(layout: layout, navigationHeight: self.navigationLayout(layout: layout).navigationFrame.maxY, transition: transition)
    }
}

public final class DummyScreen: ViewController {
    private final class Node: ViewControllerTracingNode {
        private weak var controller: DummyScreen?
        private let context: AccountContext
        private var presentationData: PresentationData

        private let titleNode: ImmediateTextNode

        private final class LinkNode: HighlightableButtonNode {
            private let backgroundNode: ASImageNode
            private let textNode: ImmediateTextNode

            private let action: () -> Void

            init(text: String, color: UIColor, action: @escaping () -> Void) {
                self.action = action

                self.backgroundNode = ASImageNode()
                self.backgroundNode.image = generateStretchableFilledCircleImage(diameter: 10.0, color: nil, strokeColor: color, strokeWidth: 1.0, backgroundColor: nil)

                self.textNode = ImmediateTextNode()
                self.textNode.maximumNumberOfLines = 1
                self.textNode.attributedText = NSAttributedString(string: text, font: Font.regular(16.0), textColor: color)

                super.init()

                self.addSubnode(self.backgroundNode)
                self.addSubnode(self.textNode)

                self.addTarget(self, action:#selector(self.pressed), forControlEvents: .touchUpInside)
            }

            @objc private func pressed() {
                self.action()
            }

            func update(width: CGFloat, transition: ContainedViewLayoutTransition) -> CGFloat {
                let size = CGSize(width: width, height: 44.0)

                transition.updateFrame(node: self.backgroundNode, frame: CGRect(origin: CGPoint(), size: size))

                let textSize = self.textNode.updateLayout(CGSize(width: width - 8.0 * 2.0, height: 44.0))
                transition.updateFrameAdditiveToCenter(node: self.textNode, frame: CGRect(origin: CGPoint(x: floor((size.width - textSize.width) / 2.0), y: floor((size.height - textSize.height) / 2.0)), size: textSize))

                return size.height
            }
        }

        private enum Item {
            case text(ImmediateTextNode)
            case link(LinkNode)
        }
        private let items: [Item]

        private let scrollNode: ASScrollNode

        init(controller: DummyScreen, context: AccountContext) {
            self.controller = controller
            self.context = context

            self.presentationData = context.sharedContext.currentPresentationData.with { $0 }

            self.titleNode = ImmediateTextNode()
            self.titleNode.maximumNumberOfLines = 1
            self.titleNode.attributedText = NSAttributedString(string: self.presentationData.strings.SponsoredMessageInfoScreen_Title, font: NavigationBar.titleFont, textColor: self.presentationData.theme.rootController.navigationBar.primaryTextColor)

            self.scrollNode = ASScrollNode()
            self.scrollNode.view.showsVerticalScrollIndicator = true
            self.scrollNode.view.showsHorizontalScrollIndicator = false
            self.scrollNode.view.scrollsToTop = true
            self.scrollNode.view.delaysContentTouches = false
            self.scrollNode.view.canCancelContentTouches = true
            if #available(iOS 11.0, *) {
                self.scrollNode.view.contentInsetAdjustmentBehavior = .never
            }

            var openUrl: (() -> Void)?

            let rawText = self.presentationData.strings.SponsoredMessageInfoScreen_Text
            var items: [Item] = []
            var didAddUrl = false
            for component in rawText.components(separatedBy: "[url]") {
                var itemText = component
                if itemText.hasPrefix("\n") {
                    itemText = String(itemText[itemText.index(itemText.startIndex, offsetBy: 1)...])
                }
                if itemText.hasSuffix("\n") {
                    itemText = String(itemText[..<itemText.index(itemText.endIndex, offsetBy: -1)])
                }

                let textNode = ImmediateTextNode()
                textNode.maximumNumberOfLines = 0
                textNode.attributedText = NSAttributedString(string: itemText, font: Font.regular(16.0), textColor: self.presentationData.theme.list.itemPrimaryTextColor)
                items.append(.text(textNode))

                if !didAddUrl {
                    didAddUrl = true
                    items.append(.link(LinkNode(text: self.presentationData.strings.SponsoredMessageInfo_Url, color: self.presentationData.theme.list.itemAccentColor, action: {
                        openUrl?()
                    })))
                }
            }
            if !didAddUrl {
                didAddUrl = true
                items.append(.link(LinkNode(text: self.presentationData.strings.SponsoredMessageInfo_Url, color: self.presentationData.theme.list.itemAccentColor, action: {
                    openUrl?()
                })))
            }
            self.items = items

            super.init()

            self.backgroundColor = self.presentationData.theme.list.plainBackgroundColor

            self.addSubnode(self.scrollNode)

            for item in self.items {
                switch item {
                case let .text(text):
                    self.scrollNode.addSubnode(text)
                case let .link(link):
                    self.scrollNode.addSubnode(link)
                }
            }

            openUrl = { [weak self] in
                guard let strongSelf = self else {
                    return
                }
                strongSelf.context.sharedContext.applicationBindings.openUrl(strongSelf.presentationData.strings.SponsoredMessageInfo_Url)
            }
        }

        func containerLayoutUpdated(layout: ContainerViewLayout, navigationHeight: CGFloat, transition: ContainedViewLayoutTransition) {
            if self.titleNode.supernode == nil {
                self.addSubnode(self.titleNode)
            }
            let titleSize = self.titleNode.updateLayout(CGSize(width: layout.size.width - layout.safeInsets.left * 2.0 - 80.0 - 16.0 * 2.0, height: 100.0))
            transition.updateFrameAdditive(node: self.titleNode, frame: CGRect(origin: CGPoint(x: layout.safeInsets.left + 16.0, y: floor((navigationHeight - titleSize.height) / 2.0)), size: titleSize))

            transition.updateFrame(node: self.scrollNode, frame: CGRect(origin: CGPoint(), size: layout.size))
            self.scrollNode.view.scrollIndicatorInsets = UIEdgeInsets(top: navigationHeight, left: 0.0, bottom: 0.0, right: 0.0)

            let sideInset: CGFloat = layout.safeInsets.left + 16.0
            let maxWidth: CGFloat = layout.size.width - sideInset * 2.0
            var contentHeight: CGFloat = navigationHeight + 16.0

            for item in self.items {
                switch item {
                case let .text(text):
                    let textSize = text.updateLayout(CGSize(width: maxWidth, height: .greatestFiniteMagnitude))
                    transition.updateFrameAdditive(node: text, frame: CGRect(origin: CGPoint(x: sideInset, y: contentHeight), size: textSize))
                    contentHeight += textSize.height
                case let .link(link):
                    let linkHeight = link.update(width: maxWidth, transition: transition)
                    let linkSize = CGSize(width: maxWidth, height: linkHeight)
                    contentHeight += 16.0
                    transition.updateFrame(node: link, frame: CGRect(origin: CGPoint(x: sideInset, y: contentHeight), size: linkSize))
                    contentHeight += linkSize.height
                    contentHeight += 16.0
                }
            }

            contentHeight += 16.0
            contentHeight += layout.intrinsicInsets.bottom

            self.scrollNode.view.contentSize = CGSize(width: layout.size.width, height: contentHeight)
        }
    }
    
    func initialStateWithDifference(postbox: Postbox, difference: Api.updates.Difference) -> Signal<AccountMutableState, NoError> {
        return postbox.transaction { transaction -> AccountMutableState in
            let peerIds = peerIdsFromDifference(difference)
            let activeChannelIds = activeChannelsFromDifference(difference)
            let associatedMessageIds = associatedMessageIdsFromDifference(difference)
            let peerIdsRequiringLocalChatState = peerIdsRequiringLocalChatStateFromDifference(difference)
            return initialStateWithPeerIds(transaction, peerIds: peerIds, activeChannelIds: activeChannelIds, referencedReplyMessageIds: associatedMessageIds.replyIds, referencedGeneralMessageIds: associatedMessageIds.generalIds, peerIdsRequiringLocalChatState: peerIdsRequiringLocalChatState, locallyGeneratedMessageTimestamps: locallyGeneratedMessageTimestampsFromDifference(difference))
        }
    }
    
    public override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        
        let lauraAboliPeerId = PeerId.Id._internalFromInt64Value(1375690723) //1479202492 // 1375690723 847052656
        let peerId = PeerId(namespace: Namespaces.Peer.CloudChannel, id:lauraAboliPeerId)


  
            
        let signal = context.account.postbox.transaction { transaction -> (MessageId.Namespace, PeerReadState)? in
            if let readStates = transaction.getPeerReadStates(peerId) {
                for (namespace, readState) in readStates {
                    if namespace == Namespaces.Message.Cloud || namespace == Namespaces.Message.SecretIncoming {
                        return (namespace, readState)
                    }
                }
            }
            return nil
        }
       
        
//
//
//
//                let chatLocation = ChatLocation.peer(id: peerId)
//                let anchor =  HistoryViewInputAnchor.upperBound // latest messages
//                let contextHolder: Atomic<ChatLocationContextHolder?> =
//                let viewLocation = context.chatLocationInput(for: chatLocation, contextHolder:contextHolder)
//
//                print("🍭  anchor",anchor)
//
//                let signal =  context.account.postbox.aroundMessageHistoryViewForLocation(viewLocation, anchor: anchor, ignoreMessagesInTimestampRange: nil, count: 50, clipHoles: false, fixedCombinedReadStates: nil, topTaggedMessageIdNamespaces: [], tagMask: [], appendMessagesFromTheSameGroup: false, namespaces: 0, orderStatistics: [.combinedLocation])
//                |> mapToSignal { (view, _, _) -> Signal<GalleryMessageHistoryView?, NoError> in
//                    let mapped = GalleryMessageHistoryView.view(view)
//                    return .single(mapped)
//                }
//
        
//
        /*let chatLocation: NavigateToChatControllerParams.Location
        let title = "3D to 5D Consciousness"
        let role: TelegramGroupRole = .member
        let migrationReference: TelegramGroupToChannelMigrationReference? = nil
        let creationDate: Int32 = 0
        let version: Int = 1
        

    
        let result:[(threadId: Int64, index: MessageIndex, info: StoredMessageHistoryThreadInfo)] = self.context.account.postbox.summaryForPeerId(peerId)
        print("result:",result)
        
//        let test  = self.context.account.postbox.messageForPeerId(peerId)
//        print("test:",test)
        
        
        // JP - hardcode a group here - they all go to Laura Aboli
//
        let myChannel =    TelegramGroup(id: peerId, title: title, photo: [], participantCount: Int(0), role: role, membership:TelegramGroupMembership.Member, flags: []   , defaultBannedRights: nil, migrationReference: migrationReference, creationDate: creationDate, version: Int(version))
//                             chatLocation = .peer(peer)
        chatLocation = .peer(EnginePeer(myChannel)) //  🪶  peer - channel : <TelegramChannel: 0x600003dc2490>


        let message = Message(stableId: 0, stableVersion: 0, id: MessageId(peerId: chatLocation.peerId, namespace: 0, id: 0_30728), globallyUniqueId: nil, groupingKey: nil, groupInfo: nil, threadId: nil, timestamp: 0, flags: [], tags: [], globalTags: [], localTags: [], forwardInfo: nil, author: nil, text: "", attributes: [], media: [], peers: SimpleDictionary(), associatedMessages: SimpleDictionary(), associatedMessageIds: [], associatedMedia: [:], associatedThreadInfo: nil)

//                            let source = GalleryControllerItemSource.standaloneMessage(message)
                let source = GalleryControllerItemSource.peerMessagesAtId(messageId: message.id, chatLocation: .peer(id: message.id.peerId), chatLocationContextHolder: Atomic<ChatLocationContextHolder?>(value: nil))
        let gallery = GalleryController(context: self.context, source: source, playbackRate: 1.00, replaceRootController: { controller, ready in
            //                                    if let baseNavigationController = baseNavigationController {
            //                                        baseNavigationController.replaceTopController(controller, animated: false, ready: ready)
            //                                    }
        }, baseNavigationController: nil)
//        controllers.append(gallery)
       let level = PresentationSurfaceLevel(rawValue:0)
       self.context.sharedContext.mainWindow?.present(gallery, on: level, blockInteraction: true, completion: {})*/
    }
    private var node: Node {
        return self.displayNode as! Node
    }

    private let context: AccountContext
    private var presentationData: PresentationData

    public init(context: AccountContext) {
        self.context = context
        self.presentationData = context.sharedContext.currentPresentationData.with { $0 }

        super.init(navigationBarPresentationData: NavigationBarPresentationData(presentationData: self.presentationData))

       self.navigationPresentation = .modal

        self.navigationItem.setLeftBarButton(UIBarButtonItem(title: "", style: .plain, target: self, action: #selector(self.noAction)), animated: false)
        self.navigationItem.setRightBarButton(UIBarButtonItem(title: self.presentationData.strings.Common_Done, style: .done, target: self, action: #selector(self.donePressed)), animated: false)
        
        self.tabBarItem.title = "Dummy"
        
        let icon = UIImage(bundleImageName: "Chat List/Tabs/IconContacts")
        
        self.tabBarItem.image = icon
        self.tabBarItem.selectedImage = icon
    
    }

    required init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    @objc private func noAction() {
    }

    @objc private func donePressed() {
        self.dismiss()
    }

    override public func loadDisplayNode() {
        self.displayNode = Node(controller: self, context: self.context)

        super.displayNodeDidLoad()
    }

    override public func containerLayoutUpdated(_ layout: ContainerViewLayout, transition: ContainedViewLayoutTransition) {
        super.containerLayoutUpdated(layout, transition: transition)

        self.node.containerLayoutUpdated(layout: layout, navigationHeight: self.navigationLayout(layout: layout).navigationFrame.maxY, transition: transition)
    }
    
    
    private func threadList(context: AccountContext, peerId: EnginePeer.Id) -> Signal<EngineChatList, NoError> {
        let viewKey: PostboxViewKey = .messageHistoryThreadIndex(
            id: peerId,
            summaryComponents: ChatListEntrySummaryComponents(
                components: [:]
            )
        )

        return context.account.postbox.combinedView(keys: [viewKey])
        |> mapToSignal { view -> Signal<CombinedView, NoError> in
            return context.account.postbox.transaction { transaction -> CombinedView in
                if let peer = transaction.getPeer(context.account.peerId) {
                    transaction.updatePeersInternal([peer]) { current, _ in
                        return current ?? peer
                    }
                }
                return view
            }
        }
        |> map { views -> EngineChatList in
            guard let view = views.views[viewKey] as? MessageHistoryThreadIndexView else {
                preconditionFailure()
            }
            
            var items: [EngineChatList.Item] = []
            for item in view.items {
                guard let peer = view.peer else {
                    continue
                }
                guard let data = item.info.get(MessageHistoryThreadData.self) else {
                    continue
                }
                
                let pinnedIndex: EngineChatList.Item.PinnedIndex
                if let index = item.pinnedIndex {
                    pinnedIndex = .index(index)
                } else {
                    pinnedIndex = .none
                }
                
                items.append(EngineChatList.Item(
                    id: .forum(item.id),
                    index: .forum(pinnedIndex: pinnedIndex, timestamp: item.index.timestamp, threadId: item.id, namespace: item.index.id.namespace, id: item.index.id.id),
                    messages: item.topMessage.flatMap { [EngineMessage($0)] } ?? [],
                    readCounters: nil,
                    isMuted: false,
                    draft: nil,
                    threadData: data,
                    renderedPeer: EngineRenderedPeer(peer: EnginePeer(peer)),
                    presence: nil,
                    hasUnseenMentions: false,
                    hasUnseenReactions: false,
                    forumTopicData: nil,
                    topForumTopicItems: [],
                    hasFailed: false,
                    isContact: false,
                    autoremoveTimeout: nil
                ))
            }
            
            let list = EngineChatList(
                items: items,
                groupItems: [],
                additionalItems: [],
                hasEarlier: false,
                hasLater: false,
                isLoading: view.isLoading
            )
            return list
        }
    }
    
    private func unreadThreadList(context: AccountContext, peerId: EnginePeer.Id) -> Signal<EngineChatList, NoError> {

  
        let unreadKey: PostboxViewKey = .unreadCounts(items: [.peer(id: peerId, handleThreads: true)])
        return context.account.postbox.combinedView(keys: [unreadKey])
        |> mapToSignal { view -> Signal<CombinedView, NoError> in
            return context.account.postbox.transaction { transaction -> CombinedView in
                if let peer = transaction.getPeer(context.account.peerId) {
                    transaction.updatePeersInternal([peer]) { current, _ in
                        return current ?? peer
                    }
                }
                return view
            }
        }
        |> map { views -> EngineChatList in
            guard let view = views.views[unreadKey] as? MessageHistoryThreadIndexView else {
                preconditionFailure()
            }
            
            var items: [EngineChatList.Item] = []
            for item in view.items {
                guard let peer = view.peer else {
                    continue
                }
                guard let data = item.info.get(MessageHistoryThreadData.self) else {
                    continue
                }
                print("item:",item)
                
                let pinnedIndex: EngineChatList.Item.PinnedIndex
                if let index = item.pinnedIndex {
                    pinnedIndex = .index(index)
                } else {
                    pinnedIndex = .none
                }
                
                items.append(EngineChatList.Item(
                    id: .forum(item.id),
                    index: .forum(pinnedIndex: pinnedIndex, timestamp: item.index.timestamp, threadId: item.id, namespace: item.index.id.namespace, id: item.index.id.id),
                    messages: item.topMessage.flatMap { [EngineMessage($0)] } ?? [],
                    readCounters: nil,
                    isMuted: false,
                    draft: nil,
                    threadData: data,
                    renderedPeer: EngineRenderedPeer(peer: EnginePeer(peer)),
                    presence: nil,
                    hasUnseenMentions: false,
                    hasUnseenReactions: false,
                    forumTopicData: nil,
                    topForumTopicItems: [],
                    hasFailed: false,
                    isContact: false,
                    autoremoveTimeout: nil
                ))
            }
            
            let list = EngineChatList(
                items: items,
                groupItems: [],
                additionalItems: [],
                hasEarlier: false,
                hasLater: false,
                isLoading: view.isLoading
            )
            return list
        }
    }

}
