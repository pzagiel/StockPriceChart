import Cocoa

class GraphWindowController: NSWindowController {

    @IBOutlet weak var tickerField: NSTextField!
    @IBOutlet weak var graphView: GraphView!
    @IBOutlet weak var periodStackView: NSStackView!

    var currentPeriod = "ytd"

    convenience init() {
        self.init(windowNibName: "GraphWindow")
    }

    override func windowDidLoad() {
        super.windowDidLoad()

        setupPeriodButtons()
        tickerField.stringValue = "0P0001KVR5.F"
        loadDataFromYahoo()
    }

    func setupPeriodButtons() {
        let periods = ["1d", "1w", "1mo", "3mo", "6mo", "ytd", "1y", "2y", "3y", "5y", "max"]
        for period in periods {
            let button = NSButton(title: period, target: self, action: #selector(periodButtonClicked(_:)))
            button.setButtonType(.pushOnPushOff)
            button.bezelStyle = .regularSquare
            button.state = (period == currentPeriod) ? .on : .off
            periodStackView.addArrangedSubview(button)
        }
    }

    @IBAction func loadButtonClicked(_ sender: Any) {
        loadDataFromYahoo()
    }

    @objc func periodButtonClicked(_ sender: NSButton) {
        for case let b as NSButton in periodStackView.arrangedSubviews {
            b.state = .off
        }
        sender.state = .on
        currentPeriod = sender.title.lowercased()
        loadDataFromYahoo()
    }

    func loadDataFromYahoo() {
        let ticker = tickerField.stringValue.uppercased()
        guard let url = URL(string: "https://query1.finance.yahoo.com/v8/finance/chart/\(ticker)?interval=1d&range=\(currentPeriod)") else {
            print("URL invalide")
            return
        }

        let task = URLSession.shared.dataTask(with: url) { data, _, error in
            if let error = error {
                print("Erreur réseau: \(error)")
                return
            }

            guard let data = data else {
                print("Pas de données reçues")
                return
            }

            do {
                let decoded = try JSONDecoder().decode(YahooFinanceResponse.self, from: data)
                guard let result = decoded.chart.result.first else { return }
                let timestamps = result.timestamp
                let closes = result.indicators.quote.first?.close ?? []

                var prices: [StockPrice] = []
                for (i, close) in closes.enumerated() {
                    if let value = close, i < timestamps.count {
                        let date = Date(timeIntervalSince1970: TimeInterval(timestamps[i]))
                        prices.append(StockPrice(date: date, value: value))
                    }
                }

                DispatchQueue.main.async {
                    self.window?.title = result.meta.shortName
                    self.graphView.setData(prices)
                }

            } catch {
                print("Erreur décodage JSON : \(error)")
            }
        }

        task.resume()
    }
    deinit {
        print("🧼 GraphWindowController a été libéré")
    }

}

