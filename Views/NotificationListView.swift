//
//  NotificationListView.swift
//  LocalNotification
//
//  Created by 길지훈 on 2022/11/14.
//


import SwiftUI

struct NotificationListView: View {
    @StateObject private var notificationManager = NotificationManager()
    //@StateObject -> 뷰안에서 안전하게 ObservedObject 인스턴스를 만들 수 있다.
    @State private var isCreatePresented = false
    
    private static var notificationDateFormatter: DateFormatter = {
        let dateFormatter = DateFormatter()
        dateFormatter.timeStyle = .short
        return dateFormatter
    }()
    
    private func timeDisplayText(from notification: UNNotificationRequest) -> String {
        guard let nextTriggerDate = (notification.trigger as?
                                     UNCalendarNotificationTrigger)?.nextTriggerDate() else { return "" }
        return Self.notificationDateFormatter.string(from: nextTriggerDate)
    }
    
    @ViewBuilder // 이 뷰에는 @ViewBuilder를 넣어주어야한다. -> body 프로퍼티는 암시적으로 이게 선언되어있다고 보면 된다.
    // 그렇기에 body외의 다른 프로퍼티나 메서드는 기본적으로 ViewBuilder를 유추하지 않기 때문에 @ViewBuilder를 명시적으로 넣어줘야한다.
    var infoOverlayView: some View {
        switch notificationManager.authorizationStatus {
        case .authorized:
            if notificationManager.notifications.isEmpty {
                InfoOverlayView(
                    infoMessage: "아직 이벤트가 생성되지 않았습니다",
                    buttonTitle: "생성하기",
                    systemImageName: "plus.circle",
                    action: {
                        isCreatePresented = true
                    }
                )
            }
        case .denied:
            InfoOverlayView(
                infoMessage: "권한을 허용해주세요",
                buttonTitle: "설정",
                systemImageName: "gear",
                action: {
                    if let url = URL(string: UIApplication.openSettingsURLString),
                        UIApplication.shared.canOpenURL(url) {
                        UIApplication.shared.open(url, options: [:], completionHandler: nil)
                    }
                }
            )
        default:
            EmptyView()
        }
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: -7) {
            
                SearchBarView(searchText: $notificationManager.searchText)
                    .padding(.bottom)
                //.background(Color.theme.accent) // 임시
                .frame(height:90)

            List{
                    ForEach(notificationManager.notifications, id: \.identifier) { notification in
                        HStack {
                            Text(notification.content.title)
                                .fontWeight(.semibold)
                            
                            Text(timeDisplayText(from: notification))
                                .fontWeight(.bold)
                            Spacer()
                        }
                    }
                    .onDelete(perform: delete)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("언제드라?")
                        .font(.largeTitle.bold())
                        .accessibilityAddTraits(.isHeader)
                }
            } // 타이틀 중앙에 넣는방법.
            .listStyle(.plain)
            .overlay(infoOverlayView)
            .onAppear(perform: notificationManager.reloadAuthorizationStatus)
            .onChange(of: notificationManager.authorizationStatus) { authorizationStatus in
                switch authorizationStatus {
                case .notDetermined: // When First Opening App.
                    //request authorization
                    notificationManager.requestAuthorization()
                case .authorized:
                    //get local notifications
                    notificationManager.reloadLocalNotifications()
                default: //don't allow
                    break
                }
            }
            .onReceive(NotificationCenter.default.publisher(for:
                UIApplication.willEnterForegroundNotification)) { _ in
                notificationManager.reloadAuthorizationStatus()
            }
            .toolbar {
                Button {
                    isCreatePresented = true
                } label: {
                    Image(systemName: "plus.circle")
                        .imageScale(.large)
                }
            }
            .sheet(isPresented: $isCreatePresented) {
                NavigationView {
                    CreateNotificationView(
                        notificationManager: notificationManager, // !!!! 오류 해결 !!!!
                        isPresented: $isCreatePresented
                    )
                }
                .accentColor(.primary)
        }
        }
        }
    }
}

extension NotificationListView {
    func delete(_ indexSet: IndexSet) {
        notificationManager.deleteLocalNotifications(
            identifiers: indexSet.map { notificationManager.notifications[$0].identifier }
        )
        notificationManager.reloadLocalNotifications()
    }
}

struct NotificationListView_Previews: PreviewProvider {
    static var previews: some View {
        NotificationListView()
            .preferredColorScheme(.dark)
    }
}
