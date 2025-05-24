import Cocoa

var graphView: GraphView!
var tickerField: NSTextField!
var shortNameField: NSTextField!

class AppDelegate: NSObject, NSApplicationDelegate, NSTextFieldDelegate {
    var window: NSWindow!
    var currentPeriod: String = "ytd" // Période par défaut
    
    func applicationDidFinishLaunching1(_ notification: Notification) {
        let contentRect = NSRect(x: 0, y: 0, width: 800, height: 600)
        window = NSWindow(contentRect: contentRect,
                          styleMask: [.titled, .closable, .resizable],
                          backing: .buffered,
                          defer: false)
        window.center()
        window.title = "Graphique du cours de l'action"
        let view = GraphView()
        loadDataFromYahoo(from: "373220.KS",into: view)
        window.contentView = view
        window.makeKeyAndOrderFront(nil)
    }
    
    @objc func searchButtonClicked() {
        let ticker = tickerField.stringValue.uppercased()
        loadDataFromYahoo(from: ticker, into: graphView)
    }
    
    @objc func periodButtonClicked(_ sender: NSButton) {
        currentPeriod = sender.title.lowercased()
        let ticker = tickerField.stringValue.isEmpty ? "0P0001KVR5.F" : tickerField.stringValue.uppercased()
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
        let contentRect = NSRect(x: 0, y: 0, width: 900, height: 650) // Légèrement plus large pour les boutons
        window = NSWindow(contentRect: contentRect,
                          styleMask: [.titled, .closable, .resizable],
                          backing: .buffered,
                          defer: false)
        window.center()
        window.title = ""
        //window.title = shortNameField.stringValue

        // Créer le champ ticker et bouton de recherche
        tickerField = NSTextField(string: "0P0001KVR5.F")
        tickerField.placeholderString = "Ticker"
        tickerField.frame.size.width = 150
        tickerField.delegate = self
        
        shortNameField = NSTextField(string: "Test")
        shortNameField.placeholderString = "shortName"
        shortNameField.frame.size.width = 150
        shortNameField.delegate = self
        let searchButton = NSButton(title: "Charger", target: self, action: #selector(searchButtonClicked))

        // Créer les boutons de période
        let periods = ["1d", "1w", "1mo", "3mo", "6mo","ytd", "1y", "2y", "3y", "5y","max"]
        var periodButtons: [NSButton] = []
        
        for period in periods {
            let button = NSButton(title: period, target: self, action: #selector(periodButtonClicked(_:)))
            button.bezelStyle = .rounded
            button.controlSize = .small
            periodButtons.append(button)
        }

        graphView = GraphView()

        // Stack horizontale pour le champ texte + bouton de recherche
        let searchBar = NSStackView()
        searchBar.orientation = .horizontal
        searchBar.spacing = 8
        searchBar.addArrangedSubview(tickerField)
        searchBar.addArrangedSubview(shortNameField)
        searchBar.addArrangedSubview(searchButton)

        // Stack horizontale pour les boutons de période
        let periodBar = NSStackView()
        periodBar.orientation = .horizontal
        periodBar.spacing = 4
        periodBar.alignment = .centerY
        
        // Ajouter un label pour clarifier
        let periodLabel = NSTextField(labelWithString: "Période:")
        periodLabel.font = NSFont.systemFont(ofSize: 12)
        periodBar.addArrangedSubview(periodLabel)
        
        for button in periodButtons {
            periodBar.addArrangedSubview(button)
        }

        // Stack principale contenant la barre de recherche, les boutons de période et le graphique
        let topControls = NSStackView()
        topControls.orientation = .vertical
        topControls.spacing = 8
        topControls.edgeInsets = NSEdgeInsets(top: 8, left: 8, bottom: 8, right: 8)
        topControls.addArrangedSubview(searchBar)
        topControls.addArrangedSubview(periodBar)

        let mainStack = NSStackView()
        mainStack.orientation = .vertical
        mainStack.translatesAutoresizingMaskIntoConstraints = false
        mainStack.addArrangedSubview(topControls)
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

        // Charger les données initiales avec la période par défaut
        loadDataFromYahoo(from: "0P0001KVR5.F", into: graphView)
    }

    func loadDataFromYahoo(from ticker: String, into graphView: GraphView) {
        // Utiliser la période courante au lieu de "ytd" en dur
        guard let url = URL(string: "https://query1.finance.yahoo.com/v8/finance/chart/\(ticker)?interval=1d&range=\(currentPeriod)") else {
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
                //self.window.title=result.meta.shortName
                DispatchQueue.main.async {
                    self.window.title = result.meta.shortName
                }

                let closes = result.indicators.quote.first?.close ?? []

                var prices: [StockPrice] = []
                for (i, close) in closes.enumerated() {
                    if let value = close, i < timestamps.count {
                        let date = Date(timeIntervalSince1970: TimeInterval(timestamps[i]))
                        prices.append(StockPrice(date: date, value: value))
                    }
                }

                DispatchQueue.main.async {
                    graphView.setData(prices)
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
