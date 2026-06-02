import Foundation
import UserNotifications
import UIKit

enum NotificationBranding {
    private static let brandingVersion = "v4-brand-logo"

    static func alarmAttachment(wallpaperId: String? = nil, phase: Int = 0) -> UNNotificationAttachment? {
        let normalizedPhase = phase % 2
        let directory = cachedAssetsDirectory()
        let wallpaperKey = wallpaperCacheKey(wallpaperId)
        let fileURL = directory.appendingPathComponent("alarmo-ring-\(wallpaperKey)-\(normalizedPhase)-\(brandingVersion).png")

        if !FileManager.default.fileExists(atPath: fileURL.path) {
            guard let image = renderAlarmBannerImage(wallpaperId: wallpaperId, phase: normalizedPhase),
                  let data = image.pngData() else {
                return nil
            }
            do {
                try data.write(to: fileURL, options: .atomic)
            } catch {
                return nil
            }
        }

        return try? UNNotificationAttachment(
            identifier: "alarmo-branding-\(normalizedPhase)",
            url: fileURL
        )
    }

    private static func wallpaperCacheKey(_ wallpaperId: String?) -> String {
        guard let wallpaperId, !wallpaperId.isEmpty else { return "default" }
        let hash = abs(wallpaperId.hashValue)
        return "\(hash)"
    }

    private static func cachedAssetsDirectory() -> URL {
        let base = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
        let dir = base.appendingPathComponent("alarmo_notification_branding", isDirectory: true)
        if !FileManager.default.fileExists(atPath: dir.path) {
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        return dir
    }

    private static func renderAlarmBannerImage(wallpaperId: String?, phase: Int) -> UIImage? {
        let size = CGSize(width: 480, height: 240)
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { ctx in
            let cg = ctx.cgContext
            let rect = CGRect(origin: .zero, size: size)

            if let wallpaperId,
               let wallpaper = WallpaperImageResolver.resolveImage(for: wallpaperId) {
                drawAspectFill(image: wallpaper, in: rect)
            } else {
                let top = UIColor(red: 0.02, green: 0.07, blue: 0.18, alpha: 1.0).cgColor
                let bottom = UIColor(red: 0.00, green: 0.39, blue: 0.66, alpha: 1.0).cgColor
                let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: [top, bottom] as CFArray, locations: [0, 1])!
                cg.drawLinearGradient(gradient, start: CGPoint(x: 0, y: 0), end: CGPoint(x: size.width, y: size.height), options: [])
            }

            // Keep text and actions readable over any selected wallpaper.
            let darkOverlay = CGGradient(
                colorsSpace: CGColorSpaceCreateDeviceRGB(),
                colors: [
                    UIColor(white: 0, alpha: 0.55).cgColor,
                    UIColor(white: 0, alpha: 0.30).cgColor,
                    UIColor(white: 0, alpha: 0.70).cgColor
                ] as CFArray,
                locations: [0.0, 0.45, 1.0]
            )!
            cg.drawLinearGradient(darkOverlay, start: CGPoint(x: 0, y: 0), end: CGPoint(x: 0, y: size.height), options: [])

            let glowCenter = CGPoint(x: size.width * 0.76, y: size.height * 0.35)
            let glowGradient = CGGradient(
                colorsSpace: CGColorSpaceCreateDeviceRGB(),
                colors: [
                    UIColor(red: 0.24, green: 0.90, blue: 1.0, alpha: 0.45).cgColor,
                    UIColor(red: 0.24, green: 0.90, blue: 1.0, alpha: 0.0).cgColor
                ] as CFArray,
                locations: [0, 1]
            )!
            cg.drawRadialGradient(
                glowGradient,
                startCenter: glowCenter,
                startRadius: 8,
                endCenter: glowCenter,
                endRadius: 180,
                options: []
            )

            let badgeCenter = CGPoint(x: 110, y: 120)
            drawBrandLogoBadge(in: cg, center: badgeCenter, phase: phase)

            let titleAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 42, weight: .heavy),
                .foregroundColor: UIColor.white
            ]
            let subAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 23, weight: .semibold),
                .foregroundColor: UIColor(red: 0.61, green: 0.95, blue: 1.0, alpha: 1.0)
            ]

            NSString(string: "Alarmo Ringing").draw(at: CGPoint(x: 190, y: 72), withAttributes: titleAttrs)
            NSString(string: "Snooze or Stop from lock screen").draw(at: CGPoint(x: 190, y: 128), withAttributes: subAttrs)
        }
    }

    private static func drawAspectFill(image: UIImage, in rect: CGRect) {
        let imageSize = image.size
        guard imageSize.width > 0, imageSize.height > 0 else {
            image.draw(in: rect)
            return
        }

        let scale = max(rect.width / imageSize.width, rect.height / imageSize.height)
        let width = imageSize.width * scale
        let height = imageSize.height * scale
        let x = rect.midX - width / 2
        let y = rect.midY - height / 2
        image.draw(in: CGRect(x: x, y: y, width: width, height: height))
    }

    private static func drawBrandLogoBadge(in cg: CGContext, center: CGPoint, phase: Int) {
        cg.saveGState()
        cg.translateBy(x: center.x, y: center.y)
        let angle = phase == 0 ? -0.08 : 0.08
        cg.rotate(by: angle)

        let outer = UIBezierPath(ovalIn: CGRect(x: -58, y: -58, width: 116, height: 116))
        UIColor(red: 0.03, green: 0.14, blue: 0.30, alpha: 1.0).setFill()
        outer.fill()

        let inner = UIBezierPath(ovalIn: CGRect(x: -50, y: -50, width: 100, height: 100))
        UIColor(red: 0.07, green: 0.39, blue: 0.72, alpha: 1.0).setFill()
        inner.fill()

        let logoRect = CGRect(x: -42, y: -42, width: 84, height: 84)
        let logoPath = UIBezierPath(roundedRect: logoRect, cornerRadius: 18)
        logoPath.addClip()
        if let logo = brandLogoImage() {
            drawAspectFill(image: logo, in: logoRect)
        } else {
            UIColor(red: 0.98, green: 0.83, blue: 0.14, alpha: 1.0).setFill()
            logoPath.fill()
        }
        UIColor.white.withAlphaComponent(0.28).setStroke()
        logoPath.lineWidth = 2.0
        logoPath.stroke()

        cg.restoreGState()

        drawRingWave(in: cg, center: center, left: true, phase: phase)
        drawRingWave(in: cg, center: center, left: false, phase: phase)
    }

    private static func drawRingWave(in cg: CGContext, center: CGPoint, left: Bool, phase: Int) {
        let waveColor = UIColor(red: 0.34, green: 0.95, blue: 1.0, alpha: 0.98)
        waveColor.setStroke()
        let side: CGFloat = left ? -1 : 1
        let offset: CGFloat = phase == 0 ? 0 : 8

        let p1 = CGPoint(x: center.x + side * (62 + offset), y: center.y - 40)
        let p2 = CGPoint(x: center.x + side * (86 + offset), y: center.y - 18)
        let p3 = CGPoint(x: center.x + side * (98 + offset), y: center.y + 14)

        let path = UIBezierPath()
        path.move(to: p1)
        path.addCurve(to: p3, controlPoint1: CGPoint(x: p2.x, y: p1.y), controlPoint2: CGPoint(x: p2.x, y: p3.y))
        path.lineWidth = 8
        path.lineCapStyle = .round
        path.stroke()
    }

    private static func brandLogoImage() -> UIImage? {
        if let image = UIImage(named: "BrandLogo") {
            return image
        }
        if let image = UIImage(named: "AppIcon-1024") {
            return image
        }
        return nil
    }
}
