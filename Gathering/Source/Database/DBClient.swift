//
//  DBClient.swift
//  Gathering
//
//  Created by 김성민 on 11/19/24.
//

import Foundation

import ComposableArchitecture
import RealmSwift

struct DBClient {
    var printRealm: () -> Void
    
    var update: @Sendable (Object) throws -> Void
    var delete: (Object) throws -> Void
    
    var createChannelChatting: @Sendable (String, ChannelChattingDBModel) throws -> Void
    var createDMChatting: @Sendable (String, DMChattingDBModel) throws -> Void
    
    // Channel 관련
    var updateChannel: @Sendable (ChannelDBModel, String, [MemberDBModel]) throws -> Void
    var fetchChannel: @Sendable (String) throws -> ChannelDBModel?
    var fetchAllChannel: @Sendable () throws -> [ChannelDBModel]
    
    // DM 관련
    var updateDMRoom: @Sendable (DMRoomDBModel, [MemberDBModel]) throws -> Void
    var fetchDMRoom: @Sendable (String) throws -> DMRoomDBModel?
    var fetchAllDMRoom: @Sendable () throws -> [DMRoomDBModel]
    
    // 멤버 관련
    var fetchMember: @Sendable (String) throws -> MemberDBModel?
    
    var removeAll: @Sendable () throws -> Void
}

extension DBClient: DependencyKey {
    static let liveValue = DBClient(
        // MARK: - 기본 CRUD
        printRealm: {
            print(Realm.Configuration.defaultConfiguration.fileURL ?? "realm 경로 없음")
        },
        update: { object in
            let realm = try Realm()
            try realm.write {
                realm.add(object, update: .modified)
            }
        },
        delete: { object in
            let realm = try Realm()
            try realm.write {
                realm.delete(object)
            }
        },
        createChannelChatting: { channelID, object in
            let realm = try Realm()
            guard let channel = realm.object(
                ofType: ChannelDBModel.self,
                forPrimaryKey: channelID
            ) else {
                print("모임을 찾을 수 없습니다.")
                return
            }
            // `object.user`가 중복되는지 확인하고 처리
            if let user = object.user {
                if let existingUser = realm.object(
                    ofType: MemberDBModel.self,
                    forPrimaryKey: user.userID
                ) {
                    // 이미 저장된 `MemberDBModel` 객체를 사용
                    try realm.write {
                        existingUser.nickname = user.nickname
                    }
                    object.user = existingUser
                } else {
                    // 새로운 유저를 저장
                    try realm.write {
                        realm.add(user)
                    }
                }
            }
            // 채팅 추가
            try realm.write {
                channel.chattings.append(object)
            }
        },
        createDMChatting: { roomID, object in
            let realm = try Realm()
            guard let dmRoom = realm.object(
                ofType: DMRoomDBModel.self,
                forPrimaryKey: roomID
            ) else {
                print("DM룸을 찾을 수 없습니다.")
                return
            }
            // `object.user`가 중복되는지 확인하고 처리
            if let user = object.user {
                if let existingUser = realm.object(
                    ofType: MemberDBModel.self,
                    forPrimaryKey: user.userID
                ) {
                    // 이미 저장된 `MemberDBModel` 객체를 사용
                    try realm.write {
                        existingUser.nickname = user.nickname
                    }
                    object.user = existingUser
                } else {
                    // 새로운 유저를 저장
                    try realm.write {
                        realm.add(user)
                    }
                }
            }
            // 채팅 추가
            try realm.write {
                dmRoom.chattings.append(object)
            }
        },
        updateChannel: { channel, channelName, members in
            let realm = try Realm()
            try realm.write {
                channel.channelName = channelName
                for newMember in members {
                    if let existingMember = realm.object(
                        ofType: MemberDBModel.self,
                        forPrimaryKey: newMember.userID
                    ) {
                        // 이미 존재하면 필요한 필드만 업데이트
                        existingMember.nickname = newMember.nickname
                        existingMember.profileImage = newMember.profileImage
                    } else {
                        // 존재하지 않으면 추가
                        realm.add(newMember)
                    }
                    
                    // 중복 방지 후 모임 멤버 리스트에 추가
                    if !channel.members.contains(where: { $0.userID == newMember.userID }) {
                        channel.members.append(newMember)
                    }
                }
            }
        },
        fetchChannel: { channelID in
            let realm = try Realm()
            return realm.object(ofType: ChannelDBModel.self, forPrimaryKey: channelID)
        },
        fetchAllChannel: {
            let realm = try Realm()
            return Array(realm.objects(ChannelDBModel.self))
        },
        updateDMRoom: { dmRoom, members in
            let realm = try Realm()
            
            try realm.write {
                for newMember in members {
                    if let existingMember = realm.object(
                        ofType: MemberDBModel.self,
                        forPrimaryKey: newMember.userID
                    ) {
                        // 이미 존재하면 필요한 필드만 업데이트
                        existingMember.nickname = newMember.nickname
                        existingMember.profileImage = newMember.profileImage
                    } else {
                        // 존재하지 않으면 추가
                        realm.add(newMember)
                    }
                    
                    // 중복 방지 후 모임 멤버 리스트에 추가
                    if !dmRoom.members.contains(where: { $0.userID == newMember.userID }) {
                        dmRoom.members.append(newMember)
                    }
                }
            }
        },
        fetchDMRoom: { roomID in
            let realm = try Realm()
            return realm.object(ofType: DMRoomDBModel.self, forPrimaryKey: roomID)
        },
        fetchAllDMRoom: {
            let realm = try Realm()
            return Array(realm.objects(DMRoomDBModel.self))
        },
        fetchMember: { userID in
            let realm = try Realm()
            return realm.object(ofType: MemberDBModel.self, forPrimaryKey: userID)
        },
        removeAll: {
            let realm = try Realm()
            try realm.write {
                realm.deleteAll()
            }
        }
    )
}

extension DependencyValues {
    var dbClient: DBClient {
        get { self[DBClient.self] }
        set { self[DBClient.self] = newValue }
    }
}
