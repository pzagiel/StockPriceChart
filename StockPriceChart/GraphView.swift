import Cocoa

struct StockPrice: Decodable {
    let dateTime: String
    let value: Double
    var date: Date {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.date(from: dateTime) ?? Date()
    }
}

struct StockData: Decodable {
    let price: [StockPrice]
    let ticker: String
}

class GraphView: NSView {
    private var stockPrices: [StockPrice] = []

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        self.wantsLayer = true
        loadData()
    }

    required init?(coder decoder: NSCoder) {
        super.init(coder: decoder)
        self.wantsLayer = true
        loadData()
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        guard !stockPrices.isEmpty else { return }

        guard let context = NSGraphicsContext.current?.cgContext else { return }

        let margin: CGFloat = 50
        let graphRect = bounds.insetBy(dx: margin, dy: margin)

        // 🔲 Fond noir
        context.setFillColor(NSColor.black.cgColor)
        context.fill(bounds)

        // 📊 Extraire les données
        let dates = stockPrices.map { $0.date }
        let values = stockPrices.map { $0.value }

        guard let minDate = dates.min(),
              let maxDate = dates.max(),
              let minValue = values.min(),
              let maxValue = values.max() else { return }

        let dateRange = maxDate.timeIntervalSince(minDate)
        let valueRange = maxValue - minValue

        // 🧱 Grille horizontale
        context.setStrokeColor(NSColor.darkGray.cgColor)
        context.setLineWidth(0.5)

        let gridLineCount = 5
        for i in 0...gridLineCount {
            let y = graphRect.minY + CGFloat(i) / CGFloat(gridLineCount) * graphRect.height
            context.move(to: CGPoint(x: graphRect.minX, y: y))
            context.addLine(to: CGPoint(x: graphRect.maxX, y: y))
        }
        context.strokePath()

        // 📈 Tracer les points
        var points: [CGPoint] = []

        for point in stockPrices {
            let xRatio = CGFloat(point.date.timeIntervalSince(minDate) / dateRange)
            let yRatio = CGFloat((point.value - minValue) / valueRange)

            let x = graphRect.minX + xRatio * graphRect.width
            let y = graphRect.minY + yRatio * graphRect.height
            points.append(CGPoint(x: x, y: y))
        }

        // 🟧 Dégradé sous la courbe
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
                                      colors: [NSColor.orange.withAlphaComponent(0.4).cgColor,
                                               NSColor.clear.cgColor] as CFArray,
                                      locations: [0.0, 1.0])!

            context.drawLinearGradient(gradient,
                                       start: CGPoint(x: 0, y: graphRect.maxY),
                                       end: CGPoint(x: 0, y: graphRect.minY),
                                       options: [])
            context.restoreGState()
        }

        // 🟧 Ligne principale orange
        context.setStrokeColor(NSColor.orange.cgColor)
        context.setLineWidth(2.0)
        context.beginPath()
        context.addLines(between: points)
        context.strokePath()

        // 🔠 Abscisse : Dates
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "MM/dd"

        let labelAttributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 10),
            .foregroundColor: NSColor.white
        ]

        let dateStep = max(1, stockPrices.count / 5)

        for i in stride(from: 0, to: stockPrices.count, by: dateStep) {
            let date = stockPrices[i].date
            let xRatio = CGFloat(date.timeIntervalSince(minDate) / dateRange)
            let x = graphRect.minX + xRatio * graphRect.width
            let label = dateFormatter.string(from: date) as NSString
            let size = label.size(withAttributes: labelAttributes)
            label.draw(at: CGPoint(x: x - size.width / 2, y: graphRect.minY - size.height - 5),
                       withAttributes: labelAttributes)
        }

        // 🔢 Ordonnée : Valeurs
        for i in 0...gridLineCount {
            let value = minValue + (Double(i) / Double(gridLineCount)) * valueRange
            let y = graphRect.minY + CGFloat(i) / CGFloat(gridLineCount) * graphRect.height
            let label = String(format: "%.2f", value) as NSString
            let size = label.size(withAttributes: labelAttributes)
            label.draw(at: CGPoint(x: graphRect.minX - size.width - 5, y: y - size.height / 2),
                       withAttributes: labelAttributes)
        }

        // ⚫ Axes X et Y
        context.setStrokeColor(NSColor.white.cgColor)
        context.setLineWidth(1.0)
        context.move(to: CGPoint(x: graphRect.minX, y: graphRect.minY))
        context.addLine(to: CGPoint(x: graphRect.minX, y: graphRect.maxY))
        context.move(to: CGPoint(x: graphRect.minX, y: graphRect.minY))
        context.addLine(to: CGPoint(x: graphRect.maxX, y: graphRect.minY))
        context.strokePath()
    }



    // MARK: - Chargement du JSON
    private func loadData() {
        let json = """
        [
            {
                "price": [
                    {"dateTime": "2025-04-14", "value": 16.168},
                    {"dateTime": "2025-04-15", "value": 16.462},
                    {"dateTime": "2025-04-16", "value": 16.514},
                    {"dateTime": "2025-04-17", "value": 16.478},
                    {"dateTime": "2025-04-22", "value": 16.688},
                    {"dateTime": "2025-04-23", "value": 17.418},
                    {"dateTime": "2025-04-24", "value": 16.642},
                    {"dateTime": "2025-04-25", "value": 16.876},
                    {"dateTime": "2025-04-28", "value": 16.966},
                    {"dateTime": "2025-04-29", "value": 17.252},
                    {"dateTime": "2025-04-30", "value": 17.014},
                    {"dateTime": "2025-05-02", "value": 18.27},
                    {"dateTime": "2025-05-05", "value": 18.15},
                    {"dateTime": "2025-05-06", "value": 17.89},
                    {"dateTime": "2025-05-07", "value": 17.77},
                    {"dateTime": "2025-05-08", "value": 17.992},
                    {"dateTime": "2025-05-09", "value": 18.204},
                    {"dateTime": "2025-05-12", "value": 18.434}
                ],
                "ticker": "INGA:NA"
            }
        ]
        """
        let data = Data(json.utf8)
        do {
            let stock = try JSONDecoder().decode([StockData].self, from: data)
            self.stockPrices = stock.first?.price ?? []
        } catch {
            print("Erreur de décodage JSON : \(error)")
        }
    }
}

