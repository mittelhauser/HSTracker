/*
 * This file is part of the HSTracker package.
 * (c) Benjamin Michotte <bmichotte@gmail.com>
 *
 * For the full copyright and license information, please view the LICENSE
 * file that was distributed with this source code.
 *
 * Created on 15/02/16.
 */

import Cocoa
import CleanroomLogger
import TextAttributes

protocol CardCellHover {
    func hover(cell: CardCellView, card: Card)

    func out(card: Card)
}

class CardCellView: TrackerFrame {

    private let frameCountBoxRect = NSRect(x: 183, y: 0, width: 34, height: 34)
    private let frameCounterRect = NSRect(x: 195, y: 7, width: 18, height: 21)
    private let frameRect = NSRect(x: 0, y: 0, width: CGFloat(kFrameWidth), height: 34)
    private let gemRect = NSRect(x: 0, y: 0, width: 34, height: 34)
    private let imageRect = NSRect(x: 108, y: 4, width: 108, height: 27)
    private let fadeRect = NSRect(x: 28, y: 0, width: 189, height: 34)
    private let iconRect = NSRect(x: 183, y: 0, width: 34, height: 34)
    private let markerRect = NSRect(x: 192, y: 8, width: 21, height: 21)

    private var trackingArea: NSTrackingArea?
    var delegate: CardCellHover?
    var card: Card?

    private var flashLayer: CALayer?
    private var cardLayer: CALayer?

    override var ratioHeight: CGFloat {
        if let playerType = playerType where playerType == .DeckManager {
            return super.ratioHeight
        }

        let baseHeight: CGFloat
        switch Settings.instance.cardSize {
        case .Small: baseHeight = CGFloat(kSmallRowHeight)
        case .Medium: baseHeight = CGFloat(kMediumRowHeight)
        default: baseHeight = CGFloat(kRowHeight)
        }

        if baseHeight > NSHeight(self.bounds) {
            return CGFloat(kRowHeight) / NSHeight(self.bounds)
        }
        return super.ratioHeight
    }

    func update(highlight: Bool) {
        if highlight {
            let flashingLayer = CALayer()
            flashingLayer.frame = ratio(frameRect)
            flashingLayer.backgroundColor = NSColor(red: 1, green: 0.647, blue: 0, alpha: 1).CGColor

            let maskLayer = CALayer()
            maskLayer.frame = ratio(frameRect)
            maskLayer.contents = ImageCache.asset("frame_mask")
            flashingLayer.mask = maskLayer

            flashLayer?.addSublayer(flashingLayer)
            let fade = CABasicAnimation(keyPath: "opacity")
            fade.fromValue = 0.7
            fade.toValue = 0.0
            fade.duration = 0.5
            fade.removedOnCompletion = false
            fade.fillMode = kCAFillModeBoth
            flashingLayer.addAnimation(fade, forKey: "alpha")
        }
    }

    func fadeIn(fadeIn: Bool) {
    }

    func fadeOut(highlight: Bool) {
    }

    override func drawRect(dirtyRect: NSRect) {
        super.drawRect(dirtyRect)
        if cardLayer == nil {
            cardLayer = CALayer()
            cardLayer?.frame = self.bounds
            layer?.addSublayer(cardLayer!)
        }

        if flashLayer == nil {
            flashLayer = CALayer()
            cardLayer?.frame = self.bounds
            layer?.addSublayer(flashLayer!)
        }

        if let cardLayer = cardLayer {
            cardLayer.sublayers?.forEach({ $0.removeFromSuperlayer() })
        }

        guard let card = self.card else {return}

        addCardImage(card)
        addCardName(card)
        addFrame(card)

        addGem(card)

        if abs(card.count) > 1 || card.rarity == Rarity.Legendary {
            addFrameCounter(card)
        }
        addCardCost(card)

        if (card.count <= 0 || card.jousted) && playerType != .CardList {
            addDarken(card)
        }
    }

    private func addCardName(card: Card) {
        var foreground = NSColor.whiteColor()
        if self.playerType == .Player {
            foreground = card.textColor()
        }
        let attributes = TextAttributes()
            .font(NSFont(name: "Belwe Bd BT", size: round(16 / ratioHeight)))
            .foregroundColor(foreground)
            .strokeColor(NSColor.blackColor())
            .strokeWidth(-1)

        NSAttributedString(string: card.name, attributes: attributes)
            .drawInRect(ratio(NSRect(x: 38, y: 2, width: 174, height: 30)))
    }

    private func addCardCost(card: Card) {
        var foreground = NSColor.whiteColor()
        if self.playerType == .Player {
            foreground = card.textColor()
        }
        let attributes = TextAttributes()
            .font(NSFont(name: "Belwe Bd BT", size: round(24 / ratioHeight)))
            .foregroundColor(foreground)
            .strokeColor(NSColor.blackColor())
            .strokeWidth(-1)
        NSAttributedString(string: "\(card.cost)", attributes: attributes)
            .drawInRect(ratio(NSRect(x: card.cost > 9 ? 5.0 : 13.0, y: 3, width: 34, height: 37)))
    }

    private func addDarken(card: Card) {
        ImageCache.darkenImage()?.drawInRect(ratio(frameRect))
        if card.highlightFrame {
            addImage(ImageCache.frameImage(.Golden), rect: frameRect)
            addImage(ImageCache.gemImage(.Legendary), rect: gemRect)
            addCardCost(card)
        }
    }

    private func addFrameCounter(card: Card) {
        if playerType == .CardList {
            if card.rarity == Rarity.Legendary {
                if Settings.instance.showRarityColors {
                    addImage(ImageCache.frameCountbox(card.rarity), rect: frameCountBoxRect)
                } else {
                    addImage(ImageCache.frameCountbox(nil), rect: frameCountBoxRect)
                }
                addImage(ImageCache.frameLegendary(), rect: frameCountBoxRect)
            }
        } else {
            if Settings.instance.showRarityColors {
                addImage(ImageCache.frameCountbox(card.rarity), rect: frameCountBoxRect)
            } else {
                addImage(ImageCache.frameCountbox(nil), rect: frameCountBoxRect)
            }

            let count = abs(card.count)
            if count <= 1 && card.rarity == Rarity.Legendary {
                addImage(ImageCache.frameLegendary(), rect: frameCountBoxRect)
            } else {
                let countText = count > 9 ? "9" : "\(count)"
                addCountText(countText, size: 20, x: 198, y: -1)
                if count > 9 {
                    addCountText("+", size: 13, x: 202, y: -1)
                }
            }
        }
    }

    func addCountText(text: String, size: CGFloat, x: CGFloat, y: CGFloat) {
        let foreground = NSColor(red: 240.0 / 255.0,
                                 green: 195.0 / 255.0,
                                 blue: 72.0 / 255.0,
                                 alpha: 1.0)
        let attributes = TextAttributes()
            .font(NSFont(name: "Belwe Bd BT", size: round(size / ratioHeight)))
            .foregroundColor(foreground)
            .strokeColor(NSColor.blackColor())
            .strokeWidth(-2)

        NSAttributedString(string: text, attributes: attributes)
            .drawInRect(ratio(NSRect(x: x, y: y, width: 30, height: 37)))
    }

    private func addGem(card: Card) {
        if card.highlightFrame {
            addImage(ImageCache.gemImage(.Legendary), rect: gemRect)
        } else if Settings.instance.showRarityColors {
            addImage(ImageCache.gemImage(card.rarity), rect: gemRect)
        } else {
            addImage(ImageCache.gemImage(nil), rect: gemRect)
        }
    }

    private func addCardImage(card: Card) {
        let xOffset: CGFloat
        if playerType == .CardList {
            xOffset = card.rarity == .Legendary ? 19 : 0
        } else {
            xOffset = abs(card.count) > 1 || card.rarity == .Legendary ? 19 : 0
        }
        addImage(ImageCache.smallCardImage(card), rect: imageRect.offsetBy(dx: -xOffset, dy: 0))
        addImage(ImageCache.fadeImage(), rect: fadeRect.offsetBy(dx: -xOffset, dy: 0))
    }

    private func addFrame(card: Card) {
        var frame = ImageCache.frameImage(nil)
        if card.highlightFrame {
            frame = ImageCache.frameImage(.Golden)
        } else {
            if Settings.instance.showRarityColors {
                frame = ImageCache.frameImage(card.rarity)
            }
        }
        addImage(frame, rect: frameRect)
    }

    // MARK: - CardCellHover
    func setDelegate(delegate: CardCellHover) {
        self.delegate = delegate
    }

    // MARK: - mouse hover
    func ensureTrackingArea() {
        if trackingArea == nil {
            trackingArea = NSTrackingArea(rect: NSZeroRect,
                                          options: [NSTrackingAreaOptions.InVisibleRect,
                                            NSTrackingAreaOptions.ActiveAlways,
                                            NSTrackingAreaOptions.MouseEnteredAndExited],
                owner: self,
                userInfo: nil)
        }
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()

        ensureTrackingArea()

        if !self.trackingAreas.contains(trackingArea!) {
            self.addTrackingArea(trackingArea!)
        }
    }

    override func mouseEntered(event: NSEvent) {
        if let card = self.card {
            delegate?.hover(self, card: card)
        }
    }

    override func mouseExited(event: NSEvent) {
        if let card = self.card {
            delegate?.out(card)
        }
    }
}
