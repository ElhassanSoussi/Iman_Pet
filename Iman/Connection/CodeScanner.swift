import SwiftUI
import AVFoundation

struct CodeScanner:UIViewControllerRepresentable {
 let scanned:(String)->Void
 func makeUIViewController(context:Context)->ScannerController{ScannerController(scanned:scanned)}
 func updateUIViewController(_ controller:ScannerController,context:Context){}
 static func dismantleUIViewController(_ controller:ScannerController,coordinator:()){controller.stop()}
}
final class ScannerController:UIViewController,AVCaptureMetadataOutputObjectsDelegate {
 private let camera=AVCaptureSession()
 private let queue=DispatchQueue(label:"Iman.camera")
 private var preview:AVCaptureVideoPreviewLayer?
 private var delivered=false
 private var stopped=false
 private let scanned:(String)->Void
 init(scanned:@escaping(String)->Void){self.scanned=scanned;super.init(nibName:nil,bundle:nil)}
 required init?(coder:NSCoder){fatalError("Use init(scanned:)")}
 override func viewDidLoad(){
  super.viewDidLoad();view.backgroundColor = .black
  AVCaptureDevice.requestAccess(for:.video){[weak self] allowed in
   DispatchQueue.main.async {
    guard let self=self,!self.stopped else{return}
    guard allowed,let device=AVCaptureDevice.default(for:.video),let input=try? AVCaptureDeviceInput(device:device),self.camera.canAddInput(input) else{self.showError();return}
    self.camera.addInput(input)
    let output=AVCaptureMetadataOutput()
    guard self.camera.canAddOutput(output) else{self.showError();return}
    self.camera.addOutput(output);output.setMetadataObjectsDelegate(self,queue:.main);output.metadataObjectTypes=[.qr]
    let layer=AVCaptureVideoPreviewLayer(session:self.camera);layer.videoGravity = .resizeAspectFill;layer.frame=self.view.bounds
    self.view.layer.addSublayer(layer);self.preview=layer
    self.queue.async{self.camera.startRunning()}
   }
  }
 }
 override func viewDidLayoutSubviews(){super.viewDidLayoutSubviews();preview?.frame=view.bounds}
 func stop(){stopped=true;queue.async{self.camera.stopRunning()}}
 private func showError(){let label=UILabel(frame:view.bounds.insetBy(dx:24,dy:24));label.text="Allow camera access to scan your Mac’s code, or paste the code in Connect.";label.textColor = .white;label.numberOfLines=0;view.addSubview(label)}
 func metadataOutput(_ output:AVCaptureMetadataOutput,didOutput objects:[AVMetadataObject],from connection:AVCaptureConnection){
  guard !delivered,let raw=(objects.first as? AVMetadataMachineReadableCodeObject)?.stringValue,(try? PairingTicket(raw)) != nil else{return}
  delivered=true;stop();scanned(raw)
 }
}
