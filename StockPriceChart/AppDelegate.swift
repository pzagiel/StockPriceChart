import Cocoa







class AppDelegate: NSObject, NSApplicationDelegate {
    var window: NSWindow!

    
    
    
    func applicationDidFinishLaunching(_ notification: Notification) {
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
