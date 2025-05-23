import Cocoa

class GraphView: NSView {
    private var stockPrices: [StockPrice] = []

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        self.wantsLayer = true
    }

    required init?(coder decoder: NSCoder) {
        super.init(coder: decoder)
        self.wantsLayer = true
    }

    /// Appel à faire depuis le contrôleur pour définir les données
    func setData(_ prices: [StockPrice]) {
        self.stockPrices = prices
        self.needsDisplay = true
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        guard !stockPrices.isEmpty else { return }
        guard let context = NSGraphicsContext.current?.cgContext else { return }

        let baseMargin: CGFloat = 20
        let bottomMargin: CGFloat = 40 // Pour les dates
        let topMargin: CGFloat = 20
        
        context.setFillColor(NSColor.black.cgColor)
        context.fill(bounds)

        // Convertir les données avec des dates valides uniquement
        let validPrices: [(date: Date, value: Double)] = stockPrices.map {
            (date: $0.date, value: $0.value)
        }

        guard !validPrices.isEmpty else { return }

        let dates = validPrices.map { $0.date }
        let values = validPrices.map { $0.value }

        guard let minDate = dates.min(),
              let maxDate = dates.max(),
              let minValue = values.min(),
              let maxValue = values.max(),
              maxDate != minDate,
              maxValue != minValue else { return }

        // Calculer la marge gauche nécessaire pour les labels de valeurs
        let labelAttributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 14),
            .foregroundColor: NSColor.white
        ]
        
        let gridLineCount = 5
        let valueRange = maxValue - minValue
        var maxLabelWidth: CGFloat = 0
        
        // Calculer la largeur maximale nécessaire pour tous les labels de valeurs
        for i in 0...gridLineCount {
            let value = minValue + (Double(i) / Double(gridLineCount)) * valueRange
            let label = String(format: "%.2f", value) as NSString
            let size = label.size(withAttributes: labelAttributes)
            maxLabelWidth = max(maxLabelWidth, size.width)
        }
        
        // Marge gauche dynamique avec un minimum de sécurité
        let leftMargin = max(baseMargin, maxLabelWidth + 10)
        
        let graphRect = CGRect(
            x: leftMargin,
            y: bottomMargin,
            width: bounds.width - leftMargin - baseMargin,
            height: bounds.height - bottomMargin - topMargin
        )

        let dateRange = maxDate.timeIntervalSince(minDate)

        // Grille horizontale
        context.setStrokeColor(NSColor.darkGray.cgColor)
        context.setLineWidth(0.5)

        for i in 0...gridLineCount {
            let y = graphRect.minY + CGFloat(i) / CGFloat(gridLineCount) * graphRect.height
            context.move(to: CGPoint(x: graphRect.minX, y: y))
            context.addLine(to: CGPoint(x: graphRect.maxX, y: y))
        }
        context.strokePath()

        // Points de la courbe
        let points: [CGPoint] = validPrices.map { item in
            let xRatio = CGFloat(item.date.timeIntervalSince(minDate) / dateRange)
            let yRatio = CGFloat((item.value - minValue) / valueRange)
            let x = graphRect.minX + xRatio * graphRect.width
            let y = graphRect.minY + yRatio * graphRect.height
            return CGPoint(x: x, y: y)
        }

        // Dégradé
        if let first = points.first, let last = points.last {
            let fillPath = CGMutablePath()
            fillPath.move(to: CGPoint(x: first.x, y: graphRect.minY))
            for pt in points {
                fillPath.addLine(to: pt)
            }
            fillPath.addLine(to: CGPoint(x: last.x, y: graphRect.minY))
            fillPath.closeSubpath()

            context.saveGState()
            context.addPath(fillPath)
            context.clip()

            let colorSpace = CGColorSpaceCreateDeviceRGB()
            let gradient = CGGradient(colorsSpace: colorSpace,
                                      colors: [
                                        NSColor.green.withAlphaComponent(0.02).cgColor,
                                        NSColor.green.withAlphaComponent(0.35).cgColor
                                      ] as CFArray,
                                      locations: [0.0, 1.0])!

            context.drawLinearGradient(gradient,
                                       start: CGPoint(x: 0, y: graphRect.minY + 1),
                                       end: CGPoint(x: 0, y: graphRect.maxY),
                                       options: [])
            context.restoreGState()
        }

        // Ligne principale
        context.setStrokeColor(NSColor.green.cgColor)
        context.setLineWidth(2.0)
        context.beginPath()
        context.addLines(between: points)
        context.strokePath()

        // Labels des dates
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "MM/dd"

        let dateStep = max(1, validPrices.count / 5)
        for i in stride(from: 0, to: validPrices.count, by: dateStep) {
            let date = validPrices[i].date
            let xRatio = CGFloat(date.timeIntervalSince(minDate) / dateRange)
            let x = graphRect.minX + xRatio * graphRect.width
            let label = dateFormatter.string(from: date) as NSString
            let size = label.size(withAttributes: labelAttributes)
            label.draw(at: CGPoint(x: x - size.width / 2, y: graphRect.minY - size.height - 5),
                       withAttributes: labelAttributes)
        }

        // Labels des valeurs avec positionnement amélioré
        for i in 0...gridLineCount {
            let value = minValue + (Double(i) / Double(gridLineCount)) * valueRange
            let y = graphRect.minY + CGFloat(i) / CGFloat(gridLineCount) * graphRect.height
            let label = String(format: "%.2f", value) as NSString
            let size = label.size(withAttributes: labelAttributes)
            
            // Alignement à droite par rapport à la zone graphique
            label.draw(at: CGPoint(x: graphRect.minX - size.width - 5, y: y - size.height / 2),
                       withAttributes: labelAttributes)
        }

        // Axes
        context.setStrokeColor(NSColor.white.cgColor)
        context.setLineWidth(1.0)
        context.move(to: CGPoint(x: graphRect.minX, y: graphRect.minY))
        context.addLine(to: CGPoint(x: graphRect.minX, y: graphRect.maxY))
        context.move(to: CGPoint(x: graphRect.minX, y: graphRect.minY))
        context.addLine(to: CGPoint(x: graphRect.maxX, y: graphRect.minY))
        context.strokePath()
    }
}
