//
//  PointCloudClient.swift
//  Creadto
//
//  Created by 이상진 on 2022/11/01.
//

#if compiler(>=5.6)
import ArgumentParser
import Foundation
import GRPC
import NIOCore
import NIOPosix

internal struct PointCloudExample {
    private let pointCloudClient : Creadto_PointCloudServiceAsyncClient
    
    init(pointCloudClient : Creadto_PointCloudServiceAsyncClient){
        self.pointCloudClient = pointCloudClient
    }
    
    func run(file : URL) async {
        await self.upload(fileURL: file)
    }
}

extension PointCloudExample {
    private func upload(
        fileURL : URL
    ) async {
        do {
            let data = try Data(contentsOf: fileURL)
            print("Data 생성 성공")
            
            let recordRoute = self.pointCloudClient.makeUploadCall()
            let streamRequest = Creadto_PointCloudRequest.with {
                $0.content = data
            }
            try await recordRoute.requestStream.send(streamRequest)
            try await recordRoute.requestStream.finish()
        } catch {
            print("Data 생성 실패")
        }
    }
}

@main
struct PointCloudClient : AsyncParsableCommand {
    var port : Int = 8080
    
    func run(url : URL) async throws {
        let group = PlatformSupport.makeEventLoopGroup(loopCount: 1)
        
        defer{
            try? group.syncShutdownGracefully()
        }
        
        let channel = try GRPCChannelPool.with(
            target: .host("localhost", port : self.port),
            transportSecurity: .plaintext,
            eventLoopGroup: group
        )
        
        defer {
            try? channel.close().wait()
        }
        
        let pointCloudClient = Creadto_PointCloudServiceAsyncClient(channel: channel)
        let example = PointCloudExample(pointCloudClient: pointCloudClient)
        await example.run(file: url)
    }
}

#else
@main
enum NotAvailable {
    static func main() {
        print("This example requires Swift >= 5.6")
    }
}
#endif


