//
//  EditorViewController+LoadAsset.swift
//  HXPhotoPicker
//
//  Created by Silence on 2023/5/20.
//

import UIKit
import AVFoundation
import ImageIO
import UniformTypeIdentifiers

extension EditorViewController {
    
    private struct PreparedEditorImage {
        let image: UIImage
        let imageData: Data?
        let isHEIC: Bool
        let isJPEG: Bool
    }
    
    enum LoadAssetStatus {
        case loadding(Bool = false)
        case succeed(EditorAsset.AssetType)
        case imageURL(URL)
        case failure
    }
    
    func initAsset() {
        let asset = selectedAsset
        initAssetType(asset.type)
    }
    func initAssetType(_ type: EditorAsset.AssetType) {
        let viewSize = UIDevice.screenSize
        switch type {
        case .image(let image):
            if !isTransitionCompletion {
                loadAssetStatus = .succeed(.image(image))
                return
            }
            loadImageForEditing(
                image,
                viewSize: viewSize
            )
        case .imageData(let imageData):
            if !isTransitionCompletion {
                loadAssetStatus = .succeed(.imageData(imageData))
                return
            }
            loadImageDataForEditing(
                imageData,
                viewSize: viewSize
            )
        case .video(let url):
            if !isTransitionCompletion {
                loadAssetStatus = .succeed(.video(url))
                return
            }
            let avAsset = AVAsset(url: url)
            let image = avAsset.getImage(at: 0.1)
            editorView.setAVAsset(avAsset, coverImage: image)
            editorView.loadVideo(isPlay: false)
            loadCompletion()
            loadLastEditedData()
        case .videoAsset(let avAsset):
            if !isTransitionCompletion {
                loadAssetStatus = .succeed(.videoAsset(avAsset))
                return
            }
            let image = avAsset.getImage(at: 0.1)
            editorView.setAVAsset(avAsset, coverImage: image)
            editorView.loadVideo(isPlay: false)
            loadCompletion()
            loadLastEditedData()
        case .networkVideo(let videoURL):
            downloadNetworkVideo(videoURL)
        case .networkImage(let url):
            downloadNetworkImage(url)
        #if HXPICKER_ENABLE_PICKER
        case .photoAsset(let photoAsset):
            loadPhotoAsset(photoAsset)
        #endif
        }
    }
    
    private func loadImageForEditing(
        _ image: UIImage,
        imageData: Data? = nil,
        viewSize: CGSize,
        dismissLoadingView: Bool = false,
        failureMessage: String = .textManager.editor.photoLoadFailedAlertMessage.text
    ) {
        if let imageData {
            loadImageDataForEditing(
                imageData,
                viewSize: viewSize,
                dismissLoadingView: dismissLoadingView,
                failureMessage: failureMessage
            )
            return
        }
        prepareImageForEditing(
            image,
            imageData: nil
        ) { [weak self] result in
            guard let self = self else {
                return
            }
            DispatchQueue.main.async {
                if dismissLoadingView {
                    PhotoManager.HUDView.dismiss(
                        delay: 0,
                        animated: true,
                        for: self.view
                    )
                }
                guard let result = result else {
                    self.loadFailure(message: failureMessage)
                    return
                }
                self.finishImageLoad(result, viewSize: viewSize)
            }
        }
    }
    
    private func loadImageDataForEditing(
        _ imageData: Data,
        viewSize: CGSize,
        dismissLoadingView: Bool = false,
        failureMessage: String = .textManager.editor.photoLoadFailedAlertMessage.text
    ) {
        prepareImageDataForEditing(imageData) { [weak self] result in
            guard let self = self else {
                return
            }
            DispatchQueue.main.async {
                if dismissLoadingView {
                    PhotoManager.HUDView.dismiss(
                        delay: 0,
                        animated: true,
                        for: self.view
                    )
                }
                guard let result = result else {
                    self.loadFailure(message: failureMessage)
                    return
                }
                self.finishImageLoad(result, viewSize: viewSize)
            }
        }
    }

    func loadImageURLForEditing(
        _ url: URL,
        viewSize: CGSize,
        dismissLoadingView: Bool = false,
        failureMessage: String = .textManager.editor.photoLoadFailedAlertMessage.text
    ) {
        prepareImageURLForEditing(url) { [weak self] result in
            guard let self = self else {
                return
            }
            DispatchQueue.main.async {
                if dismissLoadingView {
                    PhotoManager.HUDView.dismiss(
                        delay: 0,
                        animated: true,
                        for: self.view
                    )
                }
                guard let result = result else {
                    self.loadFailure(message: failureMessage)
                    return
                }
                self.finishImageLoad(result, viewSize: viewSize)
            }
        }
    }
    
    private func finishImageLoad(
        _ result: PreparedEditorImage,
        viewSize: CGSize
    ) {
        editorView.isHEICImage = result.isHEIC
        editorView.isJPEGImage = result.isJPEG
        if let imageData = result.imageData {
            editorView.setImageData(imageData)
        }else {
            editorView.setImage(result.image)
        }
        loadCompletion()
        loadLastEditedData()
        DispatchQueue.global().async {
            self.loadThumbnailImage(result.image, viewSize: viewSize)
        }
    }
    
    private func prepareImageDataForEditing(
        _ imageData: Data,
        completion: @escaping (PreparedEditorImage?) -> Void
    ) {
        let queue = DispatchQueue(
            label: "HXPhotoPicker.editor.prepareImageDataForEditing",
            qos: .userInitiated,
            attributes: [],
            autoreleaseFrequency: .workItem,
            target: nil
        )
        queue.async {
            autoreleasepool {
                completion(self.prepareImageDataForEditing(imageData))
            }
        }
    }
    
    private func prepareImageForEditing(
        _ image: UIImage,
        imageData: Data? = nil,
        completion: @escaping (PreparedEditorImage?) -> Void
    ) {
        let queue = DispatchQueue(
            label: "HXPhotoPicker.editor.prepareImageForEditing",
            qos: .userInitiated,
            attributes: [],
            autoreleaseFrequency: .workItem,
            target: nil
        )
        queue.async {
            autoreleasepool {
                completion(
                    self.prepareImageForEditing(
                        image,
                        imageData: imageData
                    )
                )
            }
        }
    }

    private func prepareImageURLForEditing(
        _ url: URL,
        completion: @escaping (PreparedEditorImage?) -> Void
    ) {
        let queue = DispatchQueue(
            label: "HXPhotoPicker.editor.prepareImageURLForEditing",
            qos: .userInitiated,
            attributes: [],
            autoreleaseFrequency: .workItem,
            target: nil
        )
        queue.async {
            autoreleasepool {
                completion(self.prepareImageURLForEditing(url))
            }
        }
    }
    
    private func prepareImageForEditing(
        _ image: UIImage,
        imageData: Data?
    ) -> PreparedEditorImage? {
        let sourceImage = image.normalizedImage() ?? image
        let sourceIsGIF = imageData?.isGif == true
        let sourceIsHEIC = imageData?.isHEIC == true
        let sourceIsJPEG = !sourceIsHEIC && imageData?.imageContentType == .jpg
        let maxPixelLength = editorImageMaxPixelLength(for: sourceImage)
        let threshold = editorImageCompressionThreshold
        if sourceIsGIF || maxPixelLength <= threshold {
            return .init(
                image: sourceImage,
                imageData: imageData,
                isHEIC: sourceIsHEIC,
                isJPEG: sourceIsJPEG
            )
        }
        let compressionScale = threshold / maxPixelLength
        guard let scaledImage = sourceImage.scaleImage(toScale: compressionScale) else {
            return .init(
                image: sourceImage,
                imageData: imageData,
                isHEIC: sourceIsHEIC,
                isJPEG: sourceIsJPEG
            )
        }
        let compressedData = compressedEditorImageData(
            for: scaledImage,
            sourceIsHEIC: sourceIsHEIC,
            sourceIsJPEG: sourceIsJPEG
        )
        guard let compressedData,
              let compressedImage = UIImage(data: compressedData)?.normalizedImage() else {
            return .init(
                image: scaledImage,
                imageData: nil,
                isHEIC: sourceIsHEIC,
                isJPEG: sourceIsJPEG
            )
        }
        return .init(
            image: compressedImage,
            imageData: compressedData,
            isHEIC: compressedData.isHEIC,
            isJPEG: !compressedData.isHEIC && compressedData.imageContentType == .jpg
        )
    }

    private func prepareImageURLForEditing(
        _ url: URL
    ) -> PreparedEditorImage? {
        guard let imageSource = CGImageSourceCreateWithURL(
            url as CFURL,
            editorImageSourceOptions
        ) else {
            if let imageData = editorImageData(contentsOf: url) {
                return prepareImageDataForEditing(imageData)
            }
            guard let image = UIImage(contentsOfFile: url.path)?.normalizedImage() else {
                return nil
            }
            return prepareImageForEditing(image, imageData: nil)
        }
        let maxPixelLength = editorImageMaxPixelLength(for: imageSource)
        let sourceIsGIF = url.isGif || editorImageSourceIsGIF(imageSource)
        let sourceIsHEIC = editorImageSourceIsHEIC(imageSource)
        let sourceIsJPEG = !sourceIsHEIC && editorImageSourceIsJPEG(imageSource)
        if sourceIsGIF {
            guard let imageData = editorImageData(contentsOf: url) else {
                return nil
            }
            return prepareAnimatedImageDataForEditing(
                imageSource,
                originalData: imageData,
                maxPixelLength: maxPixelLength
            )
        }
        guard maxPixelLength > 0 else {
            if let imageData = editorImageData(contentsOf: url) {
                return prepareImageDataForEditing(imageData)
            }
            guard let image = UIImage(contentsOfFile: url.path)?.normalizedImage() else {
                return nil
            }
            return prepareImageForEditing(image, imageData: nil)
        }
        if maxPixelLength <= editorImageCompressionThreshold {
            if let imageData = editorImageData(contentsOf: url),
               let image = UIImage(data: imageData)?.normalizedImage() {
                return .init(
                    image: image,
                    imageData: imageData,
                    isHEIC: sourceIsHEIC,
                    isJPEG: sourceIsJPEG
                )
            }
            guard let image = UIImage(contentsOfFile: url.path)?.normalizedImage() else {
                return nil
            }
            return .init(
                image: image,
                imageData: nil,
                isHEIC: sourceIsHEIC,
                isJPEG: sourceIsJPEG
            )
        }
        guard let scaledImage = editorImage(
            from: imageSource,
            maxPixelSize: editorImageCompressionThreshold
        ) else {
            if let imageData = editorImageData(contentsOf: url) {
                return prepareImageDataForEditing(imageData)
            }
            guard let image = UIImage(contentsOfFile: url.path)?.normalizedImage() else {
                return nil
            }
            return prepareImageForEditing(image, imageData: nil)
        }
        let compressedData = compressedEditorImageData(
            for: scaledImage,
            sourceIsHEIC: sourceIsHEIC,
            sourceIsJPEG: sourceIsJPEG
        )
        guard let compressedData,
              let compressedImage = UIImage(data: compressedData)?.normalizedImage() else {
            return .init(
                image: scaledImage,
                imageData: nil,
                isHEIC: sourceIsHEIC,
                isJPEG: sourceIsJPEG
            )
        }
        return .init(
            image: compressedImage,
            imageData: compressedData,
            isHEIC: compressedData.isHEIC,
            isJPEG: !compressedData.isHEIC && compressedData.imageContentType == .jpg
        )
    }

    private func prepareImageDataForEditing(
        _ imageData: Data
    ) -> PreparedEditorImage? {
        guard let imageSource = CGImageSourceCreateWithData(
            imageData as CFData,
            editorImageSourceOptions
        ) else {
            guard let image = UIImage(data: imageData)?.normalizedImage() else {
                return nil
            }
            return prepareImageForEditing(
                image,
                imageData: imageData
            )
        }
        let maxPixelLength = editorImageMaxPixelLength(for: imageSource)
        if imageData.isGif {
            return prepareAnimatedImageDataForEditing(
                imageSource,
                originalData: imageData,
                maxPixelLength: maxPixelLength
            )
        }
        guard maxPixelLength > 0 else {
            guard let image = UIImage(data: imageData)?.normalizedImage() else {
                return nil
            }
            return prepareImageForEditing(
                image,
                imageData: imageData
            )
        }
        let sourceIsHEIC = imageData.isHEIC
        let sourceIsJPEG = !sourceIsHEIC && imageData.imageContentType == .jpg
        if maxPixelLength <= editorImageCompressionThreshold {
            guard let image = UIImage(data: imageData)?.normalizedImage() else {
                return nil
            }
            return .init(
                image: image,
                imageData: imageData,
                isHEIC: sourceIsHEIC,
                isJPEG: sourceIsJPEG
            )
        }
        guard let scaledImage = editorImage(
            from: imageSource,
            maxPixelSize: editorImageCompressionThreshold
        ) else {
            guard let image = UIImage(data: imageData)?.normalizedImage() else {
                return nil
            }
            return prepareImageForEditing(
                image,
                imageData: imageData
            )
        }
        let compressedData = compressedEditorImageData(
            for: scaledImage,
            sourceIsHEIC: sourceIsHEIC,
            sourceIsJPEG: sourceIsJPEG
        )
        guard let compressedData,
              let compressedImage = UIImage(data: compressedData)?.normalizedImage() else {
            return .init(
                image: scaledImage,
                imageData: nil,
                isHEIC: sourceIsHEIC,
                isJPEG: sourceIsJPEG
            )
        }
        return .init(
            image: compressedImage,
            imageData: compressedData,
            isHEIC: compressedData.isHEIC,
            isJPEG: !compressedData.isHEIC && compressedData.imageContentType == .jpg
        )
    }

    private func prepareAnimatedImageDataForEditing(
        _ imageSource: CGImageSource,
        originalData: Data,
        maxPixelLength: CGFloat
    ) -> PreparedEditorImage? {
        let previewMaxPixelSize = min(
            maxPixelLength > 0 ? maxPixelLength : editorImageCompressionThreshold,
            editorImageCompressionThreshold
        )
        guard let previewImage = editorImage(
            from: imageSource,
            maxPixelSize: previewMaxPixelSize
        ) ?? UIImage(data: originalData)?.normalizedImage() else {
            return nil
        }
        if maxPixelLength <= editorImageCompressionThreshold {
            return .init(
                image: previewImage,
                imageData: originalData,
                isHEIC: false,
                isJPEG: false
            )
        }
        guard let compressedResult = compressedAnimatedEditorImageData(
            from: imageSource,
            maxPixelSize: editorImageCompressionThreshold
        ) else {
            return .init(
                image: previewImage,
                imageData: originalData,
                isHEIC: false,
                isJPEG: false
            )
        }
        return .init(
            image: compressedResult.image,
            imageData: compressedResult.data,
            isHEIC: false,
            isJPEG: false
        )
    }
    
    private var editorImageCompressionThreshold: CGFloat {
        UIScreen._scale * max(UIDevice.screenSize.width, UIDevice.screenSize.height)
    }

    private var editorImageSourceOptions: CFDictionary {
        [
            kCGImageSourceShouldCache: false
        ] as CFDictionary
    }
    
    private func editorImageMaxPixelLength(
        for image: UIImage
    ) -> CGFloat {
        if let cgImage = image.cgImage {
            return max(CGFloat(cgImage.width), CGFloat(cgImage.height))
        }
        return max(image.size.width * image.scale, image.size.height * image.scale)
    }

    private func editorImageMaxPixelLength(
        for imageSource: CGImageSource
    ) -> CGFloat {
        guard let properties = CGImageSourceCopyPropertiesAtIndex(
            imageSource,
            0,
            nil
        ) as? [CFString: Any] else {
            return 0
        }
        let width = (properties[kCGImagePropertyPixelWidth] as? NSNumber)?.doubleValue ?? 0
        let height = (properties[kCGImagePropertyPixelHeight] as? NSNumber)?.doubleValue ?? 0
        return max(width, height)
    }

    private func editorImage(
        from imageSource: CGImageSource,
        maxPixelSize: CGFloat
    ) -> UIImage? {
        guard let cgImage = editorCGImage(
            from: imageSource,
            at: 0,
            maxPixelSize: maxPixelSize
        ) else {
            return nil
        }
        return UIImage(cgImage: cgImage)
    }

    private func editorImageSourceIdentifier(
        for imageSource: CGImageSource
    ) -> String? {
        (CGImageSourceGetType(imageSource) as String?)?.lowercased()
    }

    private func editorImageSourceIsGIF(
        _ imageSource: CGImageSource
    ) -> Bool {
        editorImageSourceIdentifier(for: imageSource)?.contains("gif") == true
    }

    private func editorImageSourceIsHEIC(
        _ imageSource: CGImageSource
    ) -> Bool {
        guard let identifier = editorImageSourceIdentifier(for: imageSource) else {
            return false
        }
        return identifier.contains("heic") || identifier.contains("heif")
    }

    private func editorImageSourceIsJPEG(
        _ imageSource: CGImageSource
    ) -> Bool {
        guard let identifier = editorImageSourceIdentifier(for: imageSource) else {
            return false
        }
        return identifier.contains("jpeg") || identifier.contains("jpg")
    }

    private func editorCGImage(
        from imageSource: CGImageSource,
        at index: Int,
        maxPixelSize: CGFloat
    ) -> CGImage? {
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceShouldCacheImmediately: false,
            kCGImageSourceThumbnailMaxPixelSize: max(1, Int(ceil(maxPixelSize)))
        ]
        return CGImageSourceCreateThumbnailAtIndex(
            imageSource,
            index,
            options as CFDictionary
        )
    }

    private func compressedAnimatedEditorImageData(
        from imageSource: CGImageSource,
        maxPixelSize: CGFloat
    ) -> (image: UIImage, data: Data)? {
        let frameCount = CGImageSourceGetCount(imageSource)
        guard frameCount > 0 else {
            return nil
        }
        let data = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(
            data,
            editorGIFTypeIdentifier,
            frameCount,
            nil
        ) else {
            return nil
        }
        let gifProperty = [
            kCGImagePropertyGIFDictionary: [
                kCGImagePropertyGIFHasGlobalColorMap: true,
                kCGImagePropertyColorModel: kCGImagePropertyColorModelRGB,
                kCGImagePropertyDepth: 8,
                kCGImagePropertyGIFLoopCount: 0
            ] as [CFString: Any]
        ]
        CGImageDestinationSetProperties(destination, gifProperty as CFDictionary)
        var previewImage: UIImage?
        for index in 0..<frameCount {
            guard let cgImage = editorCGImage(
                from: imageSource,
                at: index,
                maxPixelSize: maxPixelSize
            ) else {
                return nil
            }
            if previewImage == nil {
                previewImage = UIImage(cgImage: cgImage)
            }
            let frameProperty = [
                kCGImagePropertyGIFDictionary: [
                    kCGImagePropertyGIFDelayTime: PhotoTools.getFrameDuration(
                        from: imageSource,
                        at: index
                    )
                ] as [CFString: Any]
            ]
            CGImageDestinationAddImage(
                destination,
                cgImage,
                frameProperty as CFDictionary
            )
        }
        guard let previewImage,
              CGImageDestinationFinalize(destination) else {
            return nil
        }
        return (previewImage, data as Data)
    }

    private var editorGIFTypeIdentifier: CFString {
        if #available(iOS 14.0, *) {
            return UTType.gif.identifier as CFString
        }
        return "com.compuserve.gif" as CFString
    }
    
    private func compressedEditorImageData(
        for image: UIImage,
        sourceIsHEIC: Bool,
        sourceIsJPEG: Bool
    ) -> Data? {
        let compressionQuality: CGFloat = 0.7
        let hasAlpha = editorImageHasAlpha(image)
        if let cgImage = image.cgImage ?? image.ci_Image?.cg_Image {
            if hasAlpha {
                if editorSupportsHEICEncoding,
                   let data = cgImage.heicData(quality: compressionQuality) {
                    return data
                }
                return image.pngData()
            }
            if sourceIsHEIC && editorSupportsHEICEncoding,
               let data = cgImage.heicData(quality: compressionQuality) {
                return data
            }
            if sourceIsJPEG || !sourceIsHEIC,
               let data = cgImage.jpegData(quality: compressionQuality) {
                return data
            }
            if editorSupportsHEICEncoding,
               let data = cgImage.heicData(quality: compressionQuality) {
                return data
            }
        }
        if hasAlpha {
            return image.pngData()
        }
        return image.jpegData(compressionQuality: compressionQuality)
    }

    private var editorSupportsHEICEncoding: Bool {
        let heicIdentifier: String
        if #available(iOS 14.0, *) {
            heicIdentifier = UTType.heic.identifier
        }else {
            heicIdentifier = "public.heic"
        }
        guard let identifiers = CGImageDestinationCopyTypeIdentifiers() as? [String] else {
            return false
        }
        return identifiers.contains(heicIdentifier)
    }

    private func editorImageData(
        contentsOf url: URL
    ) -> Data? {
        try? Data(contentsOf: url, options: .mappedIfSafe)
    }
    
    private func editorImageHasAlpha(
        _ image: UIImage
    ) -> Bool {
        guard let alphaInfo = image.cgImage?.alphaInfo else {
            return false
        }
        switch alphaInfo {
        case .premultipliedLast, .premultipliedFirst, .last, .first, .alphaOnly:
            return true
        default:
            return false
        }
    }
    
    func loadLastEditedData() {
        guard let result = selectedAsset.result else {
            filtersViewDidLoad()
            return
        }
        switch result {
        case .image(let editedResult, let editedData):
            loadFilterEditData(editedData.filterEdit)
            editorView.setAdjustmentData(editedResult.data)
        case .video(let editedResult, let editedData):
            if let music = editedData.music {
                loadMusicData(music, audioInfos: editedResult.data?.audioInfos ?? [])
            }
            loadFilterEditData(editedData.filterEdit)
            editorView.setAdjustmentData(editedResult.data)
            loadVideoCropTimeData(editedData.cropTime)
        }
        loadFilterData()
        if !firstAppear {
            editorView.layoutSubviews()
            checkLastResultState()
        }
        if config.video.isAutoPlay, selectedAsset.contentType == .video {
            DispatchQueue.main.async {
                self.videoControlView.resetLineViewFrsme(at: self.videoControlView.startTime)
                self.editorView.seekVideo(to: self.videoControlView.startTime)
                self.editorView.playVideo()
                if let musicURL = self.selectedMusicURL {
                    switch musicURL {
                    case .network(let url):
                        let key = url.absoluteString
                        let audioTmpURL = PhotoTools.getAudioTmpURL(for: key)
                        if PhotoTools.isCached(forAudio: key) {
                            self.musicPlayer?.play(audioTmpURL)
                            self.musicPlayer?.volume = self.musicVolume
                        }else {
                            self.lastMusicDownloadTask = PhotoManager.shared.downloadTask(
                                with: url,
                                toFile: audioTmpURL
                            ) { [weak self] audioURL, _, _ in
                                guard let self = self, let audioURL = audioURL else { return }
                                self.musicPlayer?.play(audioURL)
                                self.musicPlayer?.volume = self.musicVolume
                            }
                        }
                    default:
                        if let url = musicURL.url {
                            self.musicPlayer?.play(url)
                            self.musicPlayer?.volume = self.musicVolume
                        }
                    }
                }
                if self.isSelectedOriginalSound {
                    self.editorView.videoVolume = CGFloat(self.videoVolume)
                }else {
                    self.editorView.videoVolume = 0
                }
            }
        }
    }
    
    func loadMusicData(_ data: VideoEditedMusic, audioInfos: [EditorStickerAudio]) {
        isSelectedOriginalSound = data.hasOriginalSound
        videoVolume = data.videoSoundVolume
        volumeView.originalVolume = videoVolume
        musicView.originalSoundButton.isSelected = data.hasOriginalSound
        guard let url = data.backgroundMusicURL else {
            volumeView.hasMusic = false
            return
        }
        selectedMusicURL = data.backgroundMusicURL
        musicPlayer = .init()
        data.music?.parseLrc()
        musicPlayer?.music = data.music
        for audioInfo in audioInfos {
            var isSame: Bool = false
            if let musicIdentifier = data.musicIdentifier,
               audioInfo.identifier == musicIdentifier {
                isSame = true
            }
            if audioInfo.url == url || isSame {
                audioInfo.contentsHandler = { [weak self] in
                    guard let self = self,
                          let musicPlayer = self.musicPlayer,
                          let music = musicPlayer.music,
                          musicPlayer.audio == $0 else {
                        return nil
                    }
                    var texts: [EditorStickerAudioText] = []
                    for lyric in music.lyrics {
                        texts.append(.init(text: lyric.lyric, startTime: lyric.startTime, endTime: lyric.endTime))
                    }
                    return .init(time: music.time ?? 0, texts: texts)
                }
                musicPlayer?.audio = audioInfo
                musicView.showLyricButton.isSelected = true
                break
            }
        }
        volumeView.hasMusic = true
        musicView.backgroundButton.isSelected = true
        musicVolume = data.backgroundMusicVolume
        volumeView.musicVolume = musicVolume
    }
    
    func loadFilterEditData(_ data: EditorFilterEditFator?) {
        guard let data = data else {
            return
        }
        for model in filterEditView.models {
            let parameter = model.parameters.first
            switch model.type {
            case .brightness:
                parameter?.value = data.brightness / 0.5
            case .contrast:
                parameter?.value = data.contrast - 1
            case .exposure:
                parameter?.value = data.exposure / 5
            case .saturation:
                parameter?.value = data.saturation - 1
            case .highlights:
                parameter?.value = data.highlights
            case .shadows:
                parameter?.value = data.shadows
            case .warmth:
                parameter?.value = data.warmth
            case .vignette:
                parameter?.value = data.vignette / 2
            case .sharpen:
                parameter?.value = data.sharpen
            }
            if parameter?.value != 0 {
                parameter?.isNormal = false
            }else {
                parameter?.isNormal = true
            }
        }
        filterEditView.reloadData()
        filterEditView.scrollToValue()
        filterEditFator = data
    }
    
    func loadFilterData() {
        guard let result = selectedAsset.result else {
            return
        }
        switch result {
        case .image(_, let editedData):
            loadImageFilterData(editedData.filter)
        case .video(_, let editedData):
            loadVideoFilterData(editedData.filter)
        }
        filtersViewDidLoad()
    }
    
    private func loadImageFilterData(_ filter: PhotoEditorFilter?) {
        var filterInfo: PhotoEditorFilterInfo?
        var selectedIndex: Int = -1
        var selectedParameters: [PhotoEditorFilterParameterInfo] = []
        if let filter = filter {
            if filter.identifier == "hx_editor_default" {
                selectedIndex = filter.sourceIndex + 1
                selectedParameters = filter.parameters
                filterInfo = config.photo.filter.infos[filter.sourceIndex]
            }else {
                filterInfo = delegate?.editorViewcOntroller(self, fetchLastImageFilterInfo: filter)
            }
        }
        let originalImage = selectedOriginalImage
        if let filter = filter, let handler = filterInfo?.filterHandler {
            imageFilter = filter
            let lastImage = editorView.image
            imageFilterQueue.cancelAllOperations()
            let operation = BlockOperation()
            operation.addExecutionBlock { [unowned operation, weak self] in
                guard let self = self else { return }
                if operation.isCancelled { return }
                var ciImage = originalImage?.ci_Image
                if self.filterEditFator.isApply {
                    ciImage = ciImage?.apply(self.filterEditFator)
                }
                if let ciImage = ciImage,
                   let newImage = handler(ciImage, lastImage, filter.parameters, false),
                   let cgImage = self.imageFilterContext.createCGImage(newImage, from: newImage.extent) {
                    let image = UIImage(cgImage: cgImage)
                    if operation.isCancelled { return }
                    DispatchQueue.main.async {
                        self.editorView.updateImage(image)
                    }
                    if let mosaicImage = newImage.applyMosaic(level: self.config.mosaic.mosaicWidth) {
                        let mosaicResultImage = self.imageFilterContext.createCGImage(
                            mosaicImage,
                            from: mosaicImage.extent
                        )
                        if operation.isCancelled { return }
                        DispatchQueue.main.async {
                            self.editorView.mosaicCGImage = mosaicResultImage
                        }
                    }
                }
            }
            imageFilterQueue.addOperation(operation)
            if filtersView.didLoad {
                filtersView.updateFilters(selectedIndex: selectedIndex, selectedParameters: selectedParameters)
            }else {
                filtersView.loadCompletion = {
                    $0.updateFilters(selectedIndex: selectedIndex, selectedParameters: selectedParameters)
                }
            }
        }else {
            if filterEditFator.isApply {
                imageFilterQueue.cancelAllOperations()
                let operation = BlockOperation()
                operation.addExecutionBlock { [unowned operation, weak self] in
                    guard let self = self else { return }
                    if operation.isCancelled { return }
                    var ciImage = originalImage?.ci_Image
                    if self.filterEditFator.isApply {
                        ciImage = ciImage?.apply(self.filterEditFator)
                    }
                    if let ciImage = ciImage,
                       let cgImage = self.imageFilterContext.createCGImage(ciImage, from: ciImage.extent) {
                        let image = UIImage(cgImage: cgImage)
                        if operation.isCancelled { return }
                        DispatchQueue.main.async {
                            self.editorView.updateImage(image)
                        }
                        if let mosaicImage = ciImage.applyMosaic(level: self.config.mosaic.mosaicWidth) {
                            let mosaicResultImage = self.imageFilterContext.createCGImage(
                                mosaicImage,
                                from: mosaicImage.extent
                            )
                            if operation.isCancelled { return }
                            DispatchQueue.main.async {
                                self.editorView.mosaicCGImage = mosaicResultImage
                            }
                        }
                    }
                }
                imageFilterQueue.addOperation(operation)
                if filtersView.didLoad {
                    filtersView.updateFilters(selectedIndex: selectedIndex, selectedParameters: selectedParameters)
                }else {
                    filtersView.loadCompletion = {
                        $0.updateFilters(selectedIndex: selectedIndex, selectedParameters: selectedParameters)
                    }
                }
            }
        }
    }
    
    private func loadVideoFilterData(_ data: VideoEditorFilter?) {
        guard let data = data else {
            return
        }
        if data.identifier == "hx_editor_default" {
            videoFilterInfo = config.video.filter.infos[data.index]
            videoFilter = data
            if filtersView.didLoad {
                filtersView.updateFilters(
                    selectedIndex: data.index + 1,
                    selectedParameters: data.parameters,
                    isVideo: true
                )
            }else {
                filtersView.loadCompletion = {
                    $0.updateFilters(
                        selectedIndex: data.index + 1,
                        selectedParameters: data.parameters,
                        isVideo: true
                    )
                }
            }
        }else {
            if let filterInfo = delegate?.editorViewcOntroller(self, fetchLastVideoFilterInfo: data) {
                videoFilterInfo = filterInfo
                videoFilter = data
                if filtersView.didLoad {
                    filtersView.updateFilters(selectedIndex: -1, isVideo: true)
                }
            }
        }
    }
    
    func loadCorpSizeData() {
        guard let result = selectedAsset.result else {
            return
        }
        ratioToolView.layoutSubviews()
        rotateScaleView.layoutSubviews()
        func loadData(_ data: EditorCropSizeFator?, isRound: Bool) {
            guard let data = data else {
                return
            }
            ratioToolView.deselected()
            finishRatioIndex = -1
            for (index, aspectRatio) in config.cropSize.aspectRatios.enumerated() {
                if data.isFixedRatio {
                    if aspectRatio.ratio.equalTo(.init(width: -1, height: -1)) || aspectRatio.ratio.equalTo(.zero) {
                        continue
                    }
                    let scale1 = CGFloat(Int(aspectRatio.ratio.width / aspectRatio.ratio.height * 1000)) / 1000
                    let scale2 = CGFloat(Int(data.aspectRatio.width / data.aspectRatio.height * 1000)) / 1000
                    if scale1 == scale2, !isRound {
                        finishRatioIndex = index
                        break
                    }
                }else {
                    if aspectRatio.ratio.equalTo(.zero) {
                        finishRatioIndex = index
                        break
                    }
                }
            }
            DispatchQueue.main.async {
                self.ratioToolView.scrollToIndex(at: self.finishRatioIndex, animated: false)
            }
            if data.angle != 0 {
                finishScaleAngle = data.angle
                lastScaleAngle = data.angle
                rotateScaleView.updateAngle(data.angle)
            }
        }
        DispatchQueue.main.async {
            switch result {
            case .image(let editedResult, let editedData):
                loadData(
                    editedData.cropSize,
                    isRound: editedResult.data?.content.adjustedFactor?.isRoundMask ?? false
                )
            case .video(let editedResult, let editedData):
                loadData(
                    editedData.cropSize,
                    isRound: editedResult.data?.content.adjustedFactor?.isRoundMask ?? false
                )
            }
        }
    }
    
    func loadVideoCropTimeData(_ data: EditorVideoCropTime?) {
        guard let data = data else {
            return
        }
        videoControlInfo = data.controlInfo
        if !firstAppear {
            updateVideoControlInfo()
        }
        controlViewStartEndTime(at: .init(seconds: data.startTime, preferredTimescale: data.preferredTimescale))
        if !firstAppear {
            DispatchQueue.main.async {
                self.updateVideoTimeRange()
            }
        }
    }
    
    func loadVideoControl() {
        let asset = selectedAsset
        switch asset.type {
        case .video(let videoURL):
            videoControlView.layoutSubviews()
            videoControlView.loadData(.init(url: videoURL))
            updateVideoTimeRange()
            isLoadVideoControl = true
        case .networkVideo:
            if let avAsset = editorView.avAsset {
                videoControlView.layoutSubviews()
                videoControlView.loadData(avAsset)
                updateVideoTimeRange()
                isLoadVideoControl = true
            }
        #if HXPICKER_ENABLE_PICKER
        case .photoAsset:
            if let avAsset = editorView.avAsset {
                videoControlView.layoutSubviews()
                videoControlView.loadData(avAsset)
                updateVideoTimeRange()
                isLoadVideoControl = true
            }
        #endif
        default:
            break
        }
    }
    
    func downloadNetworkVideo(_ videoURL: URL) {
        let key = videoURL.absoluteString
        if PhotoTools.isCached(forVideo: key) {
            let localURL = PhotoTools.getVideoCacheURL(for: key)
            if !isTransitionCompletion {
                loadAssetStatus = .succeed(.video(localURL))
                return
            }
            let avAsset = AVAsset(url: localURL)
            let image = avAsset.getImage(at: 0.1)
            editorView.setAVAsset(avAsset, coverImage: image)
            editorView.loadVideo(isPlay: false)
            loadCompletion()
            loadLastEditedData()
            return
        }
        if isTransitionCompletion {
            assetLoadingView = PhotoManager.HUDView.show(with: .textManager.editor.videoLoadTitle.text, delay: 0, animated: true, addedTo: view)
            bringViews()
        }else {
            loadAssetStatus = .loadding(true)
        }
        PhotoManager.shared.downloadTask(
            with: videoURL
        ) { [weak self] (progress, _) in
            if progress > 0 {
                self?.assetLoadingView?.setProgress(.init(progress))
            }
        } completionHandler: { [weak self] (url, error, _) in
            guard let self = self else {
                return
            }
            if let url = url {
                if !self.isTransitionCompletion {
                    self.loadAssetStatus = .succeed(.video(url))
                    return
                }
                #if HXPICKER_ENABLE_PICKER
                if let photoAsset = self.selectedAsset.type.photoAsset {
                    photoAsset.networkVideoAsset?.fileSize = url.fileSize
                }
                #endif
                self.assetLoadingView = nil
                PhotoManager.HUDView.dismiss(delay: 0, animated: false, for: self.view)
                let avAsset = AVAsset(url: url)
                let image = avAsset.getImage(at: 0.1)
                self.editorView.setAVAsset(avAsset, coverImage: image)
                self.editorView.loadVideo(isPlay: false)
                self.loadCompletion()
                self.loadLastEditedData()
            }else {
                if let error = error as NSError?, error.code == NSURLErrorCancelled {
                    return
                }
                if !self.isTransitionCompletion {
                    self.loadAssetStatus = .failure
                    return
                }
                self.assetLoadingView = nil
                PhotoManager.HUDView.dismiss(delay: 0, animated: false, for: self.view)
                self.loadFailure()
            }
        }
    }
    
    func downloadNetworkImage(_ url: URL) {
        if isTransitionCompletion {
            assetLoadingView = PhotoManager.HUDView.show(with: nil, delay: 0, animated: true, addedTo: view)
        }else {
            loadAssetStatus = .loadding(true)
        }
        PhotoManager.ImageView.download(with: .init(downloadURL: url), options: nil) { [weak self] progress in
            if progress > 0 {
                self?.assetLoadingView?.setText(.textManager.editor.photoLoadTitle.text)
                self?.assetLoadingView?.setProgress(.init(progress))
            }
        } completionHandler: { [weak self] in
            guard let self = self else { return }
            self.assetLoadingView = nil
            switch $0 {
            case .success(let result):
                if !self.isTransitionCompletion {
                    if let imageData = result.imageData {
                        self.loadAssetStatus = .succeed(.imageData(imageData))
                    }else if let image = result.image {
                        self.loadAssetStatus = .succeed(.image(image))
                    }
                    return
                }
                let viewSize = UIDevice.screenSize
                if let imageData = result.imageData {
                    self.loadImageDataForEditing(
                        imageData,
                        viewSize: viewSize,
                        dismissLoadingView: true
                    )
                }else if let image = result.image {
                    self.loadImageForEditing(
                        image,
                        viewSize: viewSize,
                        dismissLoadingView: true
                    )
                }else {
                    PhotoManager.HUDView.dismiss(delay: 0, animated: true, for: self.view)
                    self.loadFailure(message: .textManager.editor.photoLoadFailedAlertMessage.text)
                }
            case .failure:
                if !self.isTransitionCompletion {
                    self.loadAssetStatus = .failure
                    return
                }
                self.loadFailure(message: .textManager.editor.photoLoadFailedAlertMessage.text)
            }
        }
    }
    
    #if HXPICKER_ENABLE_PICKER
    func loadPhotoAsset(_ photoAsset: PhotoAsset) {
        if photoAsset.mediaType == .photo {
            if photoAsset.isLocalAsset {
                if let localLivePhoto = photoAsset.localLivePhoto,
                   !localLivePhoto.imageURL.isFileURL {
                    requestNetworkAsset()
                    return
                }
                requestLocalAsset()
            }else if photoAsset.isNetworkAsset {
                requestNetworkAsset()
            } else {
                if photoAsset.phAsset != nil && !photoAsset.isGifAsset {
                    requestAssetImage()
                    return
                }
                requestAssetURL()
            }
        }else {
            requestAVAsset()
        }
    }
    
    func requestLocalAsset() {
        guard let photoAsset = selectedAsset.type.photoAsset else {
            return
        }
        if isTransitionCompletion {
            PhotoManager.HUDView.show(with: nil, delay: 0, animated: true, addedTo: view)
        }
        let viewSize = UIDevice.screenSize
        DispatchQueue.global().async {
            if photoAsset.mediaType == .photo {
                let imageURL = photoAsset.localImageAsset?.imageURL
                    ?? (photoAsset.localLivePhoto?.imageURL.isFileURL == true ? photoAsset.localLivePhoto?.imageURL : nil)
                let imageData = photoAsset.localImageAsset?.imageData
                    ?? (photoAsset.mediaSubType.isGif ? imageURL.flatMap { self.editorImageData(contentsOf: $0) } : nil)
                let image = imageData == nil && imageURL == nil
                    ? photoAsset.localImageAsset?.image?.normalizedImage()
                    : nil
                DispatchQueue.main.async {
                    if let imageData {
                        if !self.isTransitionCompletion {
                            self.loadAssetStatus = .succeed(.imageData(imageData))
                            return
                        }
                        self.loadImageDataForEditing(
                            imageData,
                            viewSize: viewSize,
                            dismissLoadingView: true
                        )
                    }else if let imageURL {
                        if !self.isTransitionCompletion {
                            self.loadAssetStatus = .imageURL(imageURL)
                            return
                        }
                        self.loadImageURLForEditing(
                            imageURL,
                            viewSize: viewSize,
                            dismissLoadingView: true
                        )
                    }else if let image {
                        if !self.isTransitionCompletion {
                            self.loadAssetStatus = .succeed(.image(image))
                            return
                        }
                        self.loadImageForEditing(
                            image,
                            viewSize: viewSize,
                            dismissLoadingView: true
                        )
                    }else {
                        if !self.isTransitionCompletion {
                            self.loadAssetStatus = .failure
                            return
                        }
                        PhotoManager.HUDView.dismiss(delay: 0, animated: true, for: self.view)
                        self.loadFailure(message: .textManager.editor.photoLoadFailedAlertMessage.text)
                    }
                }
            }else {
                let image = photoAsset.localVideoAsset?.image
                DispatchQueue.main.async {
                    if !self.isTransitionCompletion {
                        self.loadAssetStatus = .succeed(.image(image!))
                        return
                    }
                    self.editorView.setImage(image)
                    self.loadCompletion()
                    self.loadLastEditedData()
                    let viewSize = UIDevice.screenSize
                    DispatchQueue.global().async {
                        self.loadThumbnailImage(image, viewSize: viewSize)
                    }
                    PhotoManager.HUDView.dismiss(delay: 0, animated: true, for: self.view)
                }
            }
        }
    }
    func requestNetworkAsset() {
        guard let photoAsset = selectedAsset.type.photoAsset else {
            return
        }
        if isTransitionCompletion {
            assetLoadingView = PhotoManager.HUDView.show(with: nil, delay: 0, animated: true, addedTo: view)
        }else {
            loadAssetStatus = .loadding(true)
        }
        photoAsset.getNetworkImage(urlType: .original, filterEditor: true) { [weak self] progress in
            if progress > 0 {
                self?.assetLoadingView?.setText(.textManager.editor.photoLoadTitle.text)
                self?.assetLoadingView?.setProgress(progress)
            }
        } resultHandler: { [weak self] image, imageData in
            guard let self = self else { return }
            self.assetLoadingView = nil
            if image != nil || imageData != nil {
                if !self.isTransitionCompletion {
                    if let imageData {
                        self.loadAssetStatus = .succeed(.imageData(imageData))
                    }else if let image {
                        self.loadAssetStatus = .succeed(.image(image))
                    }
                    return
                }
                let viewSize = UIDevice.screenSize
                if let imageData {
                    self.loadImageDataForEditing(
                        imageData,
                        viewSize: viewSize,
                        dismissLoadingView: true
                    )
                }else if let image {
                    self.loadImageForEditing(
                        image,
                        viewSize: viewSize,
                        dismissLoadingView: true
                    )
                }
            }else {
                if !self.isTransitionCompletion {
                    self.loadAssetStatus = .failure
                    return
                }
                PhotoManager.HUDView.dismiss(delay: 0, animated: true, for: self.view)
                self.loadFailure(message: .textManager.editor.photoLoadFailedAlertMessage.text)
            }
        }
    }
    
    func requestAssetImage() {
        guard let photoAsset = selectedAsset.type.photoAsset else {
            return
        }
        if isTransitionCompletion {
            assetLoadingView = PhotoManager.HUDView.show(with: nil, delay: 0, animated: true, addedTo: view)
            bringViews()
        }else {
            loadAssetStatus = .loadding(true)
        }
        assetRequestID = photoAsset.requestImageData(
            filterEditor: true,
            iCloudHandler: { [weak self] _, requestID in
                self?.assetRequestID = requestID
                self?.assetLoadingView?.setText(.textManager.editor.iCloudSyncHudTitle.text + "...")
            },
            progressHandler: { [weak self] _, progress in
                if progress > 0 {
                    DispatchQueue.main.async {
                        self?.assetLoadingView?.setProgress(CGFloat(progress))
                    }
                }
            },
            resultHandler: { [weak self] asset, result in
                guard let self else { return }
                self.assetLoadingView = nil
                DispatchQueue.main.async {
                    switch result {
                    case .success(let dataResult):
                        if AssetManager.assetDownloadFinined(for: dataResult.info) || AssetManager.assetCancelDownload(for: dataResult.info) {
                            if !self.isTransitionCompletion {
                                self.loadAssetStatus = .succeed(.imageData(dataResult.imageData))
                                return
                            }
                            let viewSize = UIDevice.screenSize
                            self.loadImageDataForEditing(
                                dataResult.imageData,
                                viewSize: viewSize,
                                dismissLoadingView: true
                            )
                        }
                    case .failure(let error):
                        if !self.isTransitionCompletion {
                            self.loadAssetStatus = .failure
                            return
                        }
                        PhotoManager.HUDView.dismiss(delay: 0, animated: true, for: self.view)
                        if let inICloud = error.info?.inICloud {
                            self.loadFailure(message: inICloud ? .textManager.editor.iCloudSyncFailedAlertMessage.text : .textManager.editor.photoLoadFailedAlertMessage.text)
                        }else {
                            self.loadFailure(message: .textManager.editor.photoLoadFailedAlertMessage.text)
                        }
                        return
                    }
                }
            }
        )
    }
    
    func requestAssetURL() {
        guard let photoAsset = selectedAsset.type.photoAsset else {
            return
        }
        if isTransitionCompletion {
            PhotoManager.HUDView.show(with: nil, delay: 0, animated: true, addedTo: view)
            bringViews()
        }else {
            loadAssetStatus = .loadding(true)
        }
        photoAsset.requestAssetImageURL(
            filterEditor: true
        ) { [weak self] result in
            guard let self = self else { return }
            let viewSize = UIDevice.screenSize
            switch result {
            case .success(let response):
                let imageURL = response.url
                DispatchQueue.main.async {
                    if !self.isTransitionCompletion {
                        self.loadAssetStatus = .imageURL(imageURL)
                        return
                    }
                    self.loadImageURLForEditing(
                        imageURL,
                        viewSize: viewSize,
                        dismissLoadingView: true
                    )
                }
            case .failure:
                if !self.isTransitionCompletion {
                    self.loadAssetStatus = .failure
                    return
                }
                PhotoManager.HUDView.dismiss(delay: 0, animated: true, for: self.view)
                self.loadFailure(message: .textManager.editor.photoLoadFailedAlertMessage.text)
            }
        }
    }
    func requestAVAsset() {
        guard let photoAsset = selectedAsset.type.photoAsset else {
            return
        }
        if photoAsset.isNetworkAsset {
            if let url = photoAsset.networkVideoAsset?.videoURL {
                downloadNetworkVideo(url)
            }
            return
        }
        if isTransitionCompletion {
            assetLoadingView = PhotoManager.HUDView.show(with: nil, delay: 0, animated: true, addedTo: view)
            bringViews()
        }else {
            loadAssetStatus = .loadding(true)
        }
        assetRequestID = photoAsset.requestAVAsset(
            filterEditor: true,
            deliveryMode: .highQualityFormat
        ) { [weak self] (_, requestID) in
            self?.assetRequestID = requestID
            self?.assetLoadingView?.setText(.textManager.editor.iCloudSyncHudTitle.text + "...")
        } progressHandler: { [weak self] (_, progress) in
            if progress > 0 {
                self?.assetLoadingView?.setProgress(CGFloat(progress))
            }
        } success: { [weak self] _, avAsset, _ in
            guard let self = self else { return }
            self.assetLoadingView = nil
            if !self.isTransitionCompletion {
                self.loadAssetStatus = .succeed(.videoAsset(avAsset))
                return
            }
            PhotoManager.HUDView.dismiss(delay: 0, animated: false, for: self.view)
            let image = avAsset.getImage(at: 0.1)
            self.editorView.setAVAsset(avAsset, coverImage: image)
            self.editorView.loadVideo(isPlay: false)
            self.loadCompletion()
            self.loadLastEditedData()
        } failure: { [weak self] (_, info, _) in
            guard let self = self else { return }
            self.assetLoadingView = nil
            if !self.isTransitionCompletion {
                self.loadAssetStatus = .failure
                return
            }
            PhotoManager.HUDView.dismiss(delay: 0, animated: false, for: self.view)
            guard let info = info else {
                self.loadFailure(message: .textManager.editor.videoLoadFailedAlertMessage.text)
                return
            }
            self.loadFailure(message: info.inICloud ? .textManager.editor.iCloudSyncFailedAlertMessage.text : .textManager.editor.videoLoadFailedAlertMessage.text)
        }
    }
    #endif
    
    func bringViews() {
        view.bringSubviewToFront(cancelButton)
        view.bringSubviewToFront(finishButton)
        view.bringSubviewToFront(filterParameterView)
    }
    
    func loadThumbnailImage(_ image: UIImage?, viewSize: CGSize) {
        guard let image = image else {
            selectedThumbnailImage = selectedOriginalImage
            return
        }
        var maxSize: CGFloat = max(viewSize.width, viewSize.height)
        DispatchQueue.main.sync {
            if !view.size.equalTo(.zero) {
                maxSize = min(view.width, view.height) * 2
            }
        }
        let maxLength = max(image.width, image.height)
        if maxLength > maxSize {
            let thumbnailScale = maxSize / maxLength
            let _image = image.scaleImage(toScale: max(thumbnailScale, config.photo.filterScale))
            selectedThumbnailImage = _image
            if imageFilter == nil && !filterEditFator.isApply {
                if let img = _image?.ci_Image?.applyMosaic(level: self.config.mosaic.mosaicWidth),
                   let mosaicImage = self.imageFilterContext.createCGImage(img, from: img.extent) {
                    selectedMosaicImage = mosaicImage
                    DispatchQueue.main.async {
                        self.editorView.mosaicCGImage = mosaicImage
                    }
                }
            }
        }else {
            if imageFilter == nil && !filterEditFator.isApply {
                if let img = image.ci_Image?.applyMosaic(level: self.config.mosaic.mosaicWidth),
                   let mosaicImage = self.imageFilterContext.createCGImage(img, from: img.extent) {
                    selectedMosaicImage = mosaicImage
                    DispatchQueue.main.async {
                        self.editorView.mosaicCGImage = mosaicImage
                    }
                }
            }
        }
        if selectedThumbnailImage == nil {
            selectedThumbnailImage = image
        }
    }
    
    func filtersViewDidLoad() {
        if editorView.type == .image {
            if let image = editorView.image {
                filtersView.loadFilters(originalImage: image, selectedIndex: imageFilter != nil ? -1 : 0)
            }
        }else if editorView.type == .video {
            if let avAsset = editorView.avAsset {
                avAsset.getImage(at: 0.1) { [weak self] _, image, _ in
                    guard let self = self,
                          let image = image else {
                        return
                    }
                    let selectedIndex: Int
                    if self.videoFilter != nil {
                        selectedIndex = -1
                    }else {
                        selectedIndex = 0
                    }
                    self.filtersView.loadFilters(
                        originalImage: image,
                        selectedIndex: selectedIndex,
                        isVideo: true
                    )
                }
            }
        }
    }
    
    func loadCompletion() {
        isLoadCompletion = true
        if !isLoadVideoControl && !firstAppear {
            loadVideoControl()
        }
        if editorView.type == .image {
            selectedOriginalImage = editorView.image
        }else if editorView.type == .video {
            selectedOriginalImage = nil
        }
        if !firstAppear {
            selectedDefaultTool()
        }
    }
    
    func checkLastResultState() {
        resetButton.isEnabled = isReset
        brushColorView.canUndo = editorView.isCanUndoDraw
        mosaicToolView.canUndo = editorView.isCanUndoMosaic
        checkFinishButtonState()
    }
    
    func selectedDefaultTool() {
        if config.isFixedCropSizeState {
            UIView.animate {
                self.showTools(true)
            }
            toolsView.selectedOptionType(.cropSize)
            return
        }
        if selectedAsset.contentType == .image {
            if let optionType = config.photo.defaultSelectedToolOption {
                UIView.animate {
                    self.showTools(optionType == .cropSize)
                }
                toolsView.selectedOptionType(optionType)
            }
        }else if selectedAsset.contentType == .video {
            if let optionType = config.video.defaultSelectedToolOption {
                UIView.animate {
                    self.showTools(optionType == .cropSize)
                }
                toolsView.selectedOptionType(optionType)
            }
        }
    }
    
    func loadFailure(message: String = .textManager.editor.videoLoadFailedAlertMessage.text) {
        if isDismissed {
            return
        }
        PhotoTools.showConfirm(
            viewController: self,
            title: .textManager.editor.loadFailedAlertTitle.text,
            message: message,
            actionTitle: .textManager.editor.loadFailedAlertDoneTitle.text
        ) { [weak self] _ in
            self?.backClick(true)
        }
    }
}
