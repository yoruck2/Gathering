//
//  HomeFeature.swift
//  Gathering
//
//  Created by dopamint on 11/13/24.
//

import SwiftUI

import ComposableArchitecture

@Reducer
struct HomeFeature {
    
    @Dependency(\.workspaceClient) var workspaceClient
    @Dependency(\.userClient) var userClient
    @Dependency(\.channelClient) var channelClient
    @Dependency(\.dmsClient) var dmsClient
    @Dependency(\.realmClient) var realmClient
    
    // MARK: - 네비게이션을 통한 화면 이동
    // 내 프로필
    // 채널 채팅 뷰 -> 채널 세팅 뷰 -> 나가기 시 홈 뷰로 한번에 이동
    //           -> 다른 유저 프로필
    // DM 채팅 뷰 -> 다른 유저 프로필
    
    @Reducer
    enum Path {
        case profile(ProfileFeature)
        case channelChatting(ChannelChattingFeature)
        case channelSetting(ChannelSettingFeature)
        case dmChatting(DMChattingFeature)
    }
    
    @Reducer
    enum Destination {
        case channelAdd(CreateChannelFeature)
        case channelExplore(ExploreChannelFeature)
        case inviteMember(InviteMemberFeature)
    }
    
    @ObservableState
    struct State {
        var path = StackState<Path.State>()
        @Presents var destination: Destination.State?
        @Presents var confirmationDialog: ConfirmationDialogState<Action.ConfirmationDialog>?
        
        var isChannelExpanded = true
        var isDMExpanded = true
        
        // 워크스페이스 + 프로필 데이터
//        var myWorkspaceList: [WorkspaceResponse] = []
        var currentWorkspace: WorkspaceResponse?
        var myProfile: MyProfileResponse?
        
        var channelList: [Channel] = []
        var dmRoomList: [DMsRoom] = []
        
        var channelChattings = [Channel: [ChannelChattingResponse]]()
        var channelUnreads = [Channel: UnreadChannelResponse]()  
        var dmChattings = [DMsRoom: [DMsResponse]]()
        var dmUnreads = [DMsRoom: UnreadDMsResponse]()
        
    }
    
    enum Action: BindableAction {
        case binding(BindingAction<State>)
        case path(StackActionOf<Path>)
        case destination(PresentationAction<Destination.Action>)
        case confirmationDialog(PresentationAction<ConfirmationDialog>)
        
        enum ConfirmationDialog {
            case createChannelButtonTap
            case exploreChannelButtonTap
        }
        
        // View에서 발생하는 사용자 액션들
        case addChannelButtonTap
        case inviteMemberButtonTap
        case floatingButtonTap
        
        case channelTap(Channel)
        case dmTap(DMsRoom)
        
        case task
        
        case channelListResponse([Channel])
        case dmRoomListResponse([DMsRoom])
        case myWorkspaceResponse(WorkspaceResponse?)
        case myProfileResponse(MyProfileResponse)
        //        case myWorkspaceListResponse([WorkspaceResponse])
        case startNewMessageTap
    }
    
    var body: some ReducerOf<Self> {
        BindingReducer()
            
        Reduce { state, action in
            switch action {
                // MARK: destination -
            case .confirmationDialog(.presented(.createChannelButtonTap)):
                state.destination = .channelAdd(CreateChannelFeature.State())
                return .none
            case .confirmationDialog(.presented(.exploreChannelButtonTap)):
                state.destination = .channelExplore(ExploreChannelFeature.State())
                return .none
            case .addChannelButtonTap:
                state.confirmationDialog = ConfirmationDialogState {
                    TextState("")
                } actions: {
                    ButtonState(action: .createChannelButtonTap) {
                        TextState("채널 생성")
                    }
                    ButtonState(action: .exploreChannelButtonTap) {
                        TextState("채널 탐색")
                    }
                    ButtonState(role: .cancel) {
                        TextState("취소")
                    }
                }
                return .none
            case .inviteMemberButtonTap:
                state.destination = .inviteMember(InviteMemberFeature.State())
                return .none
            case .channelTap(let channel):
                print("채널 탭:", channel)
                state.path.append(.channelChatting(ChannelChattingFeature.State(
                    channelID: channel.id,
                    workspaceID: state.currentWorkspace?.workspace_id ?? ""
                )))
                return .none
            case .dmTap(let dmRoom):
                state.path.append(.dmChatting(DMChattingFeature.State(
                    dmsRoomResponse: dmRoom
                )))
                return .none
            case .startNewMessageTap:
                print("새 메시지 버튼 탭")
                return .none
                
            case .destination(.dismiss):
                state.destination = nil
                return .none
            case .destination:
                return .none
                
            case .floatingButtonTap:
                return .none
            case .confirmationDialog(.dismiss):
                return .none
                
            // MARK: networking -
            case .task:
//                state.isLoading = true
                return .run { send in
                    do {
                        // 워크스페이스 리스트, 유저 정보 가져오기
                        let (workspaceResult, profileResult) = try await fetchInitialData()
                        // ✅ 불러오기 성공
                        await send(.myProfileResponse(profileResult))
                        
                        if let filtered = workspaceResult.filter(
                            { $0.workspace_id == UserDefaultsManager.workspaceID }
                        ).first {
                            // UserDefaults에 있는 워크스페이스 선택
                            await send(.myWorkspaceResponse(filtered))
                        } else {
                            // UserDefaults에 없으면 첫번째 워크스페이스 선택
                            guard let workspaceID = workspaceResult.first?.workspace_id else {
                                Notification.postToast(title: "현재 워크 스페이스 없음")
                                return
                            }
                            UserDefaultsManager.recentWorkspaceID(workspaceID)
                            await send(.myWorkspaceResponse(workspaceResult.first))
                        }
                        
                        let (channelResult, dmRoomResult) = try await fetchWorkspaceDetails(
                            workspaceID: UserDefaultsManager.workspaceID
                        )
                        await send(.channelListResponse(channelResult))
                        await send(.dmRoomListResponse(dmRoomResult))
                        
                    } catch {
                        print(error)
                        print("error🔥")
                    }
                }
            case .myWorkspaceResponse(let workspace):
                state.currentWorkspace = workspace
                return .none
            case .myProfileResponse(let myProfile):
                state.myProfile = myProfile
                return .none
            case .channelListResponse(let result):
                state.channelList = result
                return .none
            case .dmRoomListResponse(let result):
                state.dmRoomList = result
                return .none
                
            case .binding(\.currentWorkspace):
                return .none
            case .binding(\.myProfile):
                return .none
            case .binding:
                return .none
            
            // MARK: - 네비게이션
            case .path(.element(id: _, action: .channelChatting(.settingButtonTap(let channel)))):
                state.path.append(.channelSetting(ChannelSettingFeature.State(
                    currentChannel: channel
                )))
                return .none
                
            case .path(.element(id: _, action: .dmChatting(.profileButtonTap(let user)))):
                print("홈 뷰에서 DM 채팅 뷰 액션 감지")
                state.path.append(.profile(ProfileFeature.State(
                    profileType: .otherUser,
                    nickname: user.nickname,
                    email: user.email,
                    profileImage: user.profileImage ?? "bird"
                )))
                return .none
                
            case .path:
                return .none
            }
        }
        .forEach(\.path, action: \.path)
        .ifLet(\.$destination, action: \.destination)
        .ifLet(\.$confirmationDialog, action: \.confirmationDialog)
    }
    
    private func fetchInitialData() async throws -> (
        workspaceList: [WorkspaceResponse],
        profile: MyProfileResponse
    ) {
        // 내가 속한 워크스페이스 리스트 조회
        async let workspaces = workspaceClient.fetchMyWorkspaceList()
        // 내 프로필 조회
        async let profile = userClient.fetchMyProfile()
        return try await (workspaces, profile)
    }
    
    private func fetchWorkspaceDetails(
        workspaceID: String
    ) async throws -> (channels: [Channel], dmRooms: [DMsRoom]) {
//        async let workspaces = workspaceClient.fetchMyWorkspaceList()
        // 채널 리스트 조회
        async let channels = channelClient.fetchMyChannelList(workspaceID)
        // DM 방 리스트 조회
        async let dmRooms = dmsClient.fetchDMSList(workspaceID)
        return try await (channels.map { $0.toChannel }, dmRooms.map { $0.toDmsRoom })
    }
    
    private func fetchChannelDetails(
        workspaceID: String,
        channelID: String,
        lastCreatedAt: String
    ) async throws -> ([ChannelChattingResponse], UnreadDMsResponse) {
        // DM 채팅 내역 리스트 조회 API
        async let fetchChattings = channelClient.fetchChattingList(
            workspaceID,
            channelID,
            lastCreatedAt
        )
        // unreadCount 조회 API
        async let fetchUnreadCount = dmsClient.fetchUnreadDMCount(
            workspaceID,
            channelID,
            lastCreatedAt
        )
        return try await (fetchChattings, fetchUnreadCount)
    }
    
    private func fetchDMRoomDetails(
        workspaceID: String,
        roomID: String,
        lastCreatedAt: String
    ) async throws -> ([DMsResponse], UnreadDMsResponse) {
        // DM 채팅 내역 리스트 조회 API
        async let fetchChattings = dmsClient.fetchDMChatHistory(
            workspaceID,
            roomID,
            lastCreatedAt
        )
        // unreadCount 조회 API
        async let fetchUnreadCount = dmsClient.fetchUnreadDMCount(
            workspaceID,
            roomID,
            lastCreatedAt
        )
        return try await (fetchChattings, fetchUnreadCount)
    }
}
