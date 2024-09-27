import Foundation
import QRCodeReader
import AVFoundation

@objc(QRScanner)
class QRScanner: CDVPlugin, QRCodeReaderViewControllerDelegate {

    var readerVC: QRCodeReaderViewController?

    override func pluginInitialize() {
        super.pluginInitialize()
        NotificationCenter.default.addObserver(self, selector: #selector(pageDidLoad), name: NSNotification.Name.CDVPageDidLoad, object: nil)
    }

    @objc func prepare(_ command: CDVInvokedUrlCommand) {
        let status = AVCaptureDevice.authorizationStatus(for: AVMediaType.video)
        if status == .notDetermined {
            AVCaptureDevice.requestAccess(for: AVMediaType.video) { granted in
                DispatchQueue.main.async {
                    if granted {
                        self.setupReader()
                        self.getStatus(command)
                    } else {
                        self.sendErrorCode(command: command, error: .camera_access_denied)
                    }
                }
            }
        } else if status == .authorized {
            setupReader()
            getStatus(command)
        } else {
            sendErrorCode(command: command, error: .camera_access_denied)
        }
    }

    func setupReader() {
        readerVC = QRCodeReaderViewController(builder: QRCodeReaderViewControllerBuilder {
            $0.reader = QRCodeReader(metadataObjectTypes: [.qr], captureDevicePosition: .back)
            $0.showTorchButton = true
            $0.preferredStatusBarStyle = .lightContent
        })
        readerVC?.delegate = self
    }

    @objc func scan(_ command: CDVInvokedUrlCommand) {
        guard let readerVC = readerVC else {
            sendErrorCode(command: command, error: .unexpected_error)
            return
        }

        readerVC.completionBlock = { (result: QRCodeReaderResult?) in
            if let result = result {
                let pluginResult = CDVPluginResult(status: CDVCommandStatus_OK, messageAs: result.value)
                self.commandDelegate.send(pluginResult, callbackId: command.callbackId)
            } else {
                self.sendErrorCode(command: command, error: .scan_canceled)
            }
        }

        self.viewController.present(readerVC, animated: true, completion: nil)
    }

    @objc func cancelScan(_ command: CDVInvokedUrlCommand) {
        readerVC?.dismiss(animated: true, completion: {
            self.sendErrorCode(command: command, error: .scan_canceled)
        })
    }

    @objc func enableLight(_ command: CDVInvokedUrlCommand) {
        readerVC?.toggleTorch()
        getStatus(command)
    }

    @objc func disableLight(_ command: CDVInvokedUrlCommand) {
        readerVC?.toggleTorch()
        getStatus(command)
    }

    @objc func getStatus(_ command: CDVInvokedUrlCommand) {
        let status = [
            "authorized": AVCaptureDevice.authorizationStatus(for: .video) == .authorized ? "1" : "0",
            "scanning": readerVC?.isBeingPresented == true ? "1" : "0",
            "lightEnabled": readerVC?.reader.isTorchAvailable == true ? "1" : "0"
        ]
        let pluginResult = CDVPluginResult(status: CDVCommandStatus_OK, messageAs: status)
        commandDelegate.send(pluginResult, callbackId: command.callbackId)
    }

    func reader(_ reader: QRCodeReaderViewController, didScanResult result: QRCodeReaderResult) {
        reader.stopScanning()
        reader.dismiss(animated: true, completion: nil)
    }

    func readerDidCancel(_ reader: QRCodeReaderViewController) {
        reader.stopScanning()
        reader.dismiss(animated: true, completion: nil)
    }

    func sendErrorCode(command: CDVInvokedUrlCommand, error: QRScannerError) {
        let pluginResult = CDVPluginResult(status: CDVCommandStatus_ERROR, messageAs: error.rawValue)
        commandDelegate.send(pluginResult, callbackId: command.callbackId)
    }

    @objc func pageDidLoad() {
        self.webView?.isOpaque = false
        self.webView?.backgroundColor = UIColor.clear
    }
}