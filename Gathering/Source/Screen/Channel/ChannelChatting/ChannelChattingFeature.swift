//
//  ChannelChattingFeature.swift
//  Gathering
//
//  Created by dopamint on 11/21/24.
//

import SwiftUI

import ComposableArchitecture

@Reducer
struct ChannelChattingFeature {
    
    // TODO: - 진입 시 채널 DB 저장(or 갱신)하기
    // TODO: - 채널 채팅 DB 저장
    @Dependency(\.channelClient) var channelClient
    @Dependency(\.dbClient) var dbClient
    
    @Reducer
    enum Destination {
        case channelSetting(ChannelSettingFeature)
        case profile(ProfileFeature)
    }
    
    @ObservableState
    struct State {
        @Presents var destination: Destination.State?
        
        // 이전 화면에서 전달
        var channelID: String
        
        // 특정 채널 조회 결과값 (멤버 포함)
        var currentChannel: ChannelResponse?
        
        var message: [ChattingPresentModel] = []
        
        var messageText = ""
        var selectedImages: [UIImage]? = []
        var scrollViewID = UUID()
        var keyboardHeight: CGFloat = 0
        
        var messageButtonValid = false
    }
    
    enum Action: BindableAction {
        case destination(PresentationAction<Destination.Action>)
        case binding(BindingAction<State>)
        
        case sendButtonTap
        case settingButtonTap(ChannelResponse?)
        
        case task
        case currentChannelResponse(ChannelResponse?)
        case channelChattingResponse([ChattingPresentModel])
    }
    
    var body: some ReducerOf<Self> {
        BindingReducer()
        Reduce { state, action in
            switch action {
                
            case .binding(\.messageText):
                state.messageButtonValid = !state.messageText.isEmpty
                || !(state.selectedImages?.isEmpty ?? true)
                return .none
                
            case .binding(\.selectedImages):
                state.messageButtonValid = !(state.selectedImages?.isEmpty ?? true)
                || !(state.selectedImages?.isEmpty ?? true)
                return .none
                
            case .settingButtonTap:
                // 홈뷰에서 path 처리
                return .none
           
            case .task:
                return .run { [channelID = state.channelID] send in
                    let workspaceID = UserDefaultsManager.workspaceID
                    do {
                        let channel = try await fetchChannel(
                            channelID: channelID,
                            workspaceID: workspaceID)
                        await send(.currentChannelResponse(channel))
                        
                        let message = try await fetchChannelChatting(
                            channelID: channelID,
                            workspaceID: workspaceID,
                            cursorDate: ""
                        )
                        print(message)
                        await send(.channelChattingResponse(message))
                    } catch {
                        print("채팅 패치 실패")
                    }
                }
            case .sendButtonTap:
                print("전송버튼 클릭")
                state.messageText = ""
                state.selectedImages = []
                state.messageButtonValid = false
                return .none
                
            case .currentChannelResponse(let channel):
                state.currentChannel = channel
                // DB 저장
                guard let channel else { return .none }
                
                let members: [MemberDBModel] = channel.channelMembers?.map { $0.toDBModel() } ?? []
                let dbChannel = channel.toDBModel(members)
                do {
                    try dbClient.update(dbChannel)
                } catch {
                    print("DB 채널 저장 실패")
                }
                return .none
            case .channelChattingResponse(let chatting):
                state.message = chatting
                return .none
            case .destination:
                return .none
            case .binding:
                return .none
            }
        }
        .ifLet(\.$destination, action: \.destination)
    }
    
    private func fetchChannel(
        channelID: String,
        workspaceID: String
    ) async throws -> ChannelResponse {
        // 내가 속한 채널 조회
        async let chennal = channelClient.fetchChannel(channelID, workspaceID)
        return try await chennal
    }
    
    private func fetchChannelChatting(
        channelID: String,
        workspaceID: String,
        cursorDate: String) async throws
    -> [ChattingPresentModel] {
        async let chattingList = channelClient.fetchChattingList(
            channelID,
            workspaceID,
            cursorDate
        )
        return try await chattingList.map { $0.toPresentModel() }
    }
}
