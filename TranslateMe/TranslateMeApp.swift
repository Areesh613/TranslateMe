//
//  TranslateMeApp.swift
//  TranslateMe
//
//  Created by user286640 on 11/1/25.
//

import SwiftUI
import FirebaseCore // <-- Import Firebase

@main
struct TranslateMeApp: App {
    
    init() { // <-- Add an init
        FirebaseApp.configure() // <-- Configure Firebase app
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
