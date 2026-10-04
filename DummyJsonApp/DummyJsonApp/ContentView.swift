//
//  ContentView.swift
//  DummyJsonApp
//
//  Created by Amin faruq on 04/10/26.
//

import SwiftUI
import Combine
import DummyJsonFramework
import DummyJsonPresentation

struct ContentView: View {
    @ObservedObject var viewModel: UserViewModel
    
    var body: some View {
        NavigationStack {
            Group {
                if viewModel.isLoading && viewModel.users.isEmpty {
                    ProgressView()
                } else if let errorMessage = viewModel.errorMessage {
                    errorView(message: errorMessage)
                } else {
                    userList
                }
            }
            .navigationTitle("Users")
            .task {
                await viewModel.load()
            }
            .refreshable {
                await viewModel.load()
            }
        }
    }
    
    private var userList: some View {
        List(viewModel.users, id: \.id) { user in
             VStack(alignment: .leading, spacing: 4) {
                 Text(user.username)
                     .font(.headline)
                 Text(user.email)
                     .font(.subheadline)
                     .foregroundStyle(.secondary)
             }
             .padding(.vertical, 2)
         }
     }
    
    private func errorView(message: String) -> some View {
           VStack(spacing: 12) {
               Image(systemName: "exclamationmark.triangle")
                   .font(.largeTitle)
                   .foregroundStyle(.red)
               Text(message)
                   .multilineTextAlignment(.center)
                   .foregroundStyle(.secondary)
               Button("Retry") {
                   Task {
                       await viewModel.load()
                   }
               }
               .buttonStyle(.borderedProminent)
           }
           .padding()
       }
    
}

private class PreviewLoader: UserLoader {
    func loadUsers() async throws -> [UserModel] {
        [
            UserModel(id: 1, username: "emilys", email: "emily@dummyjson.com"),
            UserModel(id: 2, username: "michaelw", email: "michael@dummyjson.com"),
            UserModel(id: 3, username: "sophiab", email: "sophia@dummyjson.com")
        ]
    }
}

#Preview {
    ContentView(viewModel: UserViewModel(loader: PreviewLoader()))
}
