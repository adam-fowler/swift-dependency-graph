//
//  PackageLoader.swift
//  AsyncHTTPClient
//
//  Created by Adam Fowler on 18/08/2019.
//

import Foundation
import NIO
import Basic
import PackageGraph
import PackageLoading
import PackageModel
import Workspace

public class PackageLoader {
    public init() throws {
        self.userToolchain = try UserToolchain(destination: Destination.hostDestination(AbsolutePath("/Library/Developer/CommandLineTools/usr/bin/")))
    }
    
    public func load(_ buffer: [UInt8], url: String) throws -> [String] {
        let diagnostics = DiagnosticsEngine()
        let fs = InMemoryFileSystem()
        try fs.writeFileContents(AbsolutePath("/Package.swift"), bytes: ByteString(buffer))
        
        print("Loading manifest from \(url)")
        
        do {
            let manifest = try ManifestLoader(manifestResources: userToolchain.manifestResources).load(packagePath:AbsolutePath("/"), baseURL: url, version: nil, manifestVersion: .v5, fileSystem: fs, diagnostics: diagnostics)
            let dependencies = manifest.dependencies.map {$0.url}
            return dependencies
        } catch {
            print(error.localizedDescription)
        }
        return []
    }
    
    let userToolchain : UserToolchain
}
