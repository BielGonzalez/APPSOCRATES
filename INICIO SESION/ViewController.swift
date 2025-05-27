import UIKit
import QuickLook

class ViewController: UIViewController, UITableViewDelegate, UITableViewDataSource, QLPreviewControllerDataSource {
    
    var tableView: UITableView!
    var files: [String] = []
    var deviceName: String = ""
    var previewFileURL: URL?
    var activityIndicator: UIActivityIndicatorView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        fetchFiles()
    }
    
    func setupUI() {
        // Configurar TableView
        tableView = UITableView(frame: view.bounds, style: .plain)
        tableView.delegate = self
        tableView.dataSource = self
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "Cell")
        view.addSubview(tableView)
        
        // Configurar ActivityIndicator
        activityIndicator = UIActivityIndicatorView(activityIndicatorStyle: .gray)
        activityIndicator.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(activityIndicator)
        NSLayoutConstraint.activate([
            activityIndicator.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            activityIndicator.centerYAnchor.constraint(equalTo: view.centerYAnchor)
            ])
    }
    
    func fetchFiles() {
        deviceName = UIDevice.current.name
        print("Nombre del dispositivo original: \(deviceName)")
        
        // Eliminar espacios y caracteres especiales, manteniendo solo alfanuméricos
        let validDeviceName = deviceName.components(separatedBy: CharacterSet.alphanumerics.inverted)
            .joined(separator: "")
        print("Nombre del dispositivo procesado: \(validDeviceName)")
        
        // Mostrar indicador de carga
        DispatchQueue.main.async {
            self.activityIndicator.startAnimating()
        }
        
        let encodedDeviceName = validDeviceName.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed)!
        let url = URL(string: "http://192.168.1.100:3000/files/\(encodedDeviceName)")!
        let task = URLSession.shared.dataTask(with: url) { data, response, error in
            // Ocultar indicador de carga
            DispatchQueue.main.async {
                self.activityIndicator.stopAnimating()
            }
            
            if let error = error {
                print("Error: \(error)")
                return
            }
            if let httpResponse = response as? HTTPURLResponse {
                if httpResponse.statusCode == 200 {
                    if let data = data {
                        do {
                            if let files = try JSONSerialization.jsonObject(with: data, options: []) as? [String] {
                                DispatchQueue.main.async {
                                    self.files = files
                                    self.tableView.reloadData()
                                }
                            } else {
                                print("Formato JSON inválido")
                            }
                        } catch {
                            print("Error al parsear JSON: \(error)")
                        }
                    }
                } else {
                    print("Código de estado HTTP: \(httpResponse.statusCode)")
                }
            }
        }
        task.resume()
    }
    
    func getUniqueFileURL(for fileName: String, in directory: URL) -> URL {
        let fileExtension = (fileName as NSString).pathExtension
        let baseName = (fileName as NSString).deletingPathExtension
        var destinationURL = directory.appendingPathComponent(fileName)
        var counter = 1
        
        // Si el archivo ya existe, generar un nombre único
        while FileManager.default.fileExists(atPath: destinationURL.path) {
            let newFileName = "\(baseName) (\(counter)).\(fileExtension)"
            destinationURL = directory.appendingPathComponent(newFileName)
            counter += 1
        }
        
        return destinationURL
    }
    
    @objc func downloadFile(sender: UIButton) {
        let index = sender.tag
        let fileName = files[index]
        print("Descargando archivo: \(fileName)")
        
        let validDeviceName = deviceName.components(separatedBy: CharacterSet.alphanumerics.inverted)
            .joined(separator: "")
        let encodedDeviceName = validDeviceName.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed)!
        let encodedFileName = fileName.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed)!
        let url = URL(string: "http://192.168.1.100:3000/files/\(encodedDeviceName)/\(encodedFileName)")!
        
        let task = URLSession.shared.downloadTask(with: url) { location, response, error in
            if let error = error {
                print("Error al descargar: \(error)")
                return
            }
            if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode != 200 {
                print("Código de estado HTTP: \(httpResponse.statusCode)")
                return
            }
            if let location = location {
                let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
                let destinationURL = self.getUniqueFileURL(for: fileName, in: documentsURL)
                do {
                    try FileManager.default.moveItem(at: location, to: destinationURL)
                    DispatchQueue.main.async {
                        print("Archivo descargado en: \(destinationURL.path)")
                        let alert = UIAlertController(title: "Éxito", message: "Archivo \(fileName) descargado.", preferredStyle: .alert)
                        alert.addAction(UIAlertAction(title: "OK", style: .default))
                        self.present(alert, animated: true)
                    }
                } catch {
                    print("Error al mover archivo: \(error)")
                }
            }
        }
        task.resume()
    }
    
    @objc func previewFile(sender: UIButton) {
        let index = sender.tag
        let fileName = files[index]
        print("Previsualizando archivo: \(fileName)")
        
        let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let fileURL = documentsURL.appendingPathComponent(fileName)
        
        if FileManager.default.fileExists(atPath: fileURL.path) {
            previewFileURL = fileURL
            let previewController = QLPreviewController()
            previewController.dataSource = self
            present(previewController, animated: true)
        } else {
            let alert = UIAlertController(title: "Error", message: "El archivo \(fileName) no está descargado. Descárguelo primero.", preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "OK", style: .default))
            self.present(alert, animated: true)
        }
    }
    
    // Métodos del QLPreviewControllerDataSource
    func numberOfPreviewItems(in controller: QLPreviewController) -> Int {
        return 1
    }
    
    func previewController(_ controller: QLPreviewController, previewItemAt index: Int) -> QLPreviewItem {
        return previewFileURL! as QLPreviewItem
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return files.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "Cell", for: indexPath)
        cell.textLabel?.text = files[indexPath.row]
        
        // Configurar botones de descargar y previsualizar
        let downloadButton = UIButton(type: .system)
        downloadButton.setTitle("Descargar", for: .normal)
        downloadButton.tag = indexPath.row
        downloadButton.addTarget(self, action: #selector(downloadFile), for: .touchUpInside)
        downloadButton.sizeToFit()
        
        let previewButton = UIButton(type: .system)
        previewButton.setTitle("Vista Previa", for: .normal)
        previewButton.tag = indexPath.row
        previewButton.addTarget(self, action: #selector(previewFile), for: .touchUpInside)
        previewButton.sizeToFit()
        
        // Configurar UIStackView
        let stackView = UIStackView(arrangedSubviews: [downloadButton, previewButton])
        stackView.axis = .horizontal
        stackView.spacing = 8
        stackView.distribution = .fill
        stackView.alignment = .center
        
        // Ajustar tamaño del stackView según su contenido
        stackView.frame = CGRect(x: 0, y: 0, width: downloadButton.frame.width + previewButton.frame.width + 8, height: max(downloadButton.frame.height, previewButton.frame.height))
        stackView.translatesAutoresizingMaskIntoConstraints = true // Usar frame en lugar de restricciones
        
        cell.accessoryView = stackView
        
        return cell
    }
}
