//
//  WebViewContainer.swift
//  SOOLRA
//
//  Created by Kai Yoshida on 03/08/2025.
//


import SwiftUI

struct WebViewContainer: View {
    var body: some View {
        WebView(url: URL(string: "http://192.168.1.167:54741")!)
            .navigationTitle("Website")
            .navigationBarTitleDisplayMode(.inline)
        
    }
}
