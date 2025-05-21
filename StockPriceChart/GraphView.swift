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

        // Dessiner axes
        context.setStrokeColor(NSColor.black.cgColor)
        context.setLineWidth(1.0)
        context.move(to: CGPoint(x: graphRect.minX, y: graphRect.minY))
        context.addLine(to: CGPoint(x: graphRect.minX, y: graphRect.maxY))
        context.move(to: CGPoint(x: graphRect.minX, y: graphRect.minY))
        context.addLine(to: CGPoint(x: graphRect.maxX, y: graphRect.minY))
        context.strokePath()

        // Extraire valeurs
        let dates = stockPrices.map { $0.date }
        let values = stockPrices.map { $0.value }

        guard let minDate = dates.min(), let maxDate = dates.max(),
              let minValue = values.min(), let maxValue = values.max() else { return }

        let dateRange = maxDate.timeIntervalSince(minDate)
        let valueRange = maxValue - minValue

        // Tracer ligne
        context.setStrokeColor(NSColor.systemBlue.cgColor)
        context.setLineWidth(2.0)

        for (index, point) in stockPrices.enumerated() {
            let xRatio = CGFloat(point.date.timeIntervalSince(minDate) / dateRange)
            let yRatio = CGFloat((point.value - minValue) / valueRange)

            let x = graphRect.minX + xRatio * graphRect.width
            let y = graphRect.minY + yRatio * graphRect.height

            if index == 0 {
                context.move(to: CGPoint(x: x, y: y))
            } else {
                context.addLine(to: CGPoint(x: x, y: y))
            }
        }

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

