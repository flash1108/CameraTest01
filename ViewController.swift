//
//  ViewController.swift
//  CameraTest01
//
//  Created by Ah-Jin on 2016/1/23.
//  Copyright © 2016年 Ah-Jin. All rights reserved.
//

import UIKit
import AVFoundation

class ViewController: UIViewController {

    
    var myCaptureSession:AVCaptureSession?
    var myStillImageOutput:AVCaptureStillImageOutput?
    var myVideoConnection: AVCaptureConnection?
    
    @IBOutlet weak var showImage: UIImageView!
    @IBOutlet weak var captureButton: UIBarButtonItem!
    @IBOutlet weak var previewScroll: UIScrollView!
    
    var photoPool = [String]()
    
    var photoCount = 0
    
    let _DocumentsPath = NSSearchPathForDirectoriesInDomains(.DocumentDirectory, .UserDomainMask, true)[0] as String //照片儲存路徑
    
    var _TempPath:String!
    var _PhotoPath:String!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        _TempPath = self._DocumentsPath + "/photoTemp"
        _PhotoPath = self._DocumentsPath + "/photo"
        
        do {
            try NSFileManager.defaultManager().createDirectoryAtPath(_PhotoPath, withIntermediateDirectories: false, attributes: nil)
            print("Create \(_PhotoPath) success.")
        } catch {
            print("Create \(_PhotoPath) fail.")
        }
        
        do {
            try NSFileManager.defaultManager().removeItemAtPath(_TempPath)
            print("remove \(_TempPath) success.")
        } catch {
            print("remove \(_TempPath) fail.")
        }
        
        myCaptureSession = AVCaptureSession()
        myCaptureSession?.sessionPreset = AVCaptureSessionPresetPhoto
        
        
        let myDevices = AVCaptureDevice.devices()
        
        
        for device in myDevices {
            if device.position == AVCaptureDevicePosition.Back {
                print("後攝影機硬體名稱:\(device.localizedName)")
                
                do {
                    //取得裝置
                    let myDeviceInput = try AVCaptureDeviceInput(device: device as! AVCaptureDevice)
                    myCaptureSession?.addInput(myDeviceInput)
                    
                    self.doCreateCamera()
                }
                catch {
                    
                }
                
            }
            
            if device.position == AVCaptureDevicePosition.Front {
                print("前攝影機硬體名稱:\(device.localizedName)")
            }
            
            if device.hasMediaType(AVMediaTypeAudio) {
                print("麥克風硬體名稱:\(device.localizedName)")
            }
        }

        
        
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }


    func doCreateCamera() {
        //建立 AVCaptureVideoPreviewLayer
        
        let myPreviewLayer = AVCaptureVideoPreviewLayer(session: myCaptureSession)
        myPreviewLayer.videoGravity = AVLayerVideoGravityResizeAspectFill
        
        let rect = CGRectMake(160, 180, 320, 240)
        myPreviewLayer.bounds = rect
        
        let myView = UIView(frame: rect)
        myView.layer.addSublayer(myPreviewLayer)
        
        self.view.addSubview(myView)
        
        //啟用攝影機
        myCaptureSession?.startRunning()
        
        
        myStillImageOutput = AVCaptureStillImageOutput()
        
        let myOutputSettings = [AVVideoCodecKey: AVVideoCodecJPEG]
        myStillImageOutput?.outputSettings = myOutputSettings
        
        myCaptureSession?.addOutput(myStillImageOutput)
        
        
        
        //從 AVCaptureStillImageOutput 中取得正確類型的 AVCaptureConnection
        for connection in myStillImageOutput!.connections {
            
            let captureConnection = connection as! AVCaptureConnection
            
            for port in captureConnection.inputPorts {
                
                let connectPort = port as! AVCaptureInputPort
                
                if connectPort.mediaType == AVMediaTypeVideo {
                    myVideoConnection = captureConnection
                    break
                }
            }
        }
        
        
 
    }
    
    @IBAction func doCapturePhoto(sender: AnyObject) {
        
        if self.photoCount >= 10 {
            print("一次只能拍10張")
            
            return
        }
        
        if (!NSFileManager.defaultManager().fileExistsAtPath(_TempPath)) {
            do {
                try NSFileManager.defaultManager().createDirectoryAtPath(_TempPath, withIntermediateDirectories: false, attributes: nil)
                print("Create \(_TempPath) success.")
            } catch {
                print("Create \(_TempPath) fail.")
            }
        }
        
        let bt = sender as! UIBarButtonItem
        bt.enabled = false
        
        self.report_memory(1)
        
        myStillImageOutput?.captureStillImageAsynchronouslyFromConnection(myVideoConnection, completionHandler: { (imageDataSampleBuffer, error) -> Void in
            
            self.report_memory(2)
            
            //完成擷取時的處理常式(Block)
            if imageDataSampleBuffer != nil {
                let uuid = NSUUID().UUIDString
                
                let imageData = AVCaptureStillImageOutput.jpegStillImageNSDataRepresentation(imageDataSampleBuffer)
                
                self.photoPool.append(uuid)
                self.report_memory(3)
                
                self.photoCount++
                print("目前照片數：\(self.photoCount)")

                
                let qualityOfServiceClass = QOS_CLASS_BACKGROUND
                let backgroundQueue = dispatch_get_global_queue(qualityOfServiceClass, 0)
                dispatch_async(backgroundQueue, {
                    
                    self.report_memory(4)
                    
                    self.doSaveToTempDisk(imageData, andId: uuid)
                    
                    self.report_memory(5)
                    
                    //取得的靜態影像
                    let myImage = UIImage(data: imageData)
                    let sImage = self.imageResize(myImage!, sizeChange: CGSizeMake(96, 128))
                    self.report_memory(6)
                    dispatch_async(dispatch_get_main_queue(), { () -> Void in
                        
                        let scrollWidth:CGFloat = CGFloat(96 * self.photoCount)
                        let imageView = UIImageView(image: sImage)
                        self.report_memory(7)
                        imageView.frame = CGRectMake(CGFloat(96 * (self.photoCount-1)), 0, 96, 128)
                        self.previewScroll.addSubview(imageView)
                        
                        self.report_memory(8)
                        imageView.tag = self.photoCount
                        
                        self.previewScroll.contentSize = CGSizeMake(scrollWidth, 128)
                        self.report_memory(9)
                        
                    })
                    
                })

            }
            self.report_memory(13)
            
            bt.enabled = true
            
            self.report_memory(14)
        })
        
        self.report_memory(15)
    }
    
    
    func imageResize (imageObj:UIImage, sizeChange:CGSize)-> UIImage{
        
        let hasAlpha = false
        let scale: CGFloat = 0.0 // Automatically use scale factor of main screen
        
        self.report_memory(16)
        
        UIGraphicsBeginImageContextWithOptions(sizeChange, !hasAlpha, scale)
        self.report_memory(17)
        imageObj.drawInRect(CGRect(origin: CGPointZero, size: sizeChange))
        self.report_memory(18)
        let scaledImage = UIGraphicsGetImageFromCurrentImageContext()
        self.report_memory(19)
        UIGraphicsEndImageContext();
        self.report_memory(20)
        return scaledImage
    }
    
    
    @IBAction func doSavePhoto(sender: AnyObject) {
        
        let qualityOfServiceClass = QOS_CLASS_BACKGROUND
        let backgroundQueue = dispatch_get_global_queue(qualityOfServiceClass, 0)
        dispatch_async(backgroundQueue, {
            for imgId in self.photoPool {
                
                let tempPath = NSURL(fileURLWithPath: self._TempPath).URLByAppendingPathComponent("\(imgId).jpg")
                
                let bigPath = NSURL(fileURLWithPath: self._PhotoPath).URLByAppendingPathComponent("\(imgId).jpg")
                
                let smallPath = NSURL(fileURLWithPath: self._PhotoPath).URLByAppendingPathComponent("\(imgId)_s.jpg")
                
                do {
                    try NSFileManager.defaultManager().copyItemAtURL(tempPath, toURL: bigPath)
                    print("Move big image \(imgId) successful")
                    
                    try NSFileManager.defaultManager().copyItemAtURL(tempPath, toURL: smallPath)
                    print("Move small image \(imgId) successful")
                }
                catch {

                    print("Moved big \(imgId) failed with error: \(error)")
                }


            }
            
            do {
                try NSFileManager.defaultManager().removeItemAtPath(self._TempPath)
                print("delete temp image successful")
            }
            catch {
                
                print("delete temp failed with error: \(error)")
            }
            
        })


    }
    
    func doSaveToTempDisk(imageData: NSData, andId imgId: String) {
        
        //儲存時會比較耗記憶體
        self.report_memory(10)
        let imageCompressionQuality:CGFloat = 0.8
        
        let bigPath = NSURL(fileURLWithPath: _TempPath).URLByAppendingPathComponent("\(imgId).jpg")

        if let image = UIImage(data: imageData) {
            self.report_memory(11)
            UIImageJPEGRepresentation(image, imageCompressionQuality)?.writeToURL(bigPath, atomically: true)
            
            self.report_memory(12)
            print("save image \(imgId)")
        }
    }
    
    
//    func doSaveToDisk(imageData: NSData, andId imgId: String) {
//        
//        //儲存時會比較耗記憶體
//        
//        let imageCompressionQuality:CGFloat = 0.8
//        
//        let bigPath = NSURL(fileURLWithPath: _TempPath).URLByAppendingPathComponent("\(imgId).jpg")
//        
//        let smallPath = NSURL(fileURLWithPath: _TempPath).URLByAppendingPathComponent("\(imgId)_s.jpg")
//        
//        if let image = UIImage(data: imageData) {
//            UIImageJPEGRepresentation(image, imageCompressionQuality)?.writeToURL(bigPath, atomically: true)
//            
//            UIImageJPEGRepresentation(image, imageCompressionQuality)?.writeToURL(smallPath, atomically: true)
//            print("save image \(imgId)")
//        }
//    }

    
    func report_memory(idx: Int) {
        // constant
        let MACH_TASK_BASIC_INFO_COUNT = (sizeof(mach_task_basic_info_data_t) / sizeof(natural_t))
        
        // prepare parameters
        let name   = mach_task_self_
        let flavor = task_flavor_t(MACH_TASK_BASIC_INFO)
        var size   = mach_msg_type_number_t(MACH_TASK_BASIC_INFO_COUNT)
        
        // allocate pointer to mach_task_basic_info
        let infoPointer = UnsafeMutablePointer<mach_task_basic_info>.alloc(1)
        
        // call task_info - note extra UnsafeMutablePointer(...) call
        let kerr = task_info(name, flavor, UnsafeMutablePointer(infoPointer), &size)
        
        // get mach_task_basic_info struct out of pointer
        let info = infoPointer.move()
        
        // deallocate pointer
        infoPointer.dealloc(1)
        
        // check return value for success / failure
        if kerr == KERN_SUCCESS {
            print("\(idx) Memory in use (in MB): \(info.resident_size/1000000)")
        } else {
            let errorString = String(CString: mach_error_string(kerr), encoding: NSASCIIStringEncoding)
            print(errorString ?? "\(idx) Error: couldn't parse error string")
        }    
    }
}

