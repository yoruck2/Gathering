//
//  DmsRoomResponse.swift
//  Gathering
//
//  Created by 여성은 on 11/12/24.
//

import Foundation

typealias DmsRooms = [DmsRoomResponse]

struct DmsRoomResponse: Decodable {
    let room_id: String
    let creatAt: String
    let user: MemberResponse
}
