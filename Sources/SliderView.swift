//
//  SliderView.swift
//  UptechSlider
//
//  Created by Artem Mysik on 8/19/19.
//  Copyright © 2019 Uptech. All rights reserved.
//

import UIKit

protocol SliderViewDelegate: class {
    func sliderViewDidSelectRange(_ sliderView: SliderView, minIndex: Int, maxIndex: Int)
}

final class SliderView: UIView {

    // MARK: - Public Properties -

    weak var delegate: SliderViewDelegate?

    // MARK: - Private Properties -

    private var stackView: UIStackView!
    private var itemsViews = [ItemView]()
    fileprivate var rangeView = UIView(frame: CGRect(x: 0, y: 0, width: 0, height: 34))

    private var firstSelectionView = UIView(frame: CGRect(x: 0, y: 0, width: Constants.selectionViewMinWidth, height: Constants.selectionViewHeight))
    private var secondSelectionView = UIView(frame: CGRect(x: 1, y: 0, width: Constants.selectionViewMinWidth, height: Constants.selectionViewHeight))

    fileprivate var maxSelectionView: UIView {
        return firstSelectionView.center.x >= secondSelectionView.center.x ? firstSelectionView : secondSelectionView
    }

    fileprivate var minSelectionView: UIView {
        return maxSelectionView == firstSelectionView ? secondSelectionView : firstSelectionView
    }

    fileprivate var minSelectionViewPan = UIPanGestureRecognizer(target: nil, action: nil)
    fileprivate var maxSelectionViewPan = UIPanGestureRecognizer(target: nil, action: nil)
    fileprivate let minSelectionViewTap = UITapGestureRecognizer(target: nil, action: nil)
    fileprivate let maxSelectionViewTap = UITapGestureRecognizer(target: nil, action: nil)

    fileprivate var convertedItemsFrames: [CGRect] {
        itemsViews.map { itemView in
            return self.convert(itemView.frame, from: stackView)
        }
    }

    fileprivate var currentProps: Props?

    // MARK: - Lifecycle -

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
        setupSelectionViewsGestureRecognizers()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
        setupSelectionViewsGestureRecognizers()
    }

    override func awakeFromNib() {
        super.awakeFromNib()
        setup()
        setupSelectionViewsGestureRecognizers()
    }

    // MARK: - Private Methods -

    private func setup() {
        setupStackView()
        layoutIfNeeded()

        [maxSelectionView, minSelectionView].forEach { [weak self] view in
            view.backgroundColor = Constants.selectionViewColor
            view.layer.cornerRadius = 5
            view.isUserInteractionEnabled = true
            self?.insertSubview(view, at: 0)
        }

        rangeView.backgroundColor = Constants.rangeViewColor
        rangeView.center.y = stackView.center.y
        addSubview(rangeView)
        sendSubviewToBack(rangeView)
    }

    private func setupStackView() {
        stackView = UIStackView(frame: CGRect(x: 0, y: 0, width: 0, height: 0))
        stackView.axis = .horizontal
        stackView.alignment = .fill
        stackView.distribution = .fillEqually
        stackView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stackView)
        NSLayoutConstraint.activate([
            stackView.leadingAnchor.constraint(equalTo: leadingAnchor),
            stackView.trailingAnchor.constraint(equalTo: trailingAnchor),
            stackView.topAnchor.constraint(equalTo: topAnchor),
            stackView.bottomAnchor.constraint(equalTo: bottomAnchor),
            stackView.heightAnchor.constraint(equalToConstant: Constants.selectionViewHeight)
        ])
    }

    private func setAllItemsDeselected() {
        itemsViews.forEach { $0.set(active: false) }
    }

    private func setItemView(active: Bool, at index: Int) {
        itemsViews[index].set(active: active)
    }

    private func countLabelWidth(with text: String) -> CGFloat {
        let height: CGFloat = 25
        let attributedText = NSAttributedString(string: text, attributes: [NSAttributedString.Key.font : UIFont.systemFont(ofSize: 15)])
        let drawingOptions: NSStringDrawingOptions = [NSStringDrawingOptions.usesLineFragmentOrigin,
                                                      NSStringDrawingOptions.usesFontLeading]
        let width = attributedText.boundingRect(with: CGSize(width: CGFloat.greatestFiniteMagnitude,
                                                             height: height),
                                                options: drawingOptions,
                                                context: nil).size.width

        return width
    }

    private func selectionViewWidth(for text: String?) -> CGFloat {
        let labelWidth = countLabelWidth(with: text ?? String())
        let labelWidthWithMargins = labelWidth + 20
        let newSelectionViewWidth = labelWidthWithMargins < Constants.selectionViewMinWidth ? Constants.selectionViewMinWidth : labelWidthWithMargins
        return newSelectionViewWidth
    }

    private func selectItem(index: Int, isMinimum: Bool, animated: Bool = true) {
        let selectionView = isMinimum ? minSelectionView : maxSelectionView
        let frameForItem = convertedItemsFrames[index]
        let newSelectionViewWidth = selectionViewWidth(for: itemsViews[index].text)

        let changeSelectionViewFrame: () -> Void = { [weak self] in
            selectionView.frame.size.width = newSelectionViewWidth
            selectionView.center.x = frameForItem.midX
            selectionView.center.y = frameForItem.midY
            self?.updateRangeView()
        }

        if animated {
            UIView.animate(withDuration: 0.15, animations: changeSelectionViewFrame)
        } else {
            changeSelectionViewFrame()
        }

        setItemView(active: true, at: index)
    }

    private func updateRangeView() {
        let selectionViewsDistance = maxSelectionView.center.x - minSelectionView.center.x
        rangeView.frame.size.width = selectionViewsDistance
        rangeView.frame.origin.x = minSelectionView.center.x
    }

    private func setupSelectionViewsGestureRecognizers() {
        [minSelectionView, maxSelectionView].forEach { $0.isUserInteractionEnabled = true }
        [minSelectionViewPan, maxSelectionViewPan].forEach {
            $0.addTarget(self, action: #selector(SliderView.handlePanGesture(_:)))
        }
        minSelectionView.addGestureRecognizer(minSelectionViewPan)
        maxSelectionView.addGestureRecognizer(maxSelectionViewPan)
        [minSelectionViewTap, maxSelectionViewTap].forEach {
            $0.addTarget(self, action: #selector(SliderView.handleTapGesture(_:)))
        }
        minSelectionView.addGestureRecognizer(minSelectionViewTap)
        maxSelectionView.addGestureRecognizer(maxSelectionViewTap)
    }

    @objc private func handleTapGesture(_ tap: UITapGestureRecognizer) {
        guard let view = tap.view,
            let props = currentProps,
            let nearestItem = findMinItemTo(centerX: view.frame.midX) else {
                return
        }
        let oldMin = props.minSelectedValueIndex
        let oldMax = props.maxSelectedValueIndex
        let nearestValueIndex = nearestItem.index
        var newMinMaxIndices: (min: Int, max: Int) = (min: oldMin, max: oldMax)
        if nearestValueIndex == oldMin || nearestValueIndex == oldMax {
            let isMinimumWillMove = nearestValueIndex == oldMax
            setItemView(active: false, at: isMinimumWillMove ? oldMin : oldMax)
            selectItem(index: nearestValueIndex, isMinimum: isMinimumWillMove)
            newMinMaxIndices = (min: nearestValueIndex, max: nearestValueIndex)
        } else if nearestValueIndex < oldMin && nearestValueIndex < oldMax {
            if oldMax != oldMin {
                setItemView(active: false, at: oldMin)
            }
            selectItem(index: nearestValueIndex, isMinimum: true)
            newMinMaxIndices = (min: nearestValueIndex, max: oldMax)
        } else if nearestValueIndex > oldMin && nearestValueIndex < oldMax {
            setItemView(active: false, at: oldMin)
            selectItem(index: nearestValueIndex, isMinimum: true)
            setItemView(active: false, at: oldMax)
            selectItem(index: nearestValueIndex, isMinimum: false)
            newMinMaxIndices = (min: nearestValueIndex, max: nearestValueIndex)
        } else if nearestValueIndex > oldMin && nearestValueIndex > oldMax {
            if oldMax != oldMin {
                setItemView(active: false, at: oldMax)
            }
            selectItem(index: nearestValueIndex, isMinimum: false)
            newMinMaxIndices = (min: oldMin, max: nearestValueIndex)
        } else {
            assertionFailure("hmm some case is not handled")
        }

        currentProps?.minSelectedValueIndex = newMinMaxIndices.min
        currentProps?.maxSelectedValueIndex = newMinMaxIndices.max
        delegate?.sliderViewDidSelectRange(self, minIndex: newMinMaxIndices.min, maxIndex: newMinMaxIndices.max)
    }

    @objc private func handlePanGesture(_ pan: UIPanGestureRecognizer) {
        guard let renderedProps = currentProps else {
            return
        }

        guard pan.state != .ended else {
            if let view = pan.view,
                let lastStoredItem = findMinItemTo(centerX: view.center.x) {
                selectItem(index: lastStoredItem.index, isMinimum: view == minSelectionView)
                let minIndex = view == minSelectionView ? lastStoredItem.index : renderedProps.minSelectedValueIndex
                let maxIndex = view == maxSelectionView ? lastStoredItem.index : renderedProps.maxSelectedValueIndex
                currentProps?.minSelectedValueIndex = minIndex
                currentProps?.maxSelectedValueIndex = maxIndex
                delegate?.sliderViewDidSelectRange(self, minIndex: minIndex, maxIndex: maxIndex)
            }
            pan.setTranslation(CGPoint.zero, in: self)
            return
        }

        if let view = pan.view {
            let translation = pan.translation(in: self)

            let minX = convertedItemsFrames[0].midX
            let maxX = convertedItemsFrames[renderedProps.values.count - 1].midX

            let lastStoredItem = findMinItemTo(centerX: view.center.x)
            let changedX = view.center.x + translation.x

            if changedX >= minX && changedX <= maxX {
                view.center.x = changedX
            }

            if let nearestItem = findMinItemTo(centerX: view.center.x),
                let lastItem = lastStoredItem {

                if currentProps?.minSelectedValueIndex != currentProps?.maxSelectedValueIndex  {
                    setItemView(active: false, at: lastItem.index)
                }

                if findMinItemTo(centerX: minSelectionView.center.x) == findMinItemTo(centerX: maxSelectionView.center.x) {
                    currentProps?.minSelectedValueIndex = nearestItem.index
                    currentProps?.maxSelectedValueIndex = nearestItem.index
                } else if view == minSelectionView {
                    currentProps?.minSelectedValueIndex = nearestItem.index
                } else if view == maxSelectionView {
                    currentProps?.maxSelectedValueIndex = nearestItem.index
                }

                setItemView(active: true, at: nearestItem.index)
            }

            let nearestFramesIndices = convertedItemsFrames
                .indices
                .sorted(by: { abs(convertedItemsFrames[$0].midX - view.center.x) < abs(convertedItemsFrames[$1].midX - view.center.x) })
                .prefix(2)
                .sorted(by: { convertedItemsFrames[$0].midX < convertedItemsFrames[$1].midX })
            if nearestFramesIndices.count == 2 {
                let leftNearestItemIndex = nearestFramesIndices[0]
                let rightNearestItemIndex = nearestFramesIndices[1]
                let leftNearestItemWidth = selectionViewWidth(for: itemsViews[leftNearestItemIndex].text)
                let rightNearestItemWidth = selectionViewWidth(for: itemsViews[rightNearestItemIndex].text)
                if leftNearestItemWidth == rightNearestItemWidth {
                    view.frame.size.width = leftNearestItemWidth
                } else {
                    let leftNearestItemMidX = convertedItemsFrames[leftNearestItemIndex].midX
                    let rightNearestItemMidX = convertedItemsFrames[rightNearestItemIndex].midX
                    let currentCoordinateCoef = (view.center.x - leftNearestItemMidX)/(rightNearestItemMidX - leftNearestItemMidX)
                    let selectionViewsWidthDiff = rightNearestItemWidth - leftNearestItemWidth
                    view.frame.size.width = currentCoordinateCoef * selectionViewsWidthDiff + leftNearestItemWidth
                }
            }

            updateRangeView()
        }

        pan.setTranslation(CGPoint.zero, in: self)
    }

    private func findMinItemTo(centerX: CGFloat) -> ValueIndexWithSize? {
        return convertedItemsFrames
            .indices
            .map { ValueIndexWithSize(index: $0, frame: convertedItemsFrames[$0]) }
            .min(by: { abs($0.frame.midX - centerX) < abs($1.frame.midX - centerX) })
    }

    private func render(props: Props, animated: Bool) {
        if currentProps?.values.count != props.values.count {
            setupItemsViews(count: props.values.count)
            layoutIfNeeded()
        }

        setAllItemsDeselected()
        zip(props.values, itemsViews).forEach { $1.text = $0 }
        selectItem(index: props.maxSelectedValueIndex, isMinimum: false, animated: animated)
        selectItem(index: props.minSelectedValueIndex, isMinimum: true, animated: animated)
        currentProps = props
    }

    private func setupItemsViews(count: Int) {
        itemsViews.forEach { $0.removeFromSuperview() }
        itemsViews.removeAll()
        itemsViews = (0..<count).map { _ in
            let itemView = ItemView()
            let gestureRecognizer = UITapGestureRecognizer(
                target: self,
                action: #selector(SliderView.handleTapGesture(_:))
            )
            itemView.addGestureRecognizer(gestureRecognizer)
            stackView.addArrangedSubview(itemView)
            return itemView
        }
    }

    // MARK: - Public Methods -

    func set(values: [String], minSelectedValueIndex: Int, maxSelectedValueIndex: Int, animated: Bool) {
        if values.isEmpty {
            assertionFailure("Array with values can't be empty")
        } else if !values.indices.contains(minSelectedValueIndex) {
            assertionFailure("minSelectedValueIndex is out of values' bounds")
        } else if !values.indices.contains(maxSelectedValueIndex) {
            assertionFailure("maxSelectedValueIndex is out of values' bounds")
        }
        let props = Props(values: values, minSelectedValueIndex: minSelectedValueIndex, maxSelectedValueIndex: maxSelectedValueIndex)
        render(props: props, animated: animated)
    }

    // MARK: - Inner Declarations -

    private class ItemView: UIView {
        private let label: Label

        var text: String? {
            set { label.text = newValue }
            get { return label.text }
        }

        override init(frame: CGRect) {
            label = Label()
            super.init(frame: frame)
            setup()
        }

        required init?(coder: NSCoder) {
            label = Label()
            super.init(coder: coder)
            setup()
        }

        func set(active: Bool) {
            label.set(active: active)
        }

        private func setup() {
            backgroundColor = .clear
            isUserInteractionEnabled = true
            label.translatesAutoresizingMaskIntoConstraints = false
            addSubview(label)
            NSLayoutConstraint.activate([
                label.leadingAnchor.constraint(equalTo: leadingAnchor),
                label.trailingAnchor.constraint(equalTo: trailingAnchor),
                label.topAnchor.constraint(equalTo: topAnchor),
                label.bottomAnchor.constraint(equalTo: bottomAnchor)
            ])
        }
    }

    private class Label: UILabel {
        override init(frame: CGRect) {
            super.init(frame: frame)
            setup()
        }

        required init?(coder: NSCoder) {
            super.init(coder: coder)
            setup()
        }

        func set(active: Bool) {
            textColor = active ? UIColor.white : UIColor.black
        }

        private func setup() {
            textAlignment = .center
            textColor = UIColor.black
            font = UIFont.systemFont(ofSize: 15, weight: .regular)
            text = String()
        }
    }

    fileprivate struct Props {
        let values: [String]
        fileprivate(set) var minSelectedValueIndex: Int
        fileprivate(set) var maxSelectedValueIndex: Int
    }

    fileprivate struct ValueIndexWithSize: Equatable {
        let index: Int
        let frame: CGRect
    }
}

extension SliderView {
    enum Constants {
        fileprivate static let selectionViewColor = UIColor(red: 0/255, green: 158/255, blue: 152/255, alpha: 1.0)
        fileprivate static let rangeViewColor = UIColor(white: 0.9, alpha: 1.0)
        fileprivate static let margin: CGFloat = 0.0
        fileprivate static let selectionViewMinWidth: CGFloat = 55
        fileprivate static let selectionViewHeight: CGFloat = 55
    }
}

extension SliderView {
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        let pointForMinBlueView = minSelectionView.convert(point, from: self)
        let pointForMaxBlueView = maxSelectionView.convert(point, from: self)

        if minSelectionView.bounds.contains(pointForMinBlueView) {
            return minSelectionView
        } else if maxSelectionView.bounds.contains(pointForMaxBlueView) {
            return maxSelectionView
        }

        return super.hitTest(point, with: event)
    }
}
