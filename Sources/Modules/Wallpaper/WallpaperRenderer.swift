import AppKit
import AVFoundation

final class WallpaperRenderer: NSView {
    private var imageView: NSImageView?
    private var videoLayer: AVPlayerLayer?
    private var player: AVQueuePlayer?
    private var looper: AVPlayerLooper?
    private var wave: WaveformWallpaper?
    private var html: HTMLWallpaper?
    private var scaling: DesktopConfiguration.Scaling = .fill

    init(url: URL, kind: DesktopConfiguration.Media, scaling: DesktopConfiguration.Scaling,
         accent: NSColor, active: Bool, volume: Double) throws {
        super.init(frame: .zero)
        self.scaling = scaling
        wantsLayer = true
        layer?.backgroundColor = NSColor.black.cgColor
        layer?.masksToBounds = true
        switch kind {
        case .png, .gif:
            guard let image = NSImage(contentsOf: url), image.isValid else {
                throw EngineError(message: "The selected image could not be opened.")
            }
            let view = NSImageView()
            view.image = image
            view.imageScaling = .scaleAxesIndependently
            addSubview(view)
            imageView = view
        case .mp4:
            let player = AVQueuePlayer()
            let item = AVPlayerItem(url: url)
            looper = AVPlayerLooper(player: player, templateItem: item)
            let video = AVPlayerLayer(player: player)
            video.videoGravity = scaling == .stretch ? .resize : scaling == .fit ? .resizeAspect : .resizeAspectFill
            layer?.addSublayer(video)
            videoLayer = video
            self.player = player
        case .html:
            let page = try HTMLWallpaper(url: url)
            page.frame = bounds
            page.autoresizingMask = [.width, .height]
            addSubview(page)
            html = page
        case .wav:
            let view = try WaveformWallpaper(url: url, accent: accent)
            view.frame = bounds
            view.autoresizingMask = [.width, .height]
            addSubview(view)
            wave = view
        }
        setPlayback(active: active, volume: volume)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    func setPlayback(active: Bool, volume: Double) {
        imageView?.animates = active
        player?.volume = Float(volume)
        if active { player?.play() } else { player?.pause() }
        wave?.setPlayback(active: active, volume: volume)
        html?.isHidden = !active
    }

    override func layout() {
        super.layout()
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        videoLayer?.frame = bounds
        CATransaction.commit()
        if let view = imageView, let size = view.image?.size, size.width > 0, size.height > 0 {
            let x = bounds.width / size.width, y = bounds.height / size.height
            let scale = scaling == .fill ? max(x, y) : scaling == .fit ? min(x, y) : 1
            let w = scaling == .stretch ? bounds.width : size.width * scale
            let h = scaling == .stretch ? bounds.height : size.height * scale
            view.frame = NSRect(x: bounds.midX - w / 2, y: bounds.midY - h / 2, width: w, height: h)
        }
    }

    deinit { player?.pause(); looper?.disableLooping(); player?.removeAllItems() }
}

final class WaveformWallpaper: NSView {
    private let player: AVAudioPlayer
    private let file: AVAudioFile
    private let buffer: AVAudioPCMBuffer
    private let accent: NSColor
    private var timer: Timer?
    private var levels = [CGFloat](repeating: 0, count: 64)

    init(url: URL, accent: NSColor) throws {
        player = try AVAudioPlayer(contentsOf: url)
        file = try AVAudioFile(forReading: url, commonFormat: .pcmFormatFloat32, interleaved: false)
        guard let buffer = AVAudioPCMBuffer(pcmFormat: file.processingFormat, frameCapacity: 4096) else {
            throw EngineError(message: "Couldn't allocate a WAV visualization buffer.")
        }
        self.buffer = buffer
        self.accent = accent
        super.init(frame: .zero)
        player.numberOfLoops = -1
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    func setPlayback(active: Bool, volume: Double) {
        player.volume = Float(volume)
        if active, timer == nil {
            player.play()
            let timer = Timer(timeInterval: 1 / 24, repeats: true) { [weak self] _ in self?.sample() }
            RunLoop.main.add(timer, forMode: .common)
            self.timer = timer
        } else if !active {
            player.pause()
            timer?.invalidate()
            timer = nil
        }
        if timer == nil { sample() }
    }

    private func sample() {
        file.framePosition = min(file.length - 1, AVAudioFramePosition(player.currentTime * file.processingFormat.sampleRate))
        guard (try? file.read(into: buffer)) != nil, let samples = buffer.floatChannelData?[0] else { return }
        let length = Int(buffer.frameLength)
        let step = max(1, length / levels.count)
        for i in levels.indices {
            let start = min(i * step, length), end = min(start + step, length)
            var peak: Float = 0
            for index in start..<end where samples[index].isFinite { peak = max(peak, abs(samples[index])) }
            levels[i] = CGFloat(min(1, peak))
        }
        needsDisplay = true
    }

    override func draw(_ dirtyRect: NSRect) {
        NSGradient(starting: accent.blended(withFraction: 0.87, of: .black) ?? .black,
                   ending: .black)?.draw(in: bounds, angle: 270)
        let width = bounds.width * 0.74, baseline = bounds.midY, step = width / CGFloat(levels.count)
        for (i, level) in levels.enumerated() {
            let height = max(2, sqrt(level) * bounds.height * 0.52)
            let x = bounds.midX - width / 2 + CGFloat(i) * step
            let bar = NSRect(x: x, y: baseline - height / 2, width: max(1, step * 0.56), height: height)
            accent.withAlphaComponent(0.45 + level * 0.55).setFill()
            NSBezierPath(roundedRect: bar, xRadius: 4, yRadius: 4).fill()
        }
    }

    deinit { timer?.invalidate(); player.stop() }
}
