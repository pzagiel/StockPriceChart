import Cocoa
import AVFoundation

var graphView: GraphView!
var tickerField: NSTextField!
var periodButtons: [NSButton] = [] // Ajout pour garder une référence aux boutons
var shutterPlayer: AVAudioPlayer?
//var shortNameField: NSTextField!

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
        // Réinitialiser tous les boutons à l'état normal (non enfoncés)
        for button in periodButtons {
            button.state = .off
        }
        
        // Mettre le bouton cliqué en état enfoncé
        sender.state = .on
        
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
        //tickerField.frame.size.width = 150
        tickerField.delegate = self
        //tickerField.setContentHuggingPriority(.defaultHigh, for: .horizontal)
        //tickerField.setContentCompressionResistancePriority(.defaultHigh, for: .horizontal)
        
        //shortNameField = NSTextField(string: "Test")
        //shortNameField.placeholderString = "shortName"
        //shortNameField.frame.size.width = 150
        //shortNameField.frame.size.height = 24
        //shortNameField.translatesAutoresizingMaskIntoConstraints = false
        //shortNameField.heightAnchor.constraint(equalToConstant: 24).isActive = true
        //shortNameField.widthAnchor.constraint(greaterThanOrEqualToConstant: 100).isActive = true
        //shortNameField.setContentHuggingPriority(.defaultLow, for: .horizontal)
        //shortNameField.setContentCompressionResistancePriority(.defaultHigh, for: .horizontal)

        //shortNameField.delegate = self
        //shortNameField.setContentHuggingPriority(.defaultLow, for: .horizontal)
        //shortNameField.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        //shortNameField.translatesAutoresizingMaskIntoConstraints = false
        //shortNameField.setContentHuggingPriority(.defaultHigh, for: .horizontal)
        //shortNameField.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        //shortNameField.widthAnchor.constraint(equalToConstant: 150).isActive = true
        //shortNameField.heightAnchor.constraint(equalToConstant: 24).isActive = true
        
        
        let searchButton = NSButton(title: "Charger", target: self, action: #selector(searchButtonClicked))
        searchButton.setContentHuggingPriority(.required, for: .horizontal)
        searchButton.setContentCompressionResistancePriority(.required, for: .horizontal)
        
        // Créer les boutons de période
        let periods = ["1d", "1w", "1mo", "3mo", "6mo","ytd", "1y", "2y", "3y", "5y","max"]
        periodButtons = [] // Réinitialiser le tableau
        
        for period in periods {
            let button = NSButton(title: period, target: self, action: #selector(periodButtonClicked(_:)))
            button.bezelStyle = .regularSquare  // rounded
            //button.controlSize = .small
            button.isBordered = true
            button.setButtonType(.pushOnPushOff) // Type de bouton qui reste enfoncé
            
            // Marquer le bouton par défaut comme actif (enfoncé)
            if period == currentPeriod {
                button.state = .on
            } else {
                button.state = .off
            }
            
            periodButtons.append(button)
        }

        graphView = GraphView()

        // Stack horizontale pour le champ texte + bouton de recherche
        let searchBar = NSStackView()
        searchBar.orientation = .horizontal
        searchBar.spacing = 8
        searchBar.addArrangedSubview(tickerField)
        //searchBar.addArrangedSubview(shortNameField)
        searchBar.addArrangedSubview(searchButton)
        //searchBar.wantsLayer = true
        //searchBar.layer?.backgroundColor = NSColor.red.cgColor
        

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

        let mainMenu = NSMenu()

        // Menu "Application"
        let appMenuItem = NSMenuItem()
        mainMenu.addItem(appMenuItem)

        let appMenu = NSMenu()
        appMenuItem.submenu = appMenu
        appMenu.title = "Stock Price Chart"

        appMenu.addItem(
            withTitle: "About Stock Price Chart",
            action: #selector(showAboutWindow),
            keyEquivalent: ""
        )
        appMenu.addItem(NSMenuItem.separator())
        appMenu.addItem(
            withTitle: "Hide Stock Price Chart",
            action: #selector(NSApplication.hide(_:)),
            keyEquivalent: "h"
        ).keyEquivalentModifierMask = [.command]
        
        appMenu.addItem(
            withTitle: "Hide Others",
            action: #selector(NSApplication.hideOtherApplications(_:)),
            keyEquivalent: "h"
        ).keyEquivalentModifierMask = [.command, .option]

        appMenu.addItem(
            withTitle: "Show All",
            action: #selector(NSApplication.unhideAllApplications(_:)),
            keyEquivalent: ""
        )


        appMenu.addItem(NSMenuItem.separator())
        appMenu.addItem(
            withTitle: "Quit Stock Price Chart",
            action: #selector(quit),
            keyEquivalent: "q"
        ).keyEquivalentModifierMask = [.command]

        
        // Menu "File"
        let fileMenuItem = NSMenuItem()
        mainMenu.addItem(fileMenuItem)
        let fileMenu = NSMenu(title: "File")
        fileMenuItem.submenu = fileMenu
        fileMenu.addItem(
            withTitle: "New Chart",
            action: #selector(newWindow),
            keyEquivalent: "n"
        ).keyEquivalentModifierMask = [.command]
        
        
        
        // Menu "Édition"
        let editMenuItem = NSMenuItem()
        mainMenu.addItem(editMenuItem)

        let editMenu = NSMenu(title: "Edit")
        editMenuItem.submenu = editMenu
        
        // Copy menu item
        let copyItem = editMenu.addItem(
            withTitle: "Copy",
            action: Selector(("copy:")),
            keyEquivalent: "c"
        )
        copyItem.target = nil
        copyItem.keyEquivalentModifierMask = [.command]
        
        editMenu.addItem(
            withTitle: "Copy as PDF",
            action: #selector(copyGraphAsPDF),
            keyEquivalent: "c"
        ).keyEquivalentModifierMask = [.command, .option]
        
        // Menu "Window"
        let windowMenuItem = NSMenuItem()
        mainMenu.addItem(windowMenuItem)

        let windowMenu = NSMenu(title: "Window")
        windowMenuItem.submenu = windowMenu

        let closeItem = NSMenuItem(
            title: "Close",
            action: #selector(NSWindow.performClose(_:)),
            keyEquivalent: "w"
        )
        closeItem.keyEquivalentModifierMask = [.command]
        closeItem.target = nil // Important : First Responder
        windowMenu.addItem(closeItem)

        let mergeItem = NSMenuItem(
            title: "Merge All Windows",
            action: #selector(NSWindow.mergeAllWindows(_:)),
            keyEquivalent: "m"
        )
        mergeItem.keyEquivalentModifierMask = [.command, .control]
        mergeItem.target = nil // First Responder
        windowMenu.addItem(mergeItem)

        
        NSApp.mainMenu = mainMenu
        
      

        
        // Charger les données initiales avec la période par défaut
        loadDataFromYahoo(from: "0P0001KVR5.F", into: graphView)
    }
    
    var windowControllers: [GraphWindowController] = []

    @objc func newWindow() {
        let controller = GraphWindowController(windowNibName: "GraphWindow")
        windowControllers.append(controller)
        controller.showWindow(nil)

        // Créer une référence faible au contrôleur que l'on veut observer
        let controllerToObserve = controller

        // S'abonner à la notification de fermeture de la fenêtre du contrôleur
        NotificationCenter.default.addObserver(
            forName: NSWindow.willCloseNotification, // quand la fenêtre va se fermer
            object: controllerToObserve.window,      // seulement pour cette fenêtre précise
            queue: .main                             // on veut exécuter le bloc sur le thread principal
        ) { [weak self, weak controllerToObserve] notification in

            // Vérifier que self et controllerToObserve existent encore
            guard let strongSelf = self,
                  let strongController = controllerToObserve else {
                // Si l’un a été libéré, on sort proprement
                return
            }

            // Supprimer ce contrôleur du tableau des fenêtres ouvertes
            strongSelf.windowControllers.removeAll { $0 == strongController }

            // Afficher un message de nettoyage
            print("🧼 GraphWindowController supprimé du tableau")
        }


        
        
        /* NotificationCenter.default.addObserver(forName: NSWindow.willCloseNotification, object: controller.window, queue: .main) { [weak self] _ in
            self?.windowControllers.removeAll { $0 == controller }
        } */
        
        if #available(macOS 10.14, *) {
                   NSApp.appearance = NSAppearance(named: .darkAqua)
               } else {
                   // Sur 10.12 ou 10.13, ignorer (pas de mode sombre système)
                   // Tu peux éventuellement personnaliser les couleurs manuellement ici.
               }
    }
   
    
    @objc func showAboutWindow() {
        let alert = NSAlert()
        alert.messageText = "Stock Price Chart"
        alert.informativeText = "Prototype stock price chart component.\nVersion 0.1.\nCreated by Patrick Zagiel 2025"
        alert.alertStyle = .informational
        alert.runModal()
    }

    @objc func quit() {
        NSApp.terminate(nil)
    }
    @objc func copyGraph() {
        graphView.copy()
        //NSSound(named: NSSound.Name("Glass"))?.play()
        playShutterSound()
    }
    
    func playShutterSound() {
        guard let url = Bundle.main.url(forResource: "PhotoShutterIPhone", withExtension: "aiff") else {
            print("⚠️ Son non trouvé dans le bundle")
            return
        }

        do {
            shutterPlayer = try AVAudioPlayer(contentsOf: url)
            shutterPlayer?.prepareToPlay()
            shutterPlayer?.play()
        } catch {
            print("❌ Erreur de lecture audio : \(error)")
        }
    }
    @objc func copyGraphAsPDF() {
        let bounds = graphView.bounds

        let pdfData = NSMutableData()
        var mediaBox = bounds

        guard let consumer = CGDataConsumer(data: pdfData as CFMutableData),
              let pdfContext = CGContext(consumer: consumer, mediaBox: &mediaBox, nil) else {
            print("Erreur création contexte PDF")
            return
        }

        // Créer un contexte NSGraphicsContext lié au contexte PDF
        let graphicsContext = NSGraphicsContext(cgContext: pdfContext, flipped: false)
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = graphicsContext

        // Commencer une page PDF
        pdfContext.beginPDFPage(nil)

        // ⚠️ Appeler explicitement draw() sur ta vue
        graphView.draw(bounds)

        // Terminer la page
        pdfContext.endPDFPage()

        // Nettoyage
        NSGraphicsContext.restoreGraphicsState()
        pdfContext.closePDF()

        // Copier le PDF dans le presse-papiers
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()

        let item = NSPasteboardItem()
        item.setData(pdfData as Data, forType: .pdf)
        pasteboard.writeObjects([item])
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
    
 /*   func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return true
    }*/
}
