import Cocoa
var graphView: GraphView!
var tickerField: NSTextField!






class AppDelegate: NSObject, NSApplicationDelegate, NSTextFieldDelegate {
    var window: NSWindow!

    
    
    
    func applicationDidFinishLaunching1(_ notification: Notification) {
        let contentRect = NSRect(x: 0, y: 0, width: 800, height: 600)
        window = NSWindow(contentRect: contentRect,
                          styleMask: [.titled, .closable, .resizable],
                          backing: .buffered,
                          defer: false)
        window.center()
        window.title = "Graphique du cours de l'action"
        let view = GraphView()
        loadDataFromYahoo(from: "BABA",into: view)
        window.contentView = view
        window.makeKeyAndOrderFront(nil)
    }
    @objc func searchButtonClicked() {
        let ticker = tickerField.stringValue.uppercased()
        loadDataFromYahoo(from: ticker, into: graphView)
    }
    func control(_ control: NSControl, textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
        if commandSelector == #selector(NSResponder.insertNewline(_:)) {
            searchButtonClicked()
            return true // Empêche le comportement par défaut (saut de ligne)
        }
        return false
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        let contentRect = NSRect(x: 0, y: 0, width: 800, height: 600)
        window = NSWindow(contentRect: contentRect,
                          styleMask: [.titled, .closable, .resizable],
                          backing: .buffered,
                          defer: false)
        window.center()
        window.title = "Graphique du cours de l'action"

        // Créer les sous-vues
        tickerField = NSTextField(string: "BABA")
        tickerField.placeholderString = "Ticker"
        tickerField.frame.size.width = 100
        tickerField.delegate = self

        let searchButton = NSButton(title: "Charger", target: self, action: #selector(searchButtonClicked))

        graphView = GraphView()

        // Stack horizontale pour le champ texte + bouton
        let topBar = NSStackView()
        topBar.orientation = .horizontal
        topBar.spacing = 8
        topBar.edgeInsets = NSEdgeInsets(top: 8, left: 8, bottom: 8, right: 8)
        topBar.addArrangedSubview(tickerField)
        topBar.addArrangedSubview(searchButton)

        // Stack verticale contenant la topBar et le graphique
        let mainStack = NSStackView()
        mainStack.orientation = .vertical
        mainStack.translatesAutoresizingMaskIntoConstraints = false
        mainStack.addArrangedSubview(topBar)
        mainStack.addArrangedSubview(graphView)

        // Vue container
        let containerView = NSView()
        containerView.addSubview(mainStack)

        // Contraintes
        NSLayoutConstraint.activate([
            mainStack.topAnchor.constraint(equalTo: containerView.topAnchor),
            mainStack.bottomAnchor.constraint(equalTo: containerView.bottomAnchor),
            mainStack.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            mainStack.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
        ])

        window.contentView = containerView
        window.makeKeyAndOrderFront(nil)

        // Charger les données initiales
        loadDataFromYahoo(from: "BABA", into: graphView)
    }


    
    func loadDataFromYahoo(from ticker: String, into graphView: GraphView) {
        print("https://query1.finance.yahoo.com/v8/finance/chart/\(ticker)?interval=1d&range=1mo")
        guard let url = URL(string: "https://query1.finance.yahoo.com/v8/finance/chart/\(ticker)?interval=1d&range=ytd") else {
            print("URL invalide")
            return
        }
      


        let task = URLSession.shared.dataTask(with: url) { data, response, error in
            if let error = error {
                print("Erreur réseau: \(error)")
                return
            }

            guard let data = data else {
                print("Pas de données reçues")
                return
            }
            if let jsonString = String(data: data, encoding: .utf8) {
                  print("Réponse JSON brute :\n\(jsonString)")
              }
            do {
                let decoded = try JSONDecoder().decode(YahooFinanceResponse.self, from: data)
                guard let result = decoded.chart.result.first else {
                    print("Pas de résultat dans la réponse")
                    return
                }

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
                    graphView.setData(prices) // <-- Ici, `setData` doit accepter un tableau de StockPrice avec des Date
                }

            } catch {
                print("Erreur de décodage JSON : \(error)")
            }
        }

        task.resume()
    }


  
    
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return true
    }
    
}
