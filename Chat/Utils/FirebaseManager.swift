//
//  FirebaseManager.swift
//  Chat
//
//  Created by Jerry Zhang on 1/28/22.
//

import Foundation
import Firebase
import FirebaseFirestore

class FirebaseManager: NSObject {
    let auth: Auth
    let storage: Storage
    let fireStore: Firestore
    
    static let shared = FirebaseManager()
    
    override init() {
        FirebaseApp.configure()
        self.auth = Auth.auth()
        self.storage = Storage.storage()
        self.fireStore = Firestore.firestore()
        
        super.init()
    }
    
}
