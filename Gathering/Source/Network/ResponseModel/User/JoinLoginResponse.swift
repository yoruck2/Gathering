//
//  JoinResponse.swift
//  Gathering
//
//  Created by dopamint on 11/12/24.
//

import Foundation

struct JoinLoginResponse: Decodable {
    let userID: String
    let email: String
    let nickname: String
    let profileImage: String?
    let phone: String?
    let provider: String?
    let createdAt: String
    let token: Token
    
    enum CodingKeys: String, CodingKey {
        case userID = "user_id"
        case email
        case nickname
        case profileImage
        case phone
        case provider
        case createdAt
        case token
    }
}
