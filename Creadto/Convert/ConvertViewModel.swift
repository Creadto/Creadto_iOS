//
//  ExportViewModel.swift
//  Creadto
//
//  Created by 이상진 on 2022/11/15.
//

import Alamofire
import UniformTypeIdentifiers
import SceneKit


class ConvertViewModel : ObservableObject {
    private let apiURL = URL(string: "http://192.168.219.148:3000")
    var fileController = FileController()
    var jsonURL : URL?
    
    private func checkPLYFile(fileURL : URL) -> Bool {
        if(fileURL.lastPathComponent == "Face.ply" || fileURL.pathExtension != "ply"){
            return false
        } else {
            return true
        }
    }

    func sendToServer(url : URL){
        let fileList = fileController.getContentsOfDirectory(url: url)
        var _counter = 0
        var _plyList : [URL] = []
        fileList.map{ file in
            if(checkPLYFile(fileURL: file)){
                _plyList.append(file)
                _counter += 1
            }
        }
        
        let counter = _counter
        let plyList = _plyList
        print("1. 보내고자 하는 ply file 수 = \(counter)")
        
        Task {
            do {
                try await sendDataCounter(counter: counter)
                for i in 0...counter-1 {
                    let filePath = plyList[i]
                    let mimeType = filePath.getMimeType()
                    let fileName = filePath.path.components(separatedBy: "/").last!

                    let fileData = try? Data(contentsOf: filePath)

                    try await fileUpload(fileData: fileData ?? Data(), fileName: fileName, mimeType: mimeType)
                }
                print("4. fileUpload 끝 && observeStatus")

                while(true){
                    let res = try await observeStatus(saveURL: url)
                    if(res.Status == "Meshed") {
                        break;
                    } else {
                        sleep(5)
                        print("status = \(res.Status)")
                    }
                }
                print("5. fileDownload 호출")
                try await fileDownload(saveURL: url)
            } catch {
                print("sendDataCounter Error")
            }
        }
        
    }
    
    private func sendDataCounter(counter: Int) async throws -> UserData {
        print("2. sendDataCounter 호출")
        let counterToString = String(counter)
        
        return try await AF.request(apiURL!,
                                    method: .post,
                                    parameters: ["Counter" : counterToString],
                                    encoding: URLEncoding.default,
                                    headers: ["Content-Type" : "application/octet-stream"])
        .validate(statusCode: 200..<300)
        .responseJSON { response in
            switch response.result {
            case .success(let value) :
                do {
                    print("sendDataCounter response Success")
                } catch {
                    print("sendDataCounter response error")
                }
            case .failure(let error) :
                print(error)
            }
        }
        .serializingDecodable()
        .value
    }
    
    private func observeStatus(saveURL : URL) async throws -> UserData {
        print("observeStatus 호출")
        return try await AF.request(apiURL!,
                   method: .post,
                   parameters: ["Status" : "check"],
                   encoding: URLEncoding.default,
                   headers: ["Content-Type" : "application/octet-stream"])
        .validate(statusCode: 200..<300)
        .responseJSON { response in
            switch response.result {
            case .success(let value) :
                do {
                    let data = try JSONSerialization.data(withJSONObject: value, options: .prettyPrinted)
                    let _userData = try JSONDecoder().decode(UserData.self, from: data)
                    print("observeStatus response = \(_userData)")
                    
                    if(_userData.Status == "Measured") {
                        let jsonData = _userData.Data!.data(using: .utf8)!
                        self.jsonURL = saveURL.appendingPathComponent("Measurement.json")
                        try! jsonData.write(to: self.jsonURL!)
                    }
                } catch {
                    print("observeStatus response error")
                }
            case .failure(let error) :
                print(error)
            }
        }
        .serializingDecodable()
        .value
    }
    
    
    private func fileUpload(fileData : Data, fileName: String, mimeType: String) async throws -> UserData {
        print("fileUpload 호출")
        
        return try await AF.upload(multipartFormData: { multipart in
            multipart.append(fileData,
                             withName: "ply",
                             fileName: fileName,
                             mimeType:  mimeType)
        }, to: apiURL!, method: .post).uploadProgress(closure: {
            progress in
            print(progress.fractionCompleted * 100)
        })
        .responseJSON {
            response in
            switch response.result {
            case .success(let value) :
                do{
                    print("fileUpload response = Success")
                } catch {
                    print("fileUpload response error")
                }
                
            case .failure(let error) :
                print(error)
            }
        }
        .serializingDecodable()
        .value
    }
    
    private func fileDownload(saveURL : URL){
        AF.request(apiURL!,
                   method: .post,
                   parameters: ["mesh" : "request"],
                   encoding: URLEncoding.default,
                   headers: ["Content-Type" : "application/octet-stream"])
        .validate(statusCode: 200..<300)
        .response{ response in
            switch response.result {
            case .success :
                let path = saveURL.appendingPathComponent("Mesh.ply")
                if let _data = response.data{
                    try! _data.write(to: path)
                    self.convertToPNG(path: path)
                    print("fileDownload Save file 성공")
                }else{
                    print("fileDownload Data is nil")
                }
            case .failure(let error):
                print("Error: ", error)
            }
            
        }
    }
    
    private func convertToPNG(path : URL){
        let scene = try! SCNScene(url: path, options: nil)
        let scnView = SCNView()
        let cameraNode = SCNNode()
        cameraNode.camera = SCNCamera()
        cameraNode.position = SCNVector3(x: 0 , y: 5, z:10)
        scene.rootNode.addChildNode(cameraNode)
        
        scnView.scene = scene
        scnView.autoenablesDefaultLighting = true
        scnView.antialiasingMode = .multisampling2X
        scnView.backgroundColor = UIColor.clear
        
        let previewImage = scnView.snapshot()
        let pngData = previewImage.pngData()
        let previewImageURL = path.deletingLastPathComponent().appendingPathComponent("Mesh.png")
        try? pngData!.write(to: previewImageURL)
    }
}

extension URL {
    func getMimeType() -> String {
        let pathExtension = self.pathExtension
        if let type = UTType(filenameExtension: pathExtension) {
            if let mimetype = type.preferredMIMEType {
                return mimetype as String
            }
        }
        return "application/octet-stream"
    }
}
