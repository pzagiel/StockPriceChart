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
        loadData(into: view)
        window.contentView = view
        window.makeKeyAndOrderFront(nil)
    }
    
    func loadData(into graphView: GraphView) {
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
            if let prices = stock.first?.price {
                graphView.setData(prices)
            }
        } catch {
            print("Erreur de décodage JSON : \(error)")
        }
    }

    
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return true
    }
    
}
