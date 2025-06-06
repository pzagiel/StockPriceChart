import Cocoa
import AVFoundation
import CoreServices
extension Calendar {
    func startOfMonth(for date: Date) -> Date {
        return self.date(from: self.dateComponents([.year, .month], from: date))!
    }
}
extension GraphView: NSDraggingSource,NSFilePromiseProviderDelegate {
    func filePromiseProvider(_ filePromiseProvider: NSFilePromiseProvider, fileNameForType fileType: String) -> String {
        return "Graph.png"
    }
    func filePromiseProvider(_ filePromiseProvider: NSFilePromiseProvider, writePromiseTo url: URL, completionHandler: @escaping (Error?) -> Void) {
        guard let image = graphImage(),
              let tiffData = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiffData),
              let pngData = bitmap.representation(using: .png, properties: [:]) else {
            completionHandler(NSError(domain: "GraphExport", code: 1, userInfo: nil))
            return
        }
        
        do {
            try pngData.write(to: url)
            completionHandler(nil)
        } catch {
            completionHandler(error)
        }
    }
    func draggingSession(_ session: NSDraggingSession, sourceOperationMaskFor context: NSDraggingContext) -> NSDragOperation {
        return .copy
    }

    func ignoreModifierKeys(for session: NSDraggingSession) -> Bool {
        return true // pour ne pas dépendre de la touche ⌥
    }
}


@objc class GraphView: NSView {
    
    // MARK: - Properties
    private var stockPrices: [StockPrice] = []
    
    // Nouvelles propriétés à ajouter dans la classe GraphView
    private var isTrackingMouse = false
    private var currentMousePosition: CGPoint?
    private var currentDataPoint: (date: Date, value: Double)?
    private var graphRect: CGRect = .zero
    private var dataRange: DataRange?
    private var trackingArea: NSTrackingArea?
    
    
    // Configuration constants
    private struct Constants {
        static let baseMargin: CGFloat = 20
        static let bottomMargin: CGFloat = 40
        static let topMargin: CGFloat = 20
        static let minLabelSpacing: CGFloat = 60
        static let labelPadding: CGFloat = 10
        static let gridLineWidth: CGFloat = 0.5
        static let mainLineWidth: CGFloat = 2.0
        static let axisLineWidth: CGFloat = 1.0
        static let minTicks = 4
        static let maxTicks = 6
        static let fontSize: CGFloat = 10
    }
    
    // MARK: - Initialization
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setupView()
    }

    required init?(coder decoder: NSCoder) {
        super.init(coder: decoder)
        setupView()
    }
    
    private func setupView() {
        self.wantsLayer = true
        setupMouseTracking()
    }

    // MARK: - Public Interface
    func setData(_ prices: [StockPrice]) {
        self.stockPrices = prices
        self.needsDisplay = true
    }

    // MARK: - Drawing
    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        
        guard let context = NSGraphicsContext.current?.cgContext else { return }
        guard !stockPrices.isEmpty else {
            drawEmptyState(context: context)
            return
        }

        // Prepare data
        let validPrices = stockPrices.map { (date: $0.date, value: $0.value) }
        guard let dataRange = calculateDataRange(from: validPrices) else { return }
        
        // Setup drawing area
        let graphRect = calculateGraphRect(for: dataRange.values)
        
        // IMPORTANT: Stocker ces valeurs dans les propriétés de l'instance
        self.graphRect = graphRect
        self.dataRange = dataRange
        
        // Draw components
        drawBackground(context: context)
        drawGrid(context: context, in: graphRect, for: dataRange.values)
        drawChart(context: context, in: graphRect, with: validPrices, dataRange: dataRange)
        drawLabels(context: context, in: graphRect, with: validPrices, dataRange: dataRange)
        drawAxes(context: context, in: graphRect)
        // NOUVEAU: Dessiner le crosshair interactif
        drawCrosshair(context: context, in: graphRect, with: validPrices, dataRange: dataRange)
    }
    
    // MARK: - Helper Structures
    private struct DataRange {
        let dates: (min: Date, max: Date)
        let values: (min: Double, max: Double)
        let dateSpan: TimeInterval
        let valueSpan: Double
    }
    
    private struct TickInfo {
        let values: [Double]
        let interval: Double
        let niceBounds: (min: Double, max: Double)
    }
    
    override var acceptsFirstResponder: Bool { true }

    func graphImage() -> NSImage? {
        let rep = bitmapImageRepForCachingDisplay(in: bounds)!
        cacheDisplay(in: bounds, to: rep)
        let image = NSImage(size: bounds.size)
        image.addRepresentation(rep)
        return image
    }

     func mouseDownOld(with event: NSEvent) {
        guard let image = graphImage() else { return }

        let draggingItem = NSDraggingItem(pasteboardWriter: image)

        let dragFrame = bounds
        draggingItem.setDraggingFrame(dragFrame, contents: image)

        beginDraggingSession(with: [draggingItem], event: event, source: self)
    }

    override func mouseDown(with event: NSEvent) {
        let fileType: String
        if #available(macOS 11.0, *) {
            fileType = UTType.png.identifier
        } else {
            fileType = kUTTypePNG as String
        }

        let filePromise = NSFilePromiseProvider(fileType: fileType, delegate: self)
       // let filePromise = NSFilePromiseProvider(fileType: UTType.png.identifier, delegate: self)

        let image = graphImage() ?? NSImage(size: NSSize(width: 100, height: 75))

        let draggingItem = NSDraggingItem(pasteboardWriter: filePromise)
        draggingItem.setDraggingFrame(bounds, contents: image)

        beginDraggingSession(with: [draggingItem], event: event, source: self)
    }

    
    @objc func copy(_ sender: Any?) {
         let imageRep = bitmapImageRepForCachingDisplay(in: bounds)!
         cacheDisplay(in: bounds, to: imageRep)
         let image = NSImage(size: bounds.size)
         image.addRepresentation(imageRep)

         let pasteboard = NSPasteboard.general
         pasteboard.clearContents()
         pasteboard.writeObjects([image])
         playShutterSound()
    }
    
    func playShutterSound() {
        guard let url = Bundle.main.url(forResource: "PhotoShutterIPhone", withExtension: "aiff") else {
            print("⚠️ Son non trouvé dans le bundle")
            return
        }

        do {
            shutterPlayer = try AVAudioPlayer(contentsOf: url)
            shutterPlayer?.prepareToPlay()
            shutterPlayer?.play()
        } catch {
            print("❌ Erreur de lecture audio : \(error)")
        }
    }
    
    // MARK: - Data Processing
    private func calculateDataRange(from validPrices: [(date: Date, value: Double)]) -> DataRange? {
        guard !validPrices.isEmpty else { return nil }
        
        let dates = validPrices.map { $0.date }
        let values = validPrices.map { $0.value }
        
        guard let minDate = dates.min(),
              let maxDate = dates.max(),
              let minValue = values.min(),
              let maxValue = values.max(),
              maxDate != minDate,
              maxValue != minValue else { return nil }
        
        return DataRange(
            dates: (min: minDate, max: maxDate),
            values: (min: minValue, max: maxValue),
            dateSpan: maxDate.timeIntervalSince(minDate),
            valueSpan: maxValue - minValue
        )
    }
    
    // MARK: - Performance Calculation
    private func calculatePerformance() -> Double? {
        guard stockPrices.count >= 2 else { return nil }
        
        let firstPrice = stockPrices.first!.value
        let lastPrice = stockPrices.last!.value
        
        guard firstPrice > 0 else { return nil }
        
        return ((lastPrice - firstPrice) / firstPrice) * 100.0
    }
    
    private func calculatePerformanceToPoint(_ targetValue: Double) -> Double? {
        guard let firstPrice = stockPrices.first?.value, firstPrice > 0 else { return nil }
        
        return ((targetValue - firstPrice) / firstPrice) * 100.0
    }
    
    private func calculateHighLow() -> (high: Double, low: Double)? {
        guard !stockPrices.isEmpty else { return nil }
        
        let values = stockPrices.map { $0.value }
        guard let high = values.max(), let low = values.min() else { return nil }
        
        return (high: high, low: low)
    }
    
    private func calculateNiceInterval(_ range: Double, _ targetTicks: Int) -> Double {
        let roughInterval = range / Double(targetTicks - 1)
        let magnitude = pow(10.0, floor(log10(roughInterval)))
        let normalizedInterval = roughInterval / magnitude
        
        let niceInterval: Double
        if normalizedInterval <= 1.0 {
            niceInterval = 1.0
        } else if normalizedInterval <= 2.0 {
            niceInterval = 2.0
        } else if normalizedInterval <= 5.0 {
            niceInterval = 5.0
        } else {
            niceInterval = 10.0
        }
        
        return niceInterval * magnitude
    }
    
    private func calculateTickInfo(for valueRange: (min: Double, max: Double)) -> TickInfo {
        let range = valueRange.max - valueRange.min
        
        var bestInterval = 0.0
        var bestTicks: [Double] = []
        var bestBounds = (min: 0.0, max: 0.0)
        
        for targetTicks in Constants.minTicks...Constants.maxTicks {
            let interval = calculateNiceInterval(range, targetTicks)
            let niceMin = floor(valueRange.min / interval) * interval
            let niceMax = ceil(valueRange.max / interval) * interval
            let actualTicks = Int((niceMax - niceMin) / interval) + 1
            
            if actualTicks >= Constants.minTicks && actualTicks <= Constants.maxTicks {
                bestInterval = interval
                bestBounds = (min: niceMin, max: niceMax)
                break
            } else if bestInterval == 0.0 {
                bestInterval = interval
                bestBounds = (min: niceMin, max: niceMax)
            }
        }
        
        // Generate tick values
        var tickValues: [Double] = []
        var current = bestBounds.min
        while current <= bestBounds.max + bestInterval * 0.001 {
            if current >= valueRange.min - bestInterval * 0.1 {
                tickValues.append(current)
            }
            current += bestInterval
        }
        
        return TickInfo(values: tickValues, interval: bestInterval, niceBounds: bestBounds)
    }
    
    private func calculateGraphRect(for valueRange: (min: Double, max: Double)) -> CGRect {
        let tickInfo = calculateTickInfo(for: valueRange)
        let labelAttributes = createLabelAttributes()
        
        // Calculate maximum label width
        let maxLabelWidth = tickInfo.values.reduce(CGFloat(0)) { maxWidth, value in
            let label = formatValue(value, interval: tickInfo.interval)
            let size = (label as NSString).size(withAttributes: labelAttributes)
            return max(maxWidth, size.width)
        }
        
        let leftMargin = max(Constants.baseMargin, maxLabelWidth + Constants.labelPadding)
        
        return CGRect(
            x: leftMargin,
            y: Constants.bottomMargin,
            width: bounds.width - leftMargin - Constants.baseMargin,
            height: bounds.height - Constants.bottomMargin - Constants.topMargin
        )
    }
    
    // MARK: - Drawing Methods
    private func drawEmptyState(context: CGContext) {
        context.setFillColor(NSColor.black.cgColor)
        context.fill(bounds)
        
        let message = "Aucune donnée disponible"
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 16),
            .foregroundColor: NSColor.lightGray
        ]
        let size = (message as NSString).size(withAttributes: attributes)
        let point = CGPoint(
            x: (bounds.width - size.width) / 2,
            y: (bounds.height - size.height) / 2
        )
        (message as NSString).draw(at: point, withAttributes: attributes)
    }
    
    private func drawBackground(context: CGContext) {
        context.setFillColor(NSColor.black.cgColor)
        context.fill(bounds)
    }
    
    private func drawGrid(context: CGContext, in graphRect: CGRect, for valueRange: (min: Double, max: Double)) {
        let tickInfo = calculateTickInfo(for: valueRange)
        
        context.setStrokeColor(NSColor.darkGray.cgColor)
        context.setLineWidth(Constants.gridLineWidth)
        
        for value in tickInfo.values {
            let yRatio = CGFloat((value - valueRange.min) / (valueRange.max - valueRange.min))
            let y = graphRect.minY + yRatio * graphRect.height
            
            context.move(to: CGPoint(x: graphRect.minX, y: y))
            context.addLine(to: CGPoint(x: graphRect.maxX, y: y))
        }
        context.strokePath()
    }
    
    private func drawChart(context: CGContext, in graphRect: CGRect,
                          with validPrices: [(date: Date, value: Double)],
                          dataRange: DataRange) {
        
        let points = calculatePoints(from: validPrices, in: graphRect, dataRange: dataRange)
        
        // Draw gradient fill
        drawGradientFill(context: context, points: points, in: graphRect)
        
        // Draw main line
        drawMainLine(context: context, points: points)
    }
    
    private func calculatePoints(from validPrices: [(date: Date, value: Double)],
                               in graphRect: CGRect,
                               dataRange: DataRange) -> [CGPoint] {
        return validPrices.map { item in
            let xRatio = CGFloat(item.date.timeIntervalSince(dataRange.dates.min) / dataRange.dateSpan)
            let yRatio = CGFloat((item.value - dataRange.values.min) / dataRange.valueSpan)
            let x = graphRect.minX + xRatio * graphRect.width
            let y = graphRect.minY + yRatio * graphRect.height
            return CGPoint(x: x, y: y)
        }
    }
    
    private func drawGradientFill(context: CGContext, points: [CGPoint], in graphRect: CGRect) {
        guard let first = points.first, let last = points.last else { return }
        
        let fillPath = CGMutablePath()
        fillPath.move(to: CGPoint(x: first.x, y: graphRect.minY))
        for point in points {
            fillPath.addLine(to: point)
        }
        fillPath.addLine(to: CGPoint(x: last.x, y: graphRect.minY))
        fillPath.closeSubpath()

        context.saveGState()
        context.addPath(fillPath)
        context.clip()

        let colorSpace = CGColorSpaceCreateDeviceRGB()
        guard let gradient = CGGradient(
            colorsSpace: colorSpace,
            colors: [
                NSColor.green.withAlphaComponent(0.02).cgColor,
                NSColor.green.withAlphaComponent(0.35).cgColor
            ] as CFArray,
            locations: [0.0, 1.0]
        ) else { return }

        context.drawLinearGradient(
            gradient,
            start: CGPoint(x: 0, y: graphRect.minY + 1),
            end: CGPoint(x: 0, y: graphRect.maxY),
            options: []
        )
        context.restoreGState()
    }
    
    private func drawMainLine(context: CGContext, points: [CGPoint]) {
        guard !points.isEmpty else { return }
        
        context.setStrokeColor(NSColor.green.cgColor)
        context.setLineWidth(Constants.mainLineWidth)
        context.beginPath()
        context.addLines(between: points)
        context.strokePath()
    }
    
    private func drawLabels(context: CGContext, in graphRect: CGRect,
                           with validPrices: [(date: Date, value: Double)],
                           dataRange: DataRange) {
        drawValueLabels(context: context, in: graphRect, for: dataRange.values)
        drawDateLabels(context: context, in: graphRect, with: validPrices, dataRange: dataRange)
    }
    
    private func drawValueLabels(context: CGContext, in graphRect: CGRect, for valueRange: (min: Double, max: Double)) {
        let tickInfo = calculateTickInfo(for: valueRange)
        let labelAttributes = createLabelAttributes()
        
        for (index, value) in tickInfo.values.enumerated() {
            // Skip first label if it's at the minimum
            if index == 0 && abs(value - valueRange.min) < 0.001 {
                continue
            }
            
            let yRatio = CGFloat((value - valueRange.min) / (valueRange.max - valueRange.min))
            let y = graphRect.minY + yRatio * graphRect.height
            
            let label = formatValue(value, interval: tickInfo.interval)
            let labelString = label as NSString
            let size = labelString.size(withAttributes: labelAttributes)
            
            labelString.draw(
                at: CGPoint(x: graphRect.minX - size.width - 5, y: y - size.height / 2),
                withAttributes: labelAttributes
            )
        }
    }
    
    private func drawDateLabelsClaude(context: CGContext, in graphRect: CGRect,
                               with validPrices: [(date: Date, value: Double)],
                               dataRange: DataRange) {
        let formatter = createDateFormatter(for: dataRange.dateSpan)
        let labelAttributes = createLabelAttributes()
        
        // Calculer le nombre optimal de labels
        let availableWidth = graphRect.width
        let estimatedLabelWidth: CGFloat = 70
        let maxLabels = max(3, min(7, Int(availableWidth / estimatedLabelWidth)))
        
        // Créer des positions X uniformément réparties dans l'ESPACE VISUEL
        var labelPositions: [CGFloat] = []
        
        if maxLabels == 1 {
            labelPositions = [graphRect.minX + graphRect.width / 2]
        } else {
            for i in 0..<maxLabels {
                let ratio = CGFloat(i) / CGFloat(maxLabels - 1)
                let x = graphRect.minX + ratio * graphRect.width
                labelPositions.append(x)
            }
        }
        
        var displayedLabels = Set<String>()
        
        for xPosition in labelPositions {
            // Convertir la position X visuelle en ratio temporel
            let xRatio = (xPosition - graphRect.minX) / graphRect.width
            
            // Trouver l'indice correspondant dans les données
            // Utiliser la distribution des données réelles, pas une distribution temporelle uniforme
            let targetIndex = max(0, min(validPrices.count - 1, Int(round(Double(xRatio) * Double(validPrices.count - 1)))))
            
            let targetDate = validPrices[targetIndex].date
            let labelText = formatter.string(from: targetDate)
            
            // Éviter les doublons de texte formaté
            if displayedLabels.contains(labelText) {
                continue
            }
            displayedLabels.insert(labelText)
            
            // Utiliser la position X visuelle prévue (pas la position basée sur la date)
            // Cela garantit un espacement uniforme visuellement
            let size = (labelText as NSString).size(withAttributes: labelAttributes)
            
            // Centrer le label horizontalement
            var labelX = xPosition - size.width / 2
            
            // S'assurer que le label reste dans les limites du graphique
            labelX = max(graphRect.minX, min(labelX, graphRect.maxX - size.width))
            
            // Dessiner le label
            (labelText as NSString).draw(
                at: CGPoint(x: labelX, y: graphRect.minY - size.height - 5),
                withAttributes: labelAttributes
            )
        }
    }
    
    private func drawDateLabels(context: CGContext, in graphRect: CGRect,
                               with validPrices: [(date: Date, value: Double)],
                               dataRange: DataRange) {
        let labelAttributes = createLabelAttributes()
        let calendar = Calendar(identifier: .gregorian)
        let totalDays = dataRange.dateSpan / (24 * 60 * 60)

        var currentDate: Date
        var stepComponent: Calendar.Component
        var stepValue: Int
        var dateFormat: String

        if totalDays <= 10 {
            // Afficher tous les jours
            stepComponent = .day
            stepValue = 1
            dateFormat = "dd MMM"
        } else if totalDays <= 31 {
            // Tous les 5 jours
            stepComponent = .day
            stepValue = 5
            dateFormat = "dd MMM"
        } else if totalDays <= 180 {
            // Début de chaque mois
            stepComponent = .month
            stepValue = 1
            dateFormat = "MMM"
        } else if totalDays <= 730 {
            // Un mois sur deux
            stepComponent = .month
            stepValue = 2
            dateFormat = "MMM yy"
        } else {
            // Afficher par année
            stepComponent = .year
            stepValue = 1
            dateFormat = "yyyy"
        }

        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "fr_FR")
        formatter.dateFormat = dateFormat

        currentDate = calendar.startOfDay(for: dataRange.dates.min)

        var displayedLabels = Set<String>()

        while currentDate <= dataRange.dates.max {
            let xRatio = CGFloat(currentDate.timeIntervalSince(dataRange.dates.min) / dataRange.dateSpan)
            let xPosition = graphRect.minX + xRatio * graphRect.width

            guard xPosition >= graphRect.minX, xPosition <= graphRect.maxX else {
                currentDate = calendar.date(byAdding: stepComponent, value: stepValue, to: currentDate) ?? currentDate.addingTimeInterval(86400)
                continue
            }

            let labelText = formatter.string(from: currentDate)
            if displayedLabels.contains(labelText) {
                currentDate = calendar.date(byAdding: stepComponent, value: stepValue, to: currentDate) ?? currentDate.addingTimeInterval(86400)
                continue
            }
            displayedLabels.insert(labelText)

            // Ligne verticale sous l'axe X
            context.setStrokeColor(NSColor.white.cgColor)
            context.setLineWidth(0.7)
            context.move(to: CGPoint(x: xPosition, y: graphRect.minY - 5))
            context.addLine(to: CGPoint(x: xPosition, y: graphRect.minY))
            context.strokePath()

            // Dessiner le texte centré
            let size = (labelText as NSString).size(withAttributes: labelAttributes)
            var labelX = xPosition - size.width / 2
            labelX = max(graphRect.minX, min(labelX, graphRect.maxX - size.width))

            (labelText as NSString).draw(
                at: CGPoint(x: labelX, y: graphRect.minY - size.height - 5),
                withAttributes: labelAttributes
            )

            currentDate = calendar.date(byAdding: stepComponent, value: stepValue, to: currentDate) ?? currentDate.addingTimeInterval(86400)
        }
    }

    // Méthode améliorée pour le formatage des dates
    private func createDateFormatter(for timeSpan: TimeInterval) -> DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "fr_FR")
        
        let days = timeSpan / (24 * 60 * 60)
        
        if days <= 1 {
            formatter.dateFormat = "HH:mm"
        } else if days <= 7 {
            formatter.dateFormat = "E dd"
        } else if days <= 30 {
            formatter.dateFormat = "dd/MM"
        } else if days <= 365 {
            formatter.dateFormat = "MMM"
        } else if days <= 365 * 2 {
            formatter.dateFormat = "MMM yy"
        } else {
            formatter.dateFormat = "yyyy"
        }
        
        return formatter
    }
    
    private func drawAxes(context: CGContext, in graphRect: CGRect) {
        context.setStrokeColor(NSColor.white.cgColor)
        context.setLineWidth(Constants.axisLineWidth)
        context.move(to: CGPoint(x: graphRect.minX, y: graphRect.minY))
        context.addLine(to: CGPoint(x: graphRect.minX, y: graphRect.maxY))
        context.move(to: CGPoint(x: graphRect.minX, y: graphRect.minY))
        context.addLine(to: CGPoint(x: graphRect.maxX, y: graphRect.minY))
        context.strokePath()
    }
    
    // MARK: - Utility Methods
    private func createLabelAttributes() -> [NSAttributedString.Key: Any] {
        return [
            .font: NSFont.systemFont(ofSize: Constants.fontSize),
            .foregroundColor: NSColor.white
        ]
    }
    
    private func formatValue(_ value: Double, interval: Double) -> String {
        if interval >= 1.0 {
            return String(format: "%.0f", value)
        } else if interval >= 0.1 {
            return String(format: "%.1f", value)
        } else {
            return String(format: "%.2f", value)
        }
    }
    
    private func calculateOptimalDateStep(for timeSpan: TimeInterval, dataCount: Int) -> Int {
        let days = timeSpan / (24 * 60 * 60)
        let availableWidth = bounds.width - 2 * Constants.baseMargin
        let maxLabels = Int(availableWidth / Constants.minLabelSpacing)
        
        let baseStep: Int
        if days <= 7 {
            baseStep = max(1, dataCount / 7)
        } else if days <= 30 {
            baseStep = max(1, dataCount / 7)
        } else if days <= 365 {
            baseStep = max(1, dataCount / 6)
        } else {
            baseStep = max(1, dataCount / 6)
        }
        
        return max(baseStep, dataCount / maxLabels)
    }
    
    // MARK: - Mouse Tracking Setup
    private func setupMouseTracking() {
        let options: NSTrackingArea.Options = [
            .activeInKeyWindow,
            .mouseMoved,
            .mouseEnteredAndExited
        ]
        
        if let existingArea = trackingArea {
            removeTrackingArea(existingArea)
        }
        
        trackingArea = NSTrackingArea(
            rect: bounds,
            options: options,
            owner: self,
            userInfo: nil
        )
        addTrackingArea(trackingArea!)
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        setupMouseTracking()
    }

    // MARK: - Mouse Events
    override func mouseEntered(with event: NSEvent) {
        super.mouseEntered(with: event)
        isTrackingMouse = true
        updateCrosshair(with: event)
    }

    override func mouseExited(with event: NSEvent) {
        super.mouseExited(with: event)
        isTrackingMouse = false
        currentMousePosition = nil
        currentDataPoint = nil
        needsDisplay = true
    }

    override func mouseMoved(with event: NSEvent) {
        super.mouseMoved(with: event)
        if isTrackingMouse {
            updateCrosshair(with: event)
        }
    }

    private func updateCrosshair(with event: NSEvent) {
        guard !stockPrices.isEmpty,
              let dataRange = self.dataRange else { return }
        
        let locationInView = convert(event.locationInWindow, from: nil)
        
        // Vérifier si la souris est dans la zone du graphique
        guard graphRect.contains(locationInView) else {
            if isTrackingMouse {
                currentMousePosition = nil
                currentDataPoint = nil
                needsDisplay = true
            }
            return
        }
        
        currentMousePosition = locationInView
        
        // Trouver le point de données le plus proche
        let xRatio = (locationInView.x - graphRect.minX) / graphRect.width
        let targetIndex = max(0, min(stockPrices.count - 1,
                                    Int(round(Double(xRatio) * Double(stockPrices.count - 1)))))
        
        let stockPrice = stockPrices[targetIndex]
        currentDataPoint = (date: stockPrice.date, value: stockPrice.value)
        
        needsDisplay = true
    }

    // MARK: - Crosshair Drawing
    private func drawCrosshair(context: CGContext, in rect: CGRect,
                              with validPrices: [(date: Date, value: Double)],
                              dataRange: DataRange) {
        guard isTrackingMouse,
              let mousePos = currentMousePosition,
              let dataPoint = currentDataPoint,
              rect.contains(mousePos) else { return }
        
        // Calculer la position exacte du point sur la courbe
        let xRatio = (dataPoint.date.timeIntervalSince(dataRange.dates.min)) / dataRange.dateSpan
        let yRatio = (dataPoint.value - dataRange.values.min) / dataRange.valueSpan
        
        let pointX = rect.minX + CGFloat(xRatio) * rect.width
        let pointY = rect.minY + CGFloat(yRatio) * rect.height
        let curvePoint = CGPoint(x: pointX, y: pointY)
        
        // Dessiner les lignes de crosshair
        drawCrosshairLines(context: context, at: curvePoint, in: rect)
        
        // Dessiner le point sur la courbe
        drawCurvePoint(context: context, at: curvePoint)
        
        // Dessiner le tooltip
        drawTooltip(context: context, at: curvePoint, dataPoint: dataPoint, in: rect)
    }

    private func drawCrosshairLines(context: CGContext, at point: CGPoint, in rect: CGRect) {
        context.saveGState()
        
        // Style des lignes de crosshair
        context.setStrokeColor(NSColor.white.withAlphaComponent(0.5).cgColor)
        context.setLineWidth(1.0)
        context.setLineDash(phase: 0, lengths: [4, 2])
        
        // Ligne verticale
        context.move(to: CGPoint(x: point.x, y: rect.minY))
        context.addLine(to: CGPoint(x: point.x, y: rect.maxY))
        
        // Ligne horizontale
        context.move(to: CGPoint(x: rect.minX, y: point.y))
        context.addLine(to: CGPoint(x: rect.maxX, y: point.y))
        
        context.strokePath()
        context.restoreGState()
    }

    private func drawCurvePoint(context: CGContext, at point: CGPoint) {
        context.saveGState()
        
        // Cercle blanc avec bordure verte
        let radius: CGFloat = 4
        let circleRect = CGRect(
            x: point.x - radius,
            y: point.y - radius,
            width: radius * 2,
            height: radius * 2
        )
        
        // Remplissage blanc
        context.setFillColor(NSColor.white.cgColor)
        context.fillEllipse(in: circleRect)
        
        // Bordure verte
        context.setStrokeColor(NSColor.green.cgColor)
        context.setLineWidth(2.0)
        context.strokeEllipse(in: circleRect)
        
        context.restoreGState()
    }

    private func drawTooltip(context: CGContext, at point: CGPoint,
                            dataPoint: (date: Date, value: Double), in rect: CGRect) {
        // Formater les données
        let dateFormatter = DateFormatter()
        dateFormatter.locale = Locale(identifier: "fr_FR")
        dateFormatter.dateStyle = .medium
        
        let dateText = dateFormatter.string(from: dataPoint.date)
        let valueText = String(format: "%.2f", dataPoint.value)
        
        // Calculer et formater la performance
        var performanceText = ""
        var performanceColor = NSColor.white
        
        if let performance = calculatePerformanceToPoint(dataPoint.value) {
            let sign = performance >= 0 ? "+" : ""
            performanceText = " (\(sign)\(String(format: "%.2f", performance))%)"
            performanceColor = performance >= 0 ? NSColor.green : NSColor.red
        }
        
        // Ajouter les informations High/Low pour le contexte
//        var highLowText = ""
//        if let highLow = calculateHighLow() {
//            let isHigh = abs(dataPoint.value - highLow.high) < 0.01
//            let isLow = abs(dataPoint.value - highLow.low) < 0.01
//
//            if isHigh {
//                highLowText = " 📈 MAX"
//            } else if isLow {
//                highLowText = " 📉 MIN"
//            }
//        }
        
        // Créer le texte avec la performance colorée
        let baseText = "\(valueText)\(performanceText)\n\(dateText)"
        
        // Attributs du texte de base
        let baseAttributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 11),
            .foregroundColor: NSColor.white
        ]
        
        // Créer NSMutableAttributedString pour pouvoir colorer différemment
        let attributedText = NSMutableAttributedString(string: baseText, attributes: baseAttributes)
        
        // Trouver la plage de la performance pour la colorer différemment
        if !performanceText.isEmpty {
            let range = (baseText as NSString).range(of: performanceText)
            if range.location != NSNotFound {
                attributedText.addAttribute(.foregroundColor, value: performanceColor, range: range)
            }
        }
        
        let textSize = attributedText.size()
        
        // Calculer la position du tooltip
        let padding: CGFloat = 8
        let tooltipWidth = textSize.width + padding * 2
        let tooltipHeight = textSize.height + padding * 2
        
        var tooltipX = point.x + 15
        var tooltipY = point.y - tooltipHeight / 2
        
        // Ajuster pour rester dans les limites
        if tooltipX + tooltipWidth > rect.maxX {
            tooltipX = point.x - tooltipWidth - 15
        }
        if tooltipY < rect.minY {
            tooltipY = rect.minY
        } else if tooltipY + tooltipHeight > rect.maxY {
            tooltipY = rect.maxY - tooltipHeight
        }
        
        let tooltipRect = CGRect(
            x: tooltipX,
            y: tooltipY,
            width: tooltipWidth,
            height: tooltipHeight
        )
        
        context.saveGState()
        
        // Dessiner le fond du tooltip avec un léger arrondi
        let roundedRect = CGPath(roundedRect: tooltipRect, cornerWidth: 4, cornerHeight: 4, transform: nil)
        context.addPath(roundedRect)
        context.setFillColor(NSColor.black.withAlphaComponent(0.85).cgColor)
        context.fillPath()
        
        // Dessiner la bordure
        context.addPath(roundedRect)
        context.setStrokeColor(performanceColor.withAlphaComponent(0.6).cgColor)
        context.setLineWidth(1.0)
        context.strokePath()
        
        context.restoreGState()
        
        // Dessiner le texte
        let textRect = CGRect(
            x: tooltipX + padding,
            y: tooltipY + padding,
            width: textSize.width,
            height: textSize.height
        )
        
        attributedText.draw(in: textRect)
    }
    deinit {
        print("🧼 GraphView a été libéré")
    }

}
