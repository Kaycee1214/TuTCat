import SwiftUI
import AppKit
import QuartzCore

// MARK: - 像素风气泡视图
class BubbleView: NSView {
    override func draw(_ dirtyRect: NSRect) {
        let lineWidth: CGFloat = 3
        let inset: CGFloat = lineWidth / 2

        let bubbleRect = bounds.insetBy(dx: inset, dy: inset)
        let cornerRadius = bubbleRect.height / 2

        let bubblePath = NSBezierPath(roundedRect: bubbleRect, xRadius: cornerRadius, yRadius: cornerRadius)
        NSColor.white.setFill()
        bubblePath.fill()
        NSColor(red: 228/255.0, green: 115/255.0, blue: 29/255.0, alpha: 1).setStroke()
        bubblePath.lineWidth = lineWidth
        bubblePath.stroke()
    }
}

// MARK: - 气泡窗口
class BubbleWindow: NSWindow {
    private let textField: NSTextField
    private let containerView: NSView
    private var hideTimer: Timer?

    var onTap: (() -> Void)?
    var onHide: (() -> Void)?

    init() {
        let initialRect = NSRect(x: 0, y: 0, width: 100, height: 36)
        textField = NSTextField(labelWithString: "")
        containerView = NSView(frame: initialRect)

        super.init(
            contentRect: initialRect,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )

        self.isOpaque = false
        self.backgroundColor = .clear
        self.hasShadow = false
        self.level = .statusBar + 1
        self.ignoresMouseEvents = false

        setupUI()
    }

    private func setupUI() {
        let bubbleView = BubbleView(frame: containerView.bounds)
        bubbleView.autoresizingMask = [.width, .height]
        containerView.addSubview(bubbleView)

        textField.alignment = .center
        let font = NSFont(name: "Courier", size: 12) ?? NSFont.monospacedSystemFont(ofSize: 12, weight: .regular)
        textField.font = font
        textField.textColor = .black
        textField.backgroundColor = .clear
        textField.isBezeled = false
        textField.isEditable = false
        textField.isSelectable = false
        textField.autoresizingMask = [.width]
        let lineW: CGFloat = 3
        let inset: CGFloat = lineW / 2
        let bubbleBodyHeight = containerView.bounds.height - lineW
        let textHeight = ("测" as NSString).size(withAttributes: [.font: font]).height
        let textY = inset + (bubbleBodyHeight - textHeight) / 2
        textField.frame = NSRect(
            x: inset + 6,
            y: textY,
            width: containerView.bounds.width - lineW - 12,
            height: textHeight
        )
        containerView.addSubview(textField)

        self.contentView = containerView

        let clickGesture = NSClickGestureRecognizer(target: self, action: #selector(handleClick))
        containerView.addGestureRecognizer(clickGesture)
    }

    @objc private func handleClick() {
        onTap?()
        resetHideTimer()
    }

    func show(message: String, above window: NSWindow) {
        textField.stringValue = message

        let font = textField.font ?? NSFont.monospacedSystemFont(ofSize: 12, weight: .regular)
        let attrString = NSAttributedString(string: message, attributes: [.font: font])
        let textWidth = attrString.size().width
        let bubbleWidth = max(80, textWidth + 32)
        let bubbleHeight: CGFloat = 36

        let petFrame = window.frame
        let x = petFrame.midX - bubbleWidth / 2
        let y = petFrame.maxY + 8

        self.setFrame(NSRect(x: x, y: y, width: bubbleWidth, height: bubbleHeight), display: false)

        let lineW: CGFloat = 3
        let inset: CGFloat = lineW / 2
        let bubbleBodyHeight = bubbleHeight - lineW
        let textHeight = ("测" as NSString).size(withAttributes: [.font: font]).height
        let textY = inset + (bubbleBodyHeight - textHeight) / 2
        textField.frame = NSRect(
            x: inset + 6,
            y: textY,
            width: bubbleWidth - lineW - 12,
            height: textHeight
        )

        self.alphaValue = 1
        self.orderFrontRegardless()

        resetHideTimer()
    }

    func updatePosition(relativeTo window: NSWindow) {
        guard self.alphaValue > 0 else { return }
        let petFrame = window.frame
        let bubbleWidth = self.frame.width
        let bubbleHeight = self.frame.height
        let x = petFrame.midX - bubbleWidth / 2
        let y = petFrame.maxY + 8
        self.setFrameOrigin(NSPoint(x: x, y: y))
    }

    func hide() {
        hideTimer?.invalidate()
        hideTimer = nil
        self.alphaValue = 0
        self.orderOut(nil)
        onHide?()
    }

    private func resetHideTimer() {
        hideTimer?.invalidate()
        hideTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: false) { [weak self] _ in
            self?.hide()
        }
    }
}

// MARK: - 聊天触发类型
enum ChatTriggerType {
    case morning
    case lunch
    case dinner
    case drink
    case rest
    case lieDown
    case idle
    case randomChat
}

// MARK: - 宠物视图
class PetView: NSView {
    private var imageLayer: CALayer!

    private var hoverAssets: [String] = []
    private var playAssets: [String] = []
    private var walkAssets: [String] = []
    private var dragAssets: [String] = []
    private var eatAssets: [String] = []

    private var isHovering = false
    private var isPlayingAnimation = false
    private var walkDirection: Int = -1

    private var walkTimer: Timer?
    private var directionTimer: Timer?
    private var animationTimer: Timer?
    private var idleTimer: Timer?

    private var dragStartPoint: NSPoint = .zero
    private var isDragging: Bool = false
    private var lastMouseDownLocation: NSPoint = .zero

    private var windowSize: CGFloat = 140
    private var walkSpeed: Double = 2.0
    private var lastEdgeBounceDirection: Int = 0
    private var walkHealthCheckCounter = 0

    // GIF 动画状态
    private var gifTimer: Timer?
    private var gifFrames: [CGImage] = []
    private var gifDelays: [Double] = []
    private var gifCurrentFrame: Int = 0
    private var gifAccumulatedTime: Double = 0
    private var gifLoops: Bool = true
    private var gifCompletion: (() -> Void)?

    // MARK: - 聊天相关
    private var bubbleWindow: BubbleWindow?
    private var activityMonitor: Any?

    private let morningMessages = [
        "主人，秃秃又来陪你啦！新的一天又开始了❤️",
        "主人你来啦~秃秃好想你😘",
        "主人你看起来有点困，是不是没睡好呀~",
        "早上好！今天也要元气满满哦~",
        "早安喵~今天的工作加油呀！",
        "新的一天，秃秃陪你一起摸鱼！"
    ]
    private let lunchMessages = [
        "主人，该吃饭啦！秃秃也饿了~",
        "主人，秃秃饿啦~记得给秃秃喂食哦😘",
        "一顿不吃饿得慌，秃秃现在很慌荒荒",
        "午饭时间到！快去干饭！",
        "肚子咕咕叫，你也该去吃饭了~",
        "干饭时间！今天中午吃什么？"
    ]
    private let drinkMessages = [
        "主人，该喝水啦！",
        "适当补水皮肤会更好哦，秃秃提醒你的~",
        "咕噜咕噜~喝水时间到！",
        "再不喝水秃秃就要渴死了喵~",
        "多喝水，少秃头！",
        "记得喝水哦，你嘴唇都干了"
    ]
    private let restMessages = [
        "工作不会自己消失，但心会凉。",
        "主人你已经坐很久了，出去溜溜吧",
        "休息一下吧，眼睛需要放松~",
        "起来活动活动，不然要长蘑菇了",
        "摸鱼时间到！适当休息效率更高哦",
        "你已经很棒了，休息一下吧~"
    ]
    private let lieDownMessages = [
        "你的灵魂好像下班了。",
        "秃秃已经发呆很久了，你快跟我玩一会！",
        "躺平也是一种生活态度😴",
        "今天的工作量超标了，建议摆烂",
        "好想变成一条咸鱼啊~",
        "你已经很努力了，该躺平了！"
    ]
    private let dinnerMessages = [
        "快去吃饭吧~秃秃会帮你看着电脑的！",
        "一顿不吃饿得慌，秃秃现在很慌荒荒！"
    ]
    private let idleMessages = [
        "提高时薪中……☺️",
        "上班总是很难熬~快点赚钱给秃秃买罐头！",
        "在吗？摸鱼请带上秃秃~",
        "你觉得秃秃可爱吗？",
        "今天天气不错，适合带薪发呆",
        "让秃秃看看你在忙什么~"
    ]
    private let randomChatMessages = [
        "走得好累啊，秃秃歇会儿吧~",
        "你看那边有什么？",
        "无聊的时候秃秃就想找你聊天",
        "秃秃是一只快乐的小猫咪~",
        "走路带风，走路带风~",
        "要是能飞就好了...",
        "你在忙吗？不用理秃秃也行",
        "这个桌面秃秃巡逻了很多遍了",
        "喵~",
        "好困啊，秃秃想睡觉了",
        "秃秃刚刚在想，猫是不是不用上班🌝。",
        "刚刚有一瞬间，秃秃以为你要下班了🐱~",
        "让秃秃看看你在忙什么~"
    ]

    private var lastActivityTime = Date()
    private var chatCheckTimer: Timer?
    private var triggeredToday = Set<String>()
    private var currentChatMessages: [String] = []
    private var currentChatIndex = 0
    private var lastChatIndex: Int?
    private var lastIdleTriggerTime: Date?
    private var lastTriggerDate: String = ""
    private var localActivityMonitor: Any?
    private var lastAnyChatTime: Date?
    
    // MARK: - 气泡队列
    private var pendingTriggers: [ChatTriggerType] = []
    private var isShowingChatBubble = false
    private var processQueueTimer: Timer?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setupView()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var isOpaque: Bool { false }

    private func setupView() {
        print("PetView setup...")

        // 完全透明背景
        wantsLayer = true
        layer?.backgroundColor = CGColor.clear
        layer?.isOpaque = false

        // 使用 CALayer 直接渲染图片，确保透明区域真正透过去
        imageLayer = CALayer()
        imageLayer.frame = bounds
        imageLayer.autoresizingMask = [.layerWidthSizable, .layerHeightSizable]
        imageLayer.backgroundColor = CGColor.clear
        imageLayer.contentsGravity = .resizeAspect
        layer?.addSublayer(imageLayer)

        loadAssets()
        positionWindowAtBottom()
        setupChatSystem()

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.startWalking()
        }

        print("PetView setup 完成")
    }

    // MARK: - 素材加载

    private func loadAssets() {
        let resourcePath = Bundle.main.resourcePath ?? ""
        let assetsPath = resourcePath + "/Assets"

        loadAssetsFromDirectory(path: assetsPath + "/hover", into: &hoverAssets)
        loadAssetsFromDirectory(path: assetsPath + "/play", into: &playAssets)
        loadAssetsFromDirectory(path: assetsPath + "/walk", into: &walkAssets)
        loadAssetsFromDirectory(path: assetsPath + "/drag", into: &dragAssets)
        loadAssetsFromDirectory(path: assetsPath + "/eat", into: &eatAssets)

        print("素材加载: hover=\(hoverAssets.count), play=\(playAssets.count), walk=\(walkAssets.count), drag=\(dragAssets.count), eat=\(eatAssets.count)")
    }

    private func loadAssetsFromDirectory(path: String, into array: inout [String]) {
        guard FileManager.default.fileExists(atPath: path) else { return }
        do {
            let files = try FileManager.default.contentsOfDirectory(atPath: path)
            for file in files where file.hasSuffix(".gif") || file.hasSuffix(".png") {
                array.append(path + "/" + file)
            }
        } catch {}
    }

    // MARK: - 聊天系统

    private func setupChatSystem() {
        bubbleWindow = BubbleWindow()
        bubbleWindow?.onTap = { [weak self] in
            self?.cycleChatMessage()
        }
        bubbleWindow?.onHide = { [weak self] in
            self?.isShowingChatBubble = false
            self?.processPendingQueue()
        }

        // 每30秒检查一次触发条件，加入队列
        chatCheckTimer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            self?.checkChatTriggers()
        }

        // 延迟2秒后检查一次（等待窗口就位）
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { [weak self] in
            self?.checkChatTriggers()
        }

        // 每5秒处理一次队列
        processQueueTimer = Timer.scheduledTimer(withTimeInterval: 5, repeats: true) { [weak self] _ in
            self?.processPendingQueue()
        }

        // 监听全局活动（应用不在前台时，keyDown需要Accessibility权限，故排除）
        activityMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.mouseMoved, .leftMouseDown, .rightMouseDown, .scrollWheel]) { [weak self] _ in
            self?.lastActivityTime = Date()
        }

        // 监听本地活动（应用在前台时）
        localActivityMonitor = NSEvent.addLocalMonitorForEvents(matching: [.mouseMoved, .leftMouseDown, .rightMouseDown, .keyDown, .scrollWheel]) { [weak self] event in
            self?.lastActivityTime = Date()
            return event
        }
    }

    private func checkChatTriggers() {
        defer {
            cleanupOldTriggers()
        }

        let now = Date()
        let calendar = Calendar.current
        let hour = calendar.component(.hour, from: now)
        let minute = calendar.component(.minute, from: now)
        let todayKey = dateKey(for: now)

        print("[TuTCat] 检查提醒触发 \(hour):\(String(format: "%02d", minute)), pending=\(pendingTriggers.count)")

        // 1. 早安 (9-11点)
        if hour >= 9 && hour < 11 {
            if !triggeredToday.contains("morning-\(todayKey)") {
                addToQueue(.morning)
                triggeredToday.insert("morning-\(todayKey)")
            }
        }

        // 2. 午餐 (11:25-11:35)
        if hour == 11 && minute >= 25 && minute <= 35 {
            if !triggeredToday.contains("lunch-\(todayKey)") {
                addToQueue(.lunch)
                triggeredToday.insert("lunch-\(todayKey)")
            }
        }

        // 3. 晚餐 (17:25-17:35)
        if hour == 17 && minute >= 25 && minute <= 35 {
            if !triggeredToday.contains("dinner-\(todayKey)") {
                addToQueue(.dinner)
                triggeredToday.insert("dinner-\(todayKey)")
            }
        }

        // 4. 喝水 (10:00-20:00，每30分钟)
        if hour >= 10 && (hour < 20 || (hour == 20 && minute == 0)) {
            let slotMinute = (minute / 30) * 30
            let slotKey = "drink-\(hour):\(String(format: "%02d", slotMinute))-\(todayKey)"
            if !triggeredToday.contains(slotKey) {
                addToQueue(.drink)
                triggeredToday.insert(slotKey)
            }
        }

        // 5. 休息 (10:00-20:00，每2小时: 10,12,14,16,18,20)
        if hour >= 10 && hour <= 20 && hour % 2 == 0 && minute < 30 {
            let slotKey = "rest-\(hour):00-\(todayKey)"
            if !triggeredToday.contains(slotKey) {
                addToQueue(.rest)
                triggeredToday.insert(slotKey)
            }
        }

        // 6. 躺平 (10:00-19:00，每3小时: 10,13,16,19)
        let lieDownHours = [10, 13, 16, 19]
        if lieDownHours.contains(hour) && minute < 30 {
            let slotKey = "liedown-\(hour):00-\(todayKey)"
            if !triggeredToday.contains(slotKey) {
                addToQueue(.lieDown)
                triggeredToday.insert(slotKey)
            }
        }

        // 7. 无操作15分钟（每15分钟最多触发一次）
        let idleTime = now.timeIntervalSince(lastActivityTime)
        print("[TuTCat] idleTime=\(String(format: "%.1f", idleTime/60))min")
        if idleTime >= 15 * 60 {
            if let lastIdle = lastIdleTriggerTime, now.timeIntervalSince(lastIdle) < 15 * 60 {
                print("[TuTCat] idle 15分钟内已触发过，跳过")
            } else {
                print("[TuTCat] 触发无操作提醒")
                addToQueue(.idle)
                lastIdleTriggerTime = now
            }
        }

        // 8. 随机闲聊 (每15分钟)
        let slotMinute15 = (minute / 15) * 15
        let randomSlotKey = "randomchat-\(hour):\(String(format: "%02d", slotMinute15))-\(todayKey)"
        if !triggeredToday.contains(randomSlotKey) {
            addToQueue(.randomChat)
            triggeredToday.insert(randomSlotKey)
        }

        // 尝试处理队列
        processPendingQueue()
    }

    private func addToQueue(_ type: ChatTriggerType) {
        if !pendingTriggers.contains(type) {
            pendingTriggers.append(type)
            print("[TuTCat] 加入队列: \(type)")
        }
    }

    private func processPendingQueue() {
        guard !pendingTriggers.isEmpty, !isShowingChatBubble else { return }
        let type = pendingTriggers.removeFirst()
        print("[TuTCat] 队列弹出: \(type)")
        showChat(type: type)
    }

    private func showChat(type: ChatTriggerType) {
        var messages: [String]
        var assets: [String]?

        switch type {
        case .morning:
            messages = morningMessages
            assets = eatAssets
        case .lunch:
            messages = lunchMessages
            assets = nil
        case .dinner:
            messages = dinnerMessages
            assets = nil
        case .drink:
            messages = drinkMessages
            assets = playAssets
        case .rest:
            messages = restMessages
            assets = playAssets
        case .lieDown:
            messages = lieDownMessages
            assets = playAssets
        case .idle:
            messages = idleMessages
            assets = playAssets
        case .randomChat:
            messages = randomChatMessages
            assets = nil
        }

        currentChatMessages = messages
        currentChatIndex = randomChatIndex(for: messages)
        lastChatIndex = currentChatIndex
        lastAnyChatTime = Date()
        isShowingChatBubble = true

        // 播放动画（随机闲聊、午餐、晚餐不播放动画，保持走路）
        if let assets = assets, !assets.isEmpty {
            playAnimation(assets: assets, onComplete: { [weak self] in
                self?.startWalking()
            })
        }

        // 显示气泡
        showBubble()
    }

    private func showBubble() {
        guard !currentChatMessages.isEmpty, let window = window else { return }
        let message = currentChatMessages[currentChatIndex]
        bubbleWindow?.show(message: message, above: window)
    }

    private func cycleChatMessage() {
        guard !currentChatMessages.isEmpty else { return }
        currentChatIndex = randomChatIndex(for: currentChatMessages)
        lastChatIndex = currentChatIndex
        showBubble()
    }

    private func randomChatIndex(for messages: [String]) -> Int {
        guard messages.count > 1 else { return 0 }
        var newIndex = Int.random(in: 0..<messages.count)
        // 避免连续两次展示同一条
        if let last = lastChatIndex, messages.count > 1 {
            while newIndex == last {
                newIndex = Int.random(in: 0..<messages.count)
            }
        }
        return newIndex
    }

    private func updateBubblePosition() {
        guard let window = window else { return }
        bubbleWindow?.updatePosition(relativeTo: window)
    }

    private func dateKey(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }

    private func cleanupOldTriggers() {
        let todayKey = dateKey(for: Date())
        let oldCount = triggeredToday.count
        triggeredToday = triggeredToday.filter { $0.hasSuffix(todayKey) }
        if triggeredToday.count < oldCount {
            print("[TuTCat] 清理旧触发记录: \(oldCount - triggeredToday.count) 条")
        }
        if lastTriggerDate != todayKey {
            lastTriggerDate = todayKey
            print("[TuTCat] 新的一天，重置触发记录")
        }
    }

    // MARK: - 图片显示

    private func loadImage(path: String, mirrored: Bool = false, loops: Bool = true, onComplete: (() -> Void)? = nil) {
        stopGIFAnimation()

        if path.lowercased().hasSuffix(".gif") {
            loadAnimatedGIF(path: path, loops: loops, onComplete: onComplete)
        } else {
            guard let image = NSImage(contentsOfFile: path) else {
                onComplete?()
                return
            }
            var imageRect = NSRect(origin: .zero, size: image.size)
            if let cgImage = image.cgImage(forProposedRect: &imageRect, context: nil, hints: nil) {
                imageLayer.contents = cgImage
            } else {
                imageLayer.contents = image
            }
            if !loops {
                onComplete?()
            }
        }

        CATransaction.begin()
        CATransaction.setDisableActions(true)
        if mirrored {
            imageLayer.transform = CATransform3DMakeScale(-1, 1, 1)
        } else {
            imageLayer.transform = CATransform3DIdentity
        }
        CATransaction.commit()
    }

    private func loadAnimatedGIF(path: String, loops: Bool = true, onComplete: (() -> Void)? = nil) {
        guard let data = try? Data(contentsOf: URL(fileURLWithPath: path)),
              let source = CGImageSourceCreateWithData(data as CFData, nil) else {
            onComplete?()
            return
        }

        let count = CGImageSourceGetCount(source)
        guard count > 1 else {
            if let cgImage = CGImageSourceCreateImageAtIndex(source, 0, nil) {
                imageLayer.contents = cgImage
            }
            if !loops {
                onComplete?()
            }
            return
        }

        gifFrames = []
        gifDelays = []

        for i in 0..<count {
            if let cgImage = CGImageSourceCreateImageAtIndex(source, i, nil) {
                gifFrames.append(cgImage)
                gifDelays.append(frameDelay(source: source, index: i))
            }
        }

        guard !gifFrames.isEmpty else {
            onComplete?()
            return
        }

        self.gifLoops = loops
        self.gifCompletion = onComplete

        imageLayer.contents = gifFrames[0]
        gifCurrentFrame = 0
        gifAccumulatedTime = 0

        gifTimer = Timer.scheduledTimer(timeInterval: 1.0 / 30.0, target: self, selector: #selector(updateGIFFrame), userInfo: nil, repeats: true)
    }

    @objc private func updateGIFFrame() {
        guard !gifFrames.isEmpty, gifCurrentFrame < gifDelays.count else { return }

        gifAccumulatedTime += 1.0 / 30.0

        let frameDelay = gifDelays[gifCurrentFrame]
        if gifAccumulatedTime >= frameDelay {
            gifAccumulatedTime = 0
            let nextFrame = gifCurrentFrame + 1

            if nextFrame >= gifFrames.count {
                if gifLoops {
                    gifCurrentFrame = 0
                    imageLayer.contents = gifFrames[0]
                } else {
                    gifTimer?.invalidate()
                    gifTimer = nil
                    let completion = gifCompletion
                    gifCompletion = nil
                    completion?()
                    return
                }
            } else {
                gifCurrentFrame = nextFrame
                imageLayer.contents = gifFrames[gifCurrentFrame]
            }
        }
    }

    private func stopGIFAnimation() {
        gifTimer?.invalidate()
        gifTimer = nil
        gifFrames = []
        gifDelays = []
        gifCurrentFrame = 0
        gifAccumulatedTime = 0
        gifLoops = true
        gifCompletion = nil
    }

    private func frameDelay(source: CGImageSource, index: Int) -> Double {
        guard let properties = CGImageSourceCopyPropertiesAtIndex(source, index, nil) as? [String: Any],
              let gifProps = properties[kCGImagePropertyGIFDictionary as String] as? [String: Any] else {
            return 0.1
        }

        if let delay = gifProps[kCGImagePropertyGIFUnclampedDelayTime as String] as? Double, delay > 0 {
            return delay
        }
        if let delay = gifProps[kCGImagePropertyGIFDelayTime as String] as? Double, delay > 0 {
            return delay
        }
        return 0.1
    }

    // MARK: - 窗口定位

    private func positionWindowAtBottom() {
        guard let window = window, let screen = NSScreen.main else { return }
        let screenFrame = screen.visibleFrame
        let size = self.windowSize

        let x = screenFrame.midX - size / 2
        let y = screenFrame.minY - 20

        window.setFrameOrigin(NSPoint(x: x, y: y))
    }

    // MARK: - 走路逻辑

    private func startWalking() {
        stopWalking()
        isPlayingAnimation = false
        lastEdgeBounceDirection = walkDirection

        guard !walkAssets.isEmpty else { return }

        loadImage(path: walkAssets[0], mirrored: walkDirection > 0)

        walkTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] _ in
            self?.walkStep()
        }

        scheduleDirectionChange()
        scheduleIdleBreak()
    }

    private func stopWalking() {
        walkTimer?.invalidate()
        walkTimer = nil
        directionTimer?.invalidate()
        directionTimer = nil
        idleTimer?.invalidate()
        idleTimer = nil
    }

    private func walkStep() {
        guard let window = window else { return }

        // 每20帧（约1秒）检查一次walk动画健康状态
        walkHealthCheckCounter += 1
        if walkHealthCheckCounter >= 20 {
            walkHealthCheckCounter = 0
            if gifTimer == nil && !isPlayingAnimation && !isHovering && !walkAssets.isEmpty {
                print("[TuTCat] 检测到walk动画停止，自动恢复")
                loadImage(path: walkAssets[0], mirrored: walkDirection > 0)
            }
        }

        var frame = window.frame
        frame.origin.x += CGFloat(walkDirection) * CGFloat(walkSpeed)
        window.setFrame(frame, display: true)

        // 更新气泡位置
        updateBubblePosition()

        if let screen = NSScreen.main {
            let screenFrame = screen.visibleFrame
            var didBounce = false
            if frame.maxX > screenFrame.maxX - 50 {
                walkDirection = -1
                didBounce = true
            } else if frame.minX < screenFrame.minX + 50 {
                walkDirection = 1
                didBounce = true
            }
            // 只有方向真正改变时才重新加载素材，避免边缘反复碰撞时频繁重建GIF timer
            if didBounce && walkDirection != lastEdgeBounceDirection {
                lastEdgeBounceDirection = walkDirection
                if !walkAssets.isEmpty {
                    loadImage(path: walkAssets[0], mirrored: walkDirection > 0)
                }
            }
        }
    }

    private func scheduleDirectionChange() {
        directionTimer?.invalidate()
        let delay = Double.random(in: 3.0...8.0)
        directionTimer = Timer.scheduledTimer(withTimeInterval: delay, repeats: false) { [weak self] _ in
            guard let self = self else { return }
            let oldDir = self.walkDirection
            self.walkDirection *= -1
            self.lastEdgeBounceDirection = self.walkDirection
            if !self.walkAssets.isEmpty, self.walkDirection != oldDir {
                self.loadImage(path: self.walkAssets[0], mirrored: self.walkDirection > 0)
            }
            self.scheduleDirectionChange()
        }
    }

    private func scheduleIdleBreak() {
        idleTimer?.invalidate()
        let delay = Double.random(in: 15.0...45.0)
        idleTimer = Timer.scheduledTimer(withTimeInterval: delay, repeats: false) { [weak self] _ in
            guard let self = self else { return }
            // 如果有其他动画在播放或鼠标悬停，不触发休息
            guard !self.isPlayingAnimation, !self.isHovering else {
                self.scheduleIdleBreak()
                return
            }
            self.takeIdleBreak()
        }
    }

    private func takeIdleBreak() {
        var allAssets: [[String]] = []
        if !hoverAssets.isEmpty { allAssets.append(hoverAssets) }
        if !playAssets.isEmpty { allAssets.append(playAssets) }
        if !eatAssets.isEmpty { allAssets.append(eatAssets) }

        guard let assets = allAssets.randomElement(), !assets.isEmpty else {
            scheduleIdleBreak()
            return
        }

        playAnimation(assets: assets) { [weak self] in
            self?.startWalking()
        }
    }

    // MARK: - 动画播放

    private func playAnimation(assets: [String], duration: TimeInterval = 2.0, onComplete: (() -> Void)? = nil) {
        guard !assets.isEmpty else {
            onComplete?()
            return
        }

        isPlayingAnimation = true
        stopWalking()

        let path = assets.randomElement()!

        if path.lowercased().hasSuffix(".gif") {
            loadImage(path: path, mirrored: walkDirection > 0, loops: false) { [weak self] in
                self?.isPlayingAnimation = false
                onComplete?()
            }
        } else {
            loadImage(path: path, mirrored: walkDirection > 0)
            animationTimer = Timer.scheduledTimer(withTimeInterval: duration, repeats: false) { [weak self] _ in
                self?.isPlayingAnimation = false
                onComplete?()
            }
        }
    }

    // MARK: - 鼠标事件

    override func mouseEntered(with event: NSEvent) {
        guard !isPlayingAnimation else { return }
        isHovering = true
        stopWalking()

        if !hoverAssets.isEmpty {
            let path = hoverAssets.randomElement()!
            loadImage(path: path, mirrored: walkDirection > 0, loops: false) { [weak self] in
                guard let self = self else { return }
                self.isHovering = false
                if !self.isPlayingAnimation {
                    self.startWalking()
                }
            }
        }
    }

    override func mouseExited(with event: NSEvent) {
        isHovering = false
        if gifTimer == nil && !isPlayingAnimation {
            startWalking()
        }
    }

    override func mouseDown(with event: NSEvent) {
        dragStartPoint = window?.frame.origin ?? .zero
        lastMouseDownLocation = NSEvent.mouseLocation
        isDragging = false
        stopWalking()
    }

    override func mouseDragged(with event: NSEvent) {
        let wasDragging = isDragging
        isDragging = true
        guard let window = window else { return }

        if !wasDragging && !dragAssets.isEmpty {
            let path = dragAssets.randomElement()!
            loadImage(path: path, mirrored: walkDirection > 0)
        }

        let currentScreenLocation = NSEvent.mouseLocation
        let delta = NSPoint(
            x: currentScreenLocation.x - lastMouseDownLocation.x,
            y: currentScreenLocation.y - lastMouseDownLocation.y
        )

        var newOrigin = dragStartPoint
        newOrigin.x += delta.x
        newOrigin.y += delta.y
        window.setFrameOrigin(newOrigin)

        // 更新气泡位置
        updateBubblePosition()
    }

    override func mouseUp(with event: NSEvent) {
        let distance = hypot(
            event.locationInWindow.x - lastMouseDownLocation.x,
            event.locationInWindow.y - lastMouseDownLocation.y
        )

        if distance < 5 && !isDragging {
            playAnimation(assets: playAssets) { [weak self] in
                self?.startWalking()
            }
        } else {
            startWalking()
        }
        isDragging = false
    }

    override func rightMouseDown(with event: NSEvent) {
        showContextMenu(with: event)
    }

    // MARK: - 右键菜单

    private func showContextMenu(with event: NSEvent) {
        let menu = NSMenu()

        menu.addItem(NSMenuItem(title: "换姿势", action: #selector(changePose), keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "喂食", action: #selector(feedPet), keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "玩耍", action: #selector(playWithPet), keyEquivalent: ""))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "测试气泡", action: #selector(testBubble), keyEquivalent: ""))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "设置...", action: #selector(openSettings), keyEquivalent: ","))
        menu.addItem(NSMenuItem(title: "打开素材文件夹", action: #selector(openAssetsFolder), keyEquivalent: ""))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "出门", action: #selector(quitApp), keyEquivalent: "q"))

        for item in menu.items {
            item.target = self
        }

        NSMenu.popUpContextMenu(menu, with: event, for: self)
    }

    @objc private func changePose() {
        playAnimation(assets: playAssets) { [weak self] in
            self?.startWalking()
        }
    }

    @objc private func feedPet() {
        playAnimation(assets: eatAssets) { [weak self] in
            self?.startWalking()
        }
    }

    @objc private func playWithPet() {
        playAnimation(assets: playAssets) { [weak self] in
            self?.startWalking()
        }
    }

    @objc private func testBubble() {
        showChat(type: .morning)
    }

    @objc private func openSettings() {
        showSettingsPanel()
    }

    @objc private func openAssetsFolder() {
        let assetsPath = Bundle.main.resourcePath ?? "" + "/Assets"
        NSWorkspace.shared.open(URL(fileURLWithPath: assetsPath))
    }

    @objc private func quitApp() {
        NSApplication.shared.terminate(nil)
    }

    // MARK: - 设置面板

    private func showSettingsPanel() {
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 300, height: 350),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        panel.title = "TuTCat 设置"
        panel.level = .floating
        panel.center()

        let settingsView = SettingsView(petView: self)
        panel.contentView = NSHostingView(rootView: settingsView)
        panel.makeKeyAndOrderFront(nil)
    }

    func setWindowSize(_ size: CGFloat) {
        windowSize = size
        if let window = window {
            var frame = window.frame
            let diff = size - frame.width
            frame.size = NSSize(width: size, height: size)
            frame.origin.x -= diff / 2
            window.setFrame(frame, display: true)
        }
        imageLayer.frame = bounds
    }

    func setWalkSpeed(_ speed: Double) {
        walkSpeed = speed
    }

    func resetPosition() {
        positionWindowAtBottom()
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        for trackingArea in trackingAreas {
            removeTrackingArea(trackingArea)
        }
        let options: NSTrackingArea.Options = [.mouseEnteredAndExited, .activeAlways, .inVisibleRect]
        addTrackingArea(NSTrackingArea(rect: bounds, options: options, owner: self, userInfo: nil))
    }

    deinit {
        if let monitor = activityMonitor {
            NSEvent.removeMonitor(monitor)
        }
        if let monitor = localActivityMonitor {
            NSEvent.removeMonitor(monitor)
        }
        chatCheckTimer?.invalidate()
        processQueueTimer?.invalidate()
        bubbleWindow?.hide()
    }
}

// MARK: - 设置视图
struct SettingsView: View {
    weak var petView: PetView?
    @State private var windowSize: Double = 240
    @State private var walkSpeed: Double = 2.0

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("TuTCat 设置")
                .font(.headline)
                .padding(.bottom, 8)

            VStack(alignment: .leading) {
                Text("窗口大小: \(Int(windowSize))px")
                Slider(value: $windowSize, in: 120...400, step: 20)
                    .onChange(of: windowSize) { _, newValue in
                        petView?.setWindowSize(newValue)
                    }
            }

            VStack(alignment: .leading) {
                Text("移动速度: \(String(format: "%.1f", walkSpeed))")
                Slider(value: $walkSpeed, in: 0.5...5.0, step: 0.5)
                    .onChange(of: walkSpeed) { _, newValue in
                        petView?.setWalkSpeed(newValue)
                    }
            }

            Divider()

            Button("重置到桌面底部") {
                petView?.resetPosition()
            }

            Button("打开素材文件夹") {
                let assetsPath = Bundle.main.resourcePath ?? "" + "/Assets"
                NSWorkspace.shared.open(URL(fileURLWithPath: assetsPath))
            }

            Divider()

            Button("出门") {
                NSApplication.shared.terminate(nil)
            }

            Spacer()
        }
        .padding()
        .onAppear {
            if let pv = petView {
                windowSize = Double(pv.bounds.width)
            }
        }
    }
}
