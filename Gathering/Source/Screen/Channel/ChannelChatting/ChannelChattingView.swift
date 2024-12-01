//
//  ChannelChattingView.swift
//  Gathering
//
//  Created by dopamint on 11/21/24.
//

import SwiftUI

import ComposableArchitecture
import Combine

struct ChannelChattingView: View {
    
    @Perception.Bindable var store: StoreOf<ChannelChattingFeature>
    
    @Environment(\.dismiss) private var dismiss
    var keyboardSubscriber: AnyCancellable?
    
    var body: some View {
        WithPerceptionTracking {
            mainContent
        }
    }
    
    private var mainContent: some View {
        VStack {
            // 채팅 메시지 리스트
            chatListView
            // 채팅보내는 부분
            messageInputView
        }
        .navigationBarBackButtonHidden()
        .task { store.send(.task) }
        .onTapGesture {
            // 화면을 탭할 때 키보드 내리기
            hideKeyboard()
        }
        .onDisappear {
            // 뷰가 사라질 때 키보드 노티피케이션 구독 해제
            keyboardSubscriber?.cancel()
        }
        .customToolbar(
            title: store.currentChannel?.name ?? "",
            leftItem: .init(icon: .chevronLeft) {
                dismiss()
            },
            rightItem: .init(icon: .list) {
                store.send(.settingButtonTap(store.currentChannel))
            }
        )
    }
    
    private var chatListView: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack {
                    ForEach(store.message) { message in
                        if message.isMine {
                            myMessageView(message: message)
                        } else {
                            othersMessageView(message: message)
                        }
                    }
                }
                .padding(.horizontal, 20)
                .id(store.scrollViewID)
            }
            .frame(maxWidth: .infinity)
            .onAppear {
                proxy
                    .scrollTo(store.scrollViewID, anchor: .bottom)
                // TODO: 이걸로 바꿀 수 있을까요?
//                scrollToBottom(proxy: proxy)
            }
            // 메시지 추가 시 자동 스크롤
            .onChange(of: store.message.count) { _ in
                withAnimation {
                    proxy.scrollTo(store.scrollViewID, anchor: .bottom)
                }
//                scrollToBottom(proxy: proxy)
            }
        }
    }
    
    private func scrollToBottom(proxy: ScrollViewProxy) {
        withAnimation {
            proxy.scrollTo(store.scrollViewID, anchor: .bottom)
        }
    }
    
    private var messageInputView: some View {
        HStack {
            HStack(alignment: .bottom) {
                ChattingPhotoPicker(selectedImages: $store.selectedImages) {
                    Image(systemName: "plus")
                        .resizable()
                        .frame(width: 22, height: 20)
                        .foregroundColor(Design.darkGray)
                }
                
                VStack(alignment: .leading) {
                    dynamicHeigtTextField()
                    if let images = store.selectedImages, !images.isEmpty {
                        selectePhotoView(images: images)
                    }
                }
                
                Button {
                    store.send(.sendButtonTap)
                } label: {
                    Image(systemName: "paperplane.fill")
                        .font(.system(size: 20))
                        .foregroundColor(store.messageButtonValid
                                       ? Design.green : Design.darkGray)
                }
                .disabled(!store.messageButtonValid)
            }
            .padding(.vertical, 14)
            .padding(.horizontal, 12)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .foregroundColor(Design.background)
            )
        }
        .padding(.vertical, 14)
        .padding(.horizontal, 16)
    }
    
    private func dynamicHeigtTextField() -> some View {
        TextField("메세지를 입력하세요", text: $store.messageText, axis: .vertical)
            .lineLimit(1...5)
            .background(Color.clear)
            .font(Design.body)
    }
    
    private func selectePhotoView(images: [UIImage]) -> some View {
        LazyHGrid(rows: [GridItem(.fixed(50))], spacing: 12) {
            ForEach(images, id: \.self) { image in
                photoItem(image: image)
            }
        }
        .frame(height: 55)
    }
    
    private func photoItem(image: UIImage) -> some View {
        ZStack {
            Image(uiImage: image)
                .resizable()
                .frame(width: 44, height: 44)
                .aspectRatio(contentMode: .fill)
                .clipShape(RoundedRectangle(cornerRadius: 8))
            
            Button {
                print("클릭클릭")
            } label: {
                Image(systemName: "xmark.circle")
                    .resizable()
                    .frame(width: 20, height: 20)
                    .foregroundColor(Design.black)
                    .background(
                        Circle()
                            .size(width: 20, height: 20)
                            .foregroundColor(Design.white)
                    )
                    .offset(x: 22, y: -22)
            }
        }
    }
    
    private func myMessageView(message: ChattingPresentModel) -> some View {
        VStack(alignment: .trailing) {
            HStack(alignment: .bottom) {
                Spacer()
                Text(message.date.toString(.todayChat))
                    .font(Design.caption2)
                    .foregroundStyle(Design.darkGray)
                VStack(alignment: .leading) {
                    if let text = message.text {
                        Text(text)
                            .font(Font.body)
                            .padding(8)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Design.white)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Design.gray, lineWidth: 1)
                            )
                        if !message.imageNames.isEmpty {
                            ChattingImageView(imageNames: message.imageNames)
                        }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity)
    }
    
    private func othersMessageView(message: ChattingPresentModel) -> some View {
        HStack(alignment: .top) {
            ProfileImageView(urlString: message.profile ?? "bird", size: 34)
            VStack(alignment: .leading) {
                Text(message.name)
                    .font(Design.caption)
                HStack(alignment: .bottom) {
                    VStack(alignment: .leading) {
                        if let text = message.text {
                            Text(text)
                                .font(Font.body)
                                .padding(8)
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(Design.white)
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(Design.gray, lineWidth: 1)
                                )
                        }
                    }
                    Text(message.date.toString(.todayChat))
                        .font(Design.caption2)
                        .foregroundStyle(Design.darkGray)
                    Spacer()
                }
            }
            .frame(maxWidth: .infinity)
        }
        .padding(.bottom, 5)
    }
}
