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

        // Fonction pour calculer un intervalle "propre"
        func calculateNiceInterval(_ range: Double, _ targetTicks: Int) -> Double {
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
        
        // Calculer les valeurs "propres" pour les labels
        let minTicks = 4  // Minimum de lignes souhaitées
        let maxTicks = 6  // Maximum de lignes souhaitées
        let valueRange = maxValue - minValue
        
        // Essayer différents nombres de ticks pour trouver le meilleur
        var bestInterval = 0.0
        var bestTickCount = 0
        
        for targetTicks in minTicks...maxTicks {
            let interval = calculateNiceInterval(valueRange, targetTicks)
            let niceMin = floor(minValue / interval) * interval
            let niceMax = ceil(maxValue / interval) * interval
            let actualTicks = Int((niceMax - niceMin) / interval) + 1
            
            // Privilégier les configurations qui donnent un nombre raisonnable de ticks
            if actualTicks >= minTicks && actualTicks <= maxTicks {
                bestInterval = interval
                bestTickCount = actualTicks
                break
            } else if bestInterval == 0.0 { // Garder la première option comme fallback
                bestInterval = interval
                bestTickCount = actualTicks
            }
        }
        
        let niceInterval = bestInterval
        let niceMin = floor(minValue / niceInterval) * niceInterval
        let niceMax = ceil(maxValue / niceInterval) * niceInterval
        
        // Générer les valeurs de ticks "propres"
        var tickValues: [Double] = []
        var current = niceMin
        while current <= niceMax + niceInterval * 0.001 { // Petite tolérance pour éviter les erreurs de floating point
            if current >= minValue - niceInterval * 0.1 {
                tickValues.append(current)
            }
            current += niceInterval
        }
        
        let labelAttributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 10),
            .foregroundColor: NSColor.white
        ]
        
        var maxLabelWidth: CGFloat = 0
        
        // Calculer la largeur maximale nécessaire pour tous les labels de valeurs
        for value in tickValues {
            let label: String
            if niceInterval >= 1.0 {
                label = String(format: "%.0f", value)
            } else if niceInterval >= 0.1 {
                label = String(format: "%.1f", value)
            } else {
                label = String(format: "%.2f", value)
            }
            let labelString = label as NSString
            let size = labelString.size(withAttributes: labelAttributes)
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

        // Grille horizontale basée sur les valeurs "propres"
        context.setStrokeColor(NSColor.darkGray.cgColor)
        context.setLineWidth(0.5)

        for value in tickValues {
            let yRatio = CGFloat((value - minValue) / valueRange)
            let y = graphRect.minY + yRatio * graphRect.height
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

        // Labels des valeurs avec positionnement amélioré (on skip la première valeur si c'est le minimum)
        for (index, value) in tickValues.enumerated() {
            // Skip le premier label s'il correspond au minimum (sur l'axe horizontal)
            if index == 0 && abs(value - minValue) < 0.001 {
                continue
            }
            
            let yRatio = CGFloat((value - minValue) / valueRange)
            let y = graphRect.minY + yRatio * graphRect.height
            
            let label: String
            if niceInterval >= 1.0 {
                label = String(format: "%.0f", value)
            } else if niceInterval >= 0.1 {
                label = String(format: "%.1f", value)
            } else {
                label = String(format: "%.2f", value)
            }
            
            let labelString = label as NSString
            let size = labelString.size(withAttributes: labelAttributes)
            
            // Alignement à droite par rapport à la zone graphique
            labelString.draw(at: CGPoint(x: graphRect.minX - size.width - 5, y: y - size.height / 2),
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
