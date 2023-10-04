//
// Copyright (c) 2023 Marcel Müller <ivan@nextcloud.com>
//
// Author Ivan Sein <ivan@nextcloud.com>
// Author Marcel Müller <marcel.mueller@nextcloud.com>
//
// GNU GPL version 3 or any later version
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License
// along with this program.  If not, see <http://www.gnu.org/licenses/>.
//

import Foundation

@objc protocol NCZoomableViewDelegate {
    @objc func resizeContentViewToOriginalSize(_ view: NCZoomableView)
}

@objcMembers class NCZoomableView: UIView, UIGestureRecognizerDelegate {

    public weak var delegate: NCZoomableViewDelegate?

    var pinchGestureRecognizer: UIPinchGestureRecognizer?
    var panGestureRecognizer: UIPanGestureRecognizer?
    var doubleTapGestureRecoginzer: UITapGestureRecognizer?

    private(set) var contentView = UIView()
    var contentViewSize = CGSize()

    override init(frame: CGRect) {
        super.init(frame: frame)

        self.addSubview(self.contentView)
        self.initGestureRecognizers()
    }

    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)

        self.addSubview(self.contentView)
        self.initGestureRecognizers()
    }

    func initGestureRecognizers() {
        self.pinchGestureRecognizer = UIPinchGestureRecognizer(target: self, action: #selector(handlePinch(_:)))
        self.pinchGestureRecognizer?.delegate = self
        self.contentView.addGestureRecognizer(self.pinchGestureRecognizer!)

        self.panGestureRecognizer = UIPanGestureRecognizer(target: self, action: #selector(handlePan(_:)))
        self.panGestureRecognizer?.delegate = self
        self.contentView.addGestureRecognizer(self.panGestureRecognizer!)

        self.doubleTapGestureRecoginzer = UITapGestureRecognizer(target: self, action: #selector(handleDoubleTap(_:)))
        self.doubleTapGestureRecoginzer?.delegate = self
        self.doubleTapGestureRecoginzer?.numberOfTapsRequired = 2
        self.contentView.addGestureRecognizer(self.doubleTapGestureRecoginzer!)
    }

    public func replaceContentView(_ newView: UIView) {
        if let pinchGestureRecognizer = self.pinchGestureRecognizer {
            self.contentView.removeGestureRecognizer(pinchGestureRecognizer)
        }

        if let panGestureRecognizer = self.panGestureRecognizer {
            self.contentView.removeGestureRecognizer(panGestureRecognizer)
        }

        if let doubleTapGestureRecoginzer = self.doubleTapGestureRecoginzer {
            self.contentView.removeGestureRecognizer(doubleTapGestureRecoginzer)
        }

        self.contentView.removeFromSuperview()
        self.contentView = newView
        self.contentViewSize = newView.frame.size
        self.addSubview(self.contentView)

        self.initGestureRecognizers()
        self.resizeContentView()
    }

    func handlePinch(_ recognizer: UIPinchGestureRecognizer) {
        self.zoomView(view: self.contentView, toPoint: recognizer.location(in: recognizer.view), usingScale: recognizer.scale)
        recognizer.scale = 1

        if recognizer.state == .ended {
            let bounds = self.contentView.bounds
            let zoomedSize = recognizer.view!.frame.size

            let aspectRatioContentViewSize = AVMakeRect(aspectRatio: self.contentViewSize, insideRect: bounds).size

            // Don't zoom smaller than the original size
            if zoomedSize.width < aspectRatioContentViewSize.width || zoomedSize.height < aspectRatioContentViewSize.height {
                UIView.animate(withDuration: 0.3) {
                    self.resizeContentView()
                }
            } else {
                self.adjustViewPosition()
            }

        }
    }

    func handlePan(_ recognizer: UIPanGestureRecognizer) {
        let point = recognizer.translation(in: self.contentView)

        // We need to take the current scaling into account when panning
        // As we have the same scale factor for X and Y, we can take only one here
        let scaleFactor = self.contentView.transform.a

        self.contentView.center = CGPoint(x: self.contentView.center.x + point.x * scaleFactor, y: self.contentView.center.y + point.y * scaleFactor)
        recognizer.setTranslation(.zero, in: self.contentView)

        if recognizer.state == .ended {
            self.adjustViewPosition()
        }
    }

    func handleDoubleTap(_ recognizer: UITapGestureRecognizer) {
        if recognizer.state == .recognized {
            // We need to take the current scaling into account when panning
            // As we have the same scale factor for X and Y, we can take only one here
            let scaleFactor = self.contentView.transform.a

            UIView.animate(withDuration: 0.3) {
                if scaleFactor > 1 {
                    // Set screenView's original size
                    self.resizeContentView()
                } else {
                    // Zoom 3x screenView into the tap point
                    self.zoomView(view: recognizer.view!, toPoint: recognizer.location(in: recognizer.view!), usingScale: 3)
                }
            }

            self.adjustViewPosition()
        }
    }

    func zoomView(view: UIView, toPoint point: CGPoint, usingScale scale: CGFloat) {
        let bounds = view.bounds

        var resultPoint = point
        resultPoint.x -= bounds.midX
        resultPoint.y -= bounds.midY

        var transform = view.transform
        transform = CGAffineTransformTranslate(transform, resultPoint.x, resultPoint.y)
        transform = CGAffineTransformScale(transform, scale, scale)
        transform = CGAffineTransformTranslate(transform, -resultPoint.x, -resultPoint.y)
        view.transform = transform
    }

    func adjustViewPosition() {
        let parentSize = self.frame.size
        let size = self.contentView.frame.size
        var position = self.contentView.frame.origin

        let viewLeft = position.x
        let viewRight = position.x + size.width
        let viewTop = position.y
        let viewBottom = position.y + size.height

        // Left align screenView if it has been moved to the center (and it is wide enough)
        if viewLeft > 0, size.width >= parentSize.width {
            position = CGPoint(x: 0, y: position.y)
        }

        // Top align screenView if it has been moved to the center (and it is tall enough)
        if viewTop > 0, size.height >= parentSize.height {
            position = CGPoint(x: position.x, y: 0)
        }

        // Right align screenView if it has been moved to the center (and it is wide enough)
        if viewRight < parentSize.width, size.width >= parentSize.width {
            position = CGPoint(x: parentSize.width - size.width, y: position.y)
        }

        // Bottom align screenView if it has been moved to the center (and it is tall enough)
        if viewBottom < parentSize.height, size.height >= parentSize.height {
            position = CGPoint(x: position.x, y: parentSize.height - size.height)
        }

        // Align screenView vertically
        if size.width <= parentSize.width {
            position = CGPoint(x: parentSize.width / 2 - size.width / 2, y: position.y)
        }

        // Align screenView horizontally
        if size.height <= parentSize.height {
            position = CGPoint(x: position.x, y: parentSize.height / 2 - size.height / 2)
        }

        var frame = self.contentView.frame
        frame.origin.x = position.x
        frame.origin.y = position.y

        UIView.animate(withDuration: 0.3) {
            self.contentView.frame = frame
        }
    }

    public func resizeContentView() {
        self.contentView.transform = .identity

        let bounds = self.bounds
        let contentSize = self.contentViewSize

        if contentSize.width > 0, contentSize.height > 0 {
            let aspectFrame = AVMakeRect(aspectRatio: contentSize, insideRect: bounds)
            self.contentView.frame = aspectFrame
            self.contentView.center = CGPoint(x: bounds.midX, y: bounds.midY)
        } else {
            self.contentView.frame = bounds
        }
    }

    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        return true
    }
}
