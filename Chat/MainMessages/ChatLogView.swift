//
//  ChatLogView.swift
//  Chat
//
//  Created by Jerry Zhang on 1/28/22.
//

import SwiftUI
import FirebaseFirestore

struct FirebaseConstants {
    static let fromId = "fromId"
    static let toId = "toId"
    static let text = "text"
}

struct ChatMessage: Identifiable {
    
    var id: String { documentId }
    
    let documentId: String
    let fromId, toId, text: String
    
    init(documentId: String, data: [String: Any]) {
        self.documentId = documentId
        self.fromId = data[FirebaseConstants.fromId] as? String ?? ""
        self.toId = data[FirebaseConstants.toId] as? String ?? ""
        self.text = data[FirebaseConstants.text] as? String ?? ""
    }
}

class ChatLogViewModel: ObservableObject {
    
    @Published var chatText = ""
    @Published var errorMessage = ""
    @Published var chatMessges = [ChatMessage]()
    
    let chatUser: ChatUser?
    var currentUser: ChatUser?
    
    init(chatUser: ChatUser?) {
        self.chatUser = chatUser
        
        fetchCurrentUser()
        
        fetchMessages()
    }
    
    private func fetchCurrentUser() {
        guard let currentUserId = FirebaseManager.shared.auth.currentUser?.uid else {return}
        
        FirebaseManager.shared.fireStore.collection("users").document(currentUserId).getDocument { snapshot, err in
            if let err = err {
                self.errorMessage = "Failed to fetch current user: \(err)"
                print("Failed to fetch current user", err)
                return
            }
            
            guard let data = snapshot?.data() else {
                self.errorMessage = "No data found"
                return
            }
                        
            self.currentUser = .init(data: data)
        }
    }

    private func fetchMessages() {
        guard let fromId = FirebaseManager.shared.auth.currentUser?.uid else {return}
        guard let toId = chatUser?.uid else {return}
        FirebaseManager.shared.fireStore.collection("messages").document(fromId).collection(toId).order(by: "timestamp").addSnapshotListener { querySnapshot, err in
            if let err = err {
                self.errorMessage = "Failed to listen for messages: \(err)"
                return
            }
            
            querySnapshot?.documentChanges.forEach({ change in
                if change.type == .added {
                    let data = change.document.data()
                    self.chatMessges.append(.init(documentId: change.document.documentID, data: data))
                }
            })
            
            DispatchQueue.main.async {
                self.count += 1
            }
        }
    }
    
    func handleSend() {
        guard let fromId = FirebaseManager.shared.auth.currentUser?.uid else {return}
        guard let toId = chatUser?.uid else {return}
        
        let document = FirebaseManager.shared.fireStore.collection("messages").document(fromId).collection(toId).document()
        
        let messageData = [FirebaseConstants.fromId: fromId, FirebaseConstants.toId: toId, FirebaseConstants.text: self.chatText, "timestamp": Timestamp()] as [String: Any]
        
        document.setData(messageData) { err in
            if let err = err {
                self.errorMessage = "Failed to save message into Firestore: \(err)"
                return
            }
            
            self.persistRecentMessage()
            
            self.chatText = ""
            self.count += 1
        }
        
        if fromId != toId {
            let recipientMessageDocument = FirebaseManager.shared.fireStore.collection("messages").document(toId).collection(fromId).document()
            
            recipientMessageDocument.setData(messageData) { err in
                if let err = err {
                    self.errorMessage = "Failed to save message into Firestore: \(err)"
                    return
                }
            }
        }
    }
    
    private func persistRecentMessage() {
        
        guard let uid = FirebaseManager.shared.auth.currentUser?.uid else {return}
        
        guard let toId = chatUser?.uid else {return}
        
        let document = FirebaseManager.shared.fireStore
            .collection("recent_messages")
            .document(uid)
            .collection("messages")
            .document(toId)
        
        let data = [
            "timestamp": Timestamp(),
            "text": self.chatText,
            "fromId": uid,
            "toId": toId,
            "profileImageUrl": chatUser?.profileImageUrl ?? "",
            "email": chatUser?.email ?? ""
        ] as [String : Any]
        
        document.setData(data) { err in
            if let err = err {
                self.errorMessage = "Failed to save recent message: \(err)"
                return
            }
        }
                
        let recipientRecentMessageDictionary = [
            "timestamp": Timestamp(),
            "text": self.chatText,
            "fromId": uid,
            "toId": toId,
            "profileImageUrl": currentUser?.profileImageUrl ?? "",
            "email": currentUser?.email ?? ""
        ] as [String : Any]
        
        FirebaseManager.shared.fireStore
            .collection("recent_messages")
            .document(toId)
            .collection("messages")
            .document(uid)
            .setData(recipientRecentMessageDictionary) { error in
                if let error = error {
                    print("Failed to save recipient recent message: \(error)")
                    return
                }
            }
        
    }

    @Published var count = 0
    
}

struct ChatLogView: View {
    
    let chatUser: ChatUser?
    
    init(chatUser: ChatUser?) {
        self.chatUser = chatUser
        self.vm = .init(chatUser: chatUser)
    }
    
    @ObservedObject var vm: ChatLogViewModel
    
    var body: some View {
        VStack {
            ScrollView {
                ScrollViewReader { scrollViewProxy in
                    VStack {
                        ForEach(vm.chatMessges) { message in
                            VStack {
                                if message.fromId == FirebaseManager.shared.auth.currentUser?.uid {
                                    HStack {
                                        Spacer()
                                        HStack {
                                            Text(message.text).foregroundColor(.white)
                                        }
                                        .padding()
                                        .background(Color.blue)
                                        .cornerRadius(8)
                                    }
                                    .padding(.horizontal)
                                    .padding(.top, 8)
                                } else {
                                    HStack {
                                        HStack {
                                            Text(message.text).foregroundColor(.black)
                                        }
                                        .padding()
                                        .background(Color.white)
                                        .cornerRadius(8)
                                        Spacer()
                                    }
                                }
                            }
                            .padding(.horizontal)
                            .padding(.top, 8)
                        }
                        
                        HStack {Spacer()}.id("Empty")
                    }
                    .onReceive(vm.$count) { _ in
                        withAnimation(.easeOut(duration: 0.5)) {
                            scrollViewProxy.scrollTo("Empty", anchor: .bottom)
                        }
                    }
                }
            }
            .background(Color(.init(white: 0.95, alpha: 1)))
            
            HStack(spacing: 16) {
                Image(systemName: "photo")
                    .font(.system(size: 24))
                    .foregroundColor(Color(.darkGray))
                TextField("Description", text: $vm.chatText)
                Button {
                    vm.handleSend()
                } label: {
                    Text("Send")
                        .foregroundColor(.white)
                }
                .padding(.horizontal)
                .padding(.vertical, 8)
                .background(Color.blue)
                .cornerRadius(5)
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
            
        }
        .navigationTitle(chatUser?.email ?? "")
        .navigationBarTitleDisplayMode(.inline)
    }
        
}

struct ChatLogView_Previews: PreviewProvider {
    static var previews: some View {
        MainMessagesView()
    }
}
