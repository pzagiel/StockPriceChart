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
        NSColor.black.setFill()
        context.fill(bounds)

        // 🔲 Axes
        context.setStrokeColor(NSColor.white.cgColor)
        context.setLineWidth(1.0)
        context.move(to: CGPoint(x: graphRect.minX, y: graphRect.minY))
        context.addLine(to: CGPoint(x: graphRect.minX, y: graphRect.maxY))
        context.move(to: CGPoint(x: graphRect.minX, y: graphRect.minY))
        context.addLine(to: CGPoint(x: graphRect.maxX, y: graphRect.minY))
        context.strokePath()

        // 🔄 Valeurs
        let dates = stockPrices.map { $0.date }
        let values = stockPrices.map { $0.value }

        guard let minDate = dates.min(), let maxDate = dates.max(),
              let minValue = values.min(), let maxValue = values.max() else { return }

        let dateRange = maxDate.timeIntervalSince(minDate)
        let valueRange = maxValue - minValue

        // 🟧 Tracé de la courbe + remplissage
        var linePoints: [CGPoint] = []

        for point in stockPrices {
            let xRatio = CGFloat(point.date.timeIntervalSince(minDate) / dateRange)
            let yRatio = CGFloat((point.value - minValue) / valueRange)
            let x = graphRect.minX + xRatio * graphRect.width
            let y = graphRect.minY + yRatio * graphRect.height
            linePoints.append(CGPoint(x: x, y: y))
        }

        // 🟧 Dégradé sous la courbe
        if let first = linePoints.first, let last = linePoints.last {
            context.saveGState()
            let path = CGMutablePath()
            path.move(to: CGPoint(x: first.x, y: graphRect.minY))
            for point in linePoints {
                path.addLine(to: point)
            }
            path.addLine(to: CGPoint(x: last.x, y: graphRect.minY))
            path.closeSubpath()

            context.addPath(path)
            context.clip()

            let colorSpace = CGColorSpaceCreateDeviceRGB()
            let colors: [CGColor] = [
                NSColor.orange.withAlphaComponent(0.6).cgColor,
                NSColor.orange.withAlphaComponent(0.0).cgColor
            ]
            let locations: [CGFloat] = [0.0, 1.0]
            if let gradient = CGGradient(colorsSpace: colorSpace, colors: colors as CFArray, locations: locations) {
                context.drawLinearGradient(gradient,
                                           start: CGPoint(x: 0, y: graphRect.maxY),
                                           end: CGPoint(x: 0, y: graphRect.minY),
                                           options: [])
            }

            context.restoreGState()
        }

        // 🟧 Ligne principale en orange
        context.setStrokeColor(NSColor.orange.cgColor)
        context.setLineWidth(2.0)
        context.beginPath()
        for (i, pt) in linePoints.enumerated() {
            i == 0 ? context.move(to: pt) : context.addLine(to: pt)
        }
        context.strokePath()

        // 📈 Grille horizontale (ordonnée)
        let valueStep = (maxValue - minValue) / 5
        for i in 0...5 {
            let value = minValue + valueStep * Double(i)
            let yRatio = CGFloat((value - minValue) / valueRange)
            let y = graphRect.minY + yRatio * graphRect.height

            context.setStrokeColor(NSColor.darkGray.withAlphaComponent(0.4).cgColor)
            context.setLineWidth(0.5)
            context.move(to: CGPoint(x: graphRect.minX, y: y))
            context.addLine(to: CGPoint(x: graphRect.maxX, y: y))
            context.strokePath()

            // 🎯 Graduation
            let valueStr = String(format: "%.2f", value)
            let attrs: [NSAttributedString.Key: Any] = [
                .foregroundColor: NSColor.white,
                .font: NSFont.systemFont(ofSize: 10)
            ]
            let size = valueStr.size(withAttributes: attrs)
            let rect = CGRect(x: graphRect.minX - size.width - 4, y: y - size.height / 2, width: size.width, height: size.height)
            valueStr.draw(in: rect, withAttributes: attrs)
        }

        // 🗓 Abscisses : Dates
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "MM-dd"
        for i in stride(from: 0, to: stockPrices.count, by: 3) {
            let point = stockPrices[i]
            let xRatio = CGFloat(point.date.timeIntervalSince(minDate) / dateRange)
            let x = graphRect.minX + xRatio * graphRect.width
            let dateStr = dateFormatter.string(from: point.date)

            let attrs: [NSAttributedString.Key: Any] = [
                .foregroundColor: NSColor.white,
                .font: NSFont.systemFont(ofSize: 10)
            ]
            let size = dateStr.size(withAttributes: attrs)
            let rect = CGRect(x: x - size.width / 2, y: graphRect.minY - size.height - 4, width: size.width, height: size.height)
            dateStr.draw(in: rect, withAttributes: attrs)
        }
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

