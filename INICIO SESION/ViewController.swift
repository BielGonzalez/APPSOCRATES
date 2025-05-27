import UIKit
import QuickLook // Framework for previewing documents

// ViewController manages the main view of the application.
// It displays a list of files fetched from a server, allows downloading, and previewing them.
// It conforms to:
// - UITableViewDelegate: To handle interactions with the table view (e.g., row selection, though not used here for selection).
// - UITableViewDataSource: To provide data (file names and cells) to the table view.
// - QLPreviewControllerDataSource: To provide items for the QuickLook preview controller.
class ViewController: UIViewController, UITableViewDelegate, UITableViewDataSource, QLPreviewControllerDataSource {
    
    // MARK: - Properties
    
    // UI Elements (programmatically created, not IBOutlets)
    var tableView: UITableView! // Table view to display the list of files.
    var activityIndicator: UIActivityIndicatorView! // Shows loading activity while fetching files.
    
    // Data Source
    var files: [String] = [] // Array to store the names of files fetched from the server.
    
    // Helper Properties
    var deviceName: String = "" // Stores the current device's name, used for fetching files.
    var previewFileURL: URL? // URL of the file to be previewed by QLPreviewController.
    
    // MARK: - Lifecycle Methods
    
    // Called after the controller's view is loaded into memory.
    // This method is typically used for initial setup.
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI() // Initialize and configure UI elements.
        fetchFiles() // Fetch the list of files from the server.
    }
    
    // MARK: - UI Setup
    
    // Sets up the user interface elements programmatically.
    func setupUI() {
        // Configure TableView
        tableView = UITableView(frame: view.bounds, style: .plain) // Create a full-screen table view.
        tableView.delegate = self
        tableView.dataSource = self
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "Cell") // Register a default cell type.
        view.addSubview(tableView) // Add the table view to the main view.
        
        // Configure ActivityIndicator
        // The style was updated from .gray (deprecated) to .medium.
        activityIndicator = UIActivityIndicatorView(style: .medium)
        activityIndicator.translatesAutoresizingMaskIntoConstraints = false // Use Auto Layout.
        view.addSubview(activityIndicator)
        // Center the activity indicator in the view.
        NSLayoutConstraint.activate([
            activityIndicator.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            activityIndicator.centerYAnchor.constraint(equalTo: view.centerYAnchor)
            ])
    }
    
    // MARK: - Data Fetching
    
    // Fetches the list of files from the remote server.
    func fetchFiles() {
        // Get the current device name. This is used as part of the server URL.
        deviceName = UIDevice.current.name
        print("Nombre del dispositivo original: \(deviceName)") // Original device name for debugging.
        
        // Sanitize the device name: remove non-alphanumeric characters.
        // This is important for creating a valid URL path component.
        let validDeviceName = deviceName.components(separatedBy: CharacterSet.alphanumerics.inverted)
            .joined(separator: "")
        print("Nombre del dispositivo procesado: \(validDeviceName)") // Processed device name for debugging.
        
        // Show loading indicator on the main thread.
        DispatchQueue.main.async {
            self.activityIndicator.startAnimating()
        }
        
        // Encode the device name for URL safety.
        guard let encodedDeviceName = validDeviceName.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) else {
            print("Error: Could not encode device name.")
            DispatchQueue.main.async { self.activityIndicator.stopAnimating() }
            return
        }
        
        // Construct the URL to fetch files.
        // Note: The IP address 192.168.1.100 is hardcoded, suitable for local network testing.
        guard let url = URL(string: "http://192.168.1.100:3000/files/\(encodedDeviceName)") else {
            print("Error: Invalid URL string.")
            DispatchQueue.main.async { self.activityIndicator.stopAnimating() }
            return
        }
        
        // Create a data task to fetch file list from the server.
        let task = URLSession.shared.dataTask(with: url) { data, response, error in
            // Hide loading indicator on the main thread once the task completes.
            DispatchQueue.main.async {
                self.activityIndicator.stopAnimating()
            }
            
            // Handle network errors.
            if let error = error {
                print("Error fetching files: \(error.localizedDescription)")
                // TODO: Potentially show an error message to the user.
                return
            }
            
            // Check for a successful HTTP response.
            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                print("Error: Invalid HTTP response or status code not 200. Status: \((response as? HTTPURLResponse)?.statusCode ?? -1)")
                // TODO: Potentially show an error message to the user.
                return
            }
            
            // Ensure data is present.
            guard let data = data else {
                print("Error: No data received.")
                // TODO: Potentially show an error message to the user.
                return
            }
            
            // Parse the JSON data. Expecting an array of strings (file names).
            do {
                if let filesArray = try JSONSerialization.jsonObject(with: data, options: []) as? [String] {
                    // Update files array and reload table view on the main thread.
                    DispatchQueue.main.async {
                        self.files = filesArray
                        self.tableView.reloadData()
                    }
                } else {
                    print("Error: Invalid JSON format or not an array of strings.")
                }
            } catch {
                print("Error parsing JSON: \(error.localizedDescription)")
            }
        }
        task.resume() // Start the network task.
    }
    
    // MARK: - File Management
    
    // Generates a unique file URL to avoid overwriting existing files in the specified directory.
    // If a file with `fileName` exists, it appends a counter (e.g., "file (1).txt").
    // - Parameter fileName: The original name of the file.
    // - Parameter directory: The directory URL where the file will be saved.
    // - Returns: A unique URL for the file within the directory.
    func getUniqueFileURL(for fileName: String, in directory: URL) -> URL {
        let fileExtension = (fileName as NSString).pathExtension
        let baseName = (fileName as NSString).deletingPathExtension
        var destinationURL = directory.appendingPathComponent(fileName)
        var counter = 1
        
        // If a file at destinationURL already exists, append a counter to the base name.
        while FileManager.default.fileExists(atPath: destinationURL.path) {
            let newFileName = "\(baseName) (\(counter)).\(fileExtension)"
            destinationURL = directory.appendingPathComponent(newFileName)
            counter += 1
        }
        
        return destinationURL
    }
    
    // MARK: - Actions (Triggered by UI)
    
    // Handles the tap of the "Descargar" (Download) button in a table view cell.
    // - Parameter sender: The UIButton that triggered the action. Its tag contains the row index.
    @objc func downloadFile(sender: UIButton) {
        let index = sender.tag // Get the row index from the button's tag.
        let fileName = files[index] // Get the corresponding file name.
        print("Descargando archivo: \(fileName)")
        
        // Re-validate and encode device name and file name for the download URL.
        let validDeviceName = deviceName.components(separatedBy: CharacterSet.alphanumerics.inverted).joined()
        guard let encodedDeviceName = validDeviceName.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed),
              let encodedFileName = fileName.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) else {
            print("Error: Could not encode device or file name for download.")
            // TODO: Show error to user
            return
        }
        
        // Construct the download URL.
        guard let url = URL(string: "http://192.168.1.100:3000/files/\(encodedDeviceName)/\(encodedFileName)") else {
            print("Error: Invalid download URL string.")
            // TODO: Show error to user
            return
        }
        
        // Create a download task.
        let task = URLSession.shared.downloadTask(with: url) { location, response, error in
            // Handle network errors during download.
            if let error = error {
                print("Error al descargar: \(error.localizedDescription)")
                // TODO: Potentially show an error message to the user on the main thread.
                return
            }
            
            // Check for a successful HTTP response.
            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                print("Código de estado HTTP: \((response as? HTTPURLResponse)?.statusCode ?? -1)")
                // TODO: Potentially show an error message to the user on the main thread.
                return
            }
            
            // Ensure temporary location of the downloaded file is available.
            guard let location = location else {
                print("Error: Download location is nil.")
                // TODO: Potentially show an error message to the user on the main thread.
                return
            }
            
            // Get the app's documents directory URL.
            let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            // Get a unique destination URL within the documents directory.
            let destinationURL = self.getUniqueFileURL(for: fileName, in: documentsURL)
            
            // Move the downloaded file from the temporary location to the documents directory.
            do {
                try FileManager.default.moveItem(at: location, to: destinationURL)
                // On success, show an alert on the main thread.
                DispatchQueue.main.async {
                    print("Archivo descargado en: \(destinationURL.path)")
                    let alert = UIAlertController(title: "Éxito", message: "Archivo \(fileName) descargado.", preferredStyle: .alert)
                    alert.addAction(UIAlertAction(title: "OK", style: .default))
                    self.present(alert, animated: true)
                }
            } catch {
                print("Error al mover archivo: \(error.localizedDescription)")
                // TODO: Potentially show an error message to the user on the main thread.
            }
        }
        task.resume() // Start the download task.
    }
    
    // Handles the tap of the "Vista Previa" (Preview) button in a table view cell.
    // - Parameter sender: The UIButton that triggered the action. Its tag contains the row index.
    @objc func previewFile(sender: UIButton) {
        let index = sender.tag // Get the row index from the button's tag.
        let fileName = files[index] // Get the corresponding file name.
        print("Previsualizando archivo: \(fileName)")
        
        // Construct the URL for the file in the app's documents directory.
        let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let fileURL = documentsURL.appendingPathComponent(fileName)
        
        // Check if the file exists at the constructed path.
        if FileManager.default.fileExists(atPath: fileURL.path) {
            self.previewFileURL = fileURL // Set the URL for the QLPreviewController.
            let previewController = QLPreviewController() // Create a QuickLook preview controller.
            previewController.dataSource = self // Set this ViewController as the data source.
            self.present(previewController, animated: true) // Present the preview controller.
        } else {
            // If the file is not found, show an alert prompting the user to download it first.
            let alert = UIAlertController(title: "Error", message: "El archivo \(fileName) no está descargado. Descárguelo primero.", preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "OK", style: .default))
            self.present(alert, animated: true)
        }
    }
    
    // MARK: - QLPreviewControllerDataSource Methods
    
    // Returns the number of items to preview.
    func numberOfPreviewItems(in controller: QLPreviewController) -> Int {
        return previewFileURL == nil ? 0 : 1 // Only one item (or none if URL is nil).
    }
    
    // Returns the preview item for a given index.
    func previewController(_ controller: QLPreviewController, previewItemAt index: Int) -> QLPreviewItem {
        // Force unwrap is used here assuming previewFileURL is always set before this is called.
        // A safer approach would be to handle the optional gracefully.
        guard let url = previewFileURL else {
            // This case should ideally not happen if numberOfPreviewItems returns 0 when previewFileURL is nil.
            // Returning a dummy URL or handling this error gracefully is better.
            fatalError("previewFileURL is nil, but QLPreviewController asked for an item. This should not happen.")
        }
        return url as QLPreviewItem
    }
    
    // MARK: - UITableViewDataSource Methods
    
    // Returns the number of rows in the table view section.
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return files.count // Number of rows is the count of fetched files.
    }
    
    // Configures and returns a cell for a given row in the table view.
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "Cell", for: indexPath)
        cell.textLabel?.text = files[indexPath.row] // Set the file name as the cell's text.
        
        // --- Configure Download Button ---
        let downloadButton = UIButton(type: .system)
        downloadButton.setTitle("Descargar", for: .normal)
        downloadButton.tag = indexPath.row // Store row index in tag to identify file.
        downloadButton.addTarget(self, action: #selector(downloadFile), for: .touchUpInside)
        downloadButton.sizeToFit() // Adjust button size to fit its title.
        
        // --- Configure Preview Button ---
        let previewButton = UIButton(type: .system)
        previewButton.setTitle("Vista Previa", for: .normal)
        previewButton.tag = indexPath.row // Store row index in tag.
        previewButton.addTarget(self, action: #selector(previewFile), for: .touchUpInside)
        previewButton.sizeToFit()
        
        // --- Configure UIStackView for Buttons ---
        // Use a horizontal stack view to arrange the download and preview buttons.
        let stackView = UIStackView(arrangedSubviews: [downloadButton, previewButton])
        stackView.axis = .horizontal
        stackView.spacing = 8 // Space between buttons.
        stackView.distribution = .fill // Distribution of elements.
        stackView.alignment = .center // Alignment of elements.
        
        // Set the frame for the stack view.
        // Using frame directly because `translatesAutoresizingMaskIntoConstraints` is set to true later.
        // This manual frame calculation might be fragile with different button title lengths or font sizes.
        // Auto Layout constraints for the stack view within the cell's accessoryView would be more robust.
        stackView.frame = CGRect(x: 0, y: 0, width: downloadButton.frame.width + previewButton.frame.width + stackView.spacing, height: max(downloadButton.frame.height, previewButton.frame.height))
        // Note: The original code had `translatesAutoresizingMaskIntoConstraints = true` here.
        // When providing a view for `accessoryView`, it's usually best to let the table view manage its layout,
        // or if using a custom size, ensure it's handled correctly.
        // For simplicity and matching original behavior, we keep it, but typically this would be false if adding constraints.
        
        cell.accessoryView = stackView // Set the stack view as the cell's accessory view.
        
        return cell
    }
}
