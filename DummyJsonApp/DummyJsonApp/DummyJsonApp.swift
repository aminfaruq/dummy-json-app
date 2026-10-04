//
//  DummyJsonApp.swift
//  DummyJsonApp
//
//  Created by Amin faruq on 04/10/26.
//

import SwiftUI
import DummyJsonFramework
import DummyJsonPresentation

@main
struct DummyJsonApp: App {
    var body: some Scene {
        WindowGroup {
            let client = URLSessionHTTPClient()
            let url = URL(string: "https://dummyjson.com/users")!
            let loader = RemoteUserLoader(url: url, client: client)
            let viewModel = UserViewModel(loader: loader)
            ContentView(viewModel: viewModel)
                .preferredColorScheme(.dark)
        }
        
    }
}
