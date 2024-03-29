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
    @State private var searchText = ""
    @State private var savedTime = ""
    
    // EditMode 활성화 상태 변수 추가
    @State private var isEditing = false
        
    // 선택한 아이템을 추적하기 위한 set
    @State private var selectedNotifications = Set<UNNotificationRequest>()
    
    var filteredList: [UNNotificationRequest] {
            if searchText.isEmpty {
                return notificationManager.notifications
            } else {
                return notificationManager.notifications.filter { notification in
                    notification.content.title.localizedCaseInsensitiveContains(searchText) || notification.content.body.localizedCaseInsensitiveContains(searchText)
                }
            }
        }
    
    // dateformat하기
    private static var notificationDateFormatter: DateFormatter = {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd [HH:mm]"
        return dateFormatter
    }()
    
    private func timeDisplayText(from notification: UNNotificationRequest) -> String {
        
        guard let nextTriggerDate = (notification.trigger as? UNCalendarNotificationTrigger)?.nextTriggerDate()
        else { return "확인된 알림" }
        
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
        
        ZStack {
            //background layer
            Color.theme.background
                .ignoresSafeArea()
            
            // content layer
            NavigationView {
                VStack(spacing: 16) {
                    GeometryReader { geometry in
                        List {
                            ForEach(filteredList, id: \.self) { notification in
                                VStack(alignment: .leading) {
                                    Text(notification.content.title)
                                        .font(.system(size: 20, weight: .bold, design: .default))
                                        .frame(width: geometry.size.width - 90, alignment: .leading)
                                        .lineLimit(1)
                                        .minimumScaleFactor(0.5)
                                        .truncationMode(.tail)
                                    Spacer(minLength:3)
                                    Text(notification.content.body)
                                        .frame(width: geometry.size.width - 90 , alignment: .leading)
                                        .lineLimit(1)
                                        .minimumScaleFactor(0.5)
                                        .truncationMode(.tail)
                                    Spacer(minLength:5)
                                    Text(timeDisplayText(from: notification))
                                        .font(.system(size: 14, weight: .ultraLight, design: .default))
                                        .frame(width: geometry.size.width - 90, alignment: .leading)
                                        .lineLimit(1)
                                        .minimumScaleFactor(0.5)
                                        .truncationMode(.tail)
                                }
                                .listRowSeparator(.hidden)
                                .padding(16)
                                .background(Color.white)
                                .cornerRadius(8)
                                .shadow(radius: 2, x: 0, y: 1)
                            }
                            .onDelete(perform: delete)
                            .onMove(perform: move)
                            .frame(maxWidth: .infinity)
                        }
                        .listStyle(PlainListStyle())
                        .background(Color.clear)
                        .searchable(text: $searchText, placement: .navigationBarDrawer)
                    }
                }
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .principal) {
                        Text("Cool-Time")
                            .font(.title.bold())
                            .accessibilityAddTraits(.isHeader)
                    }
                } // 타이틀 중앙에 넣는방법.
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
                } // create 버튼
                .toolbar {
                    EditButton()
                } // edit 버튼
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
            .overlay(infoOverlayView)
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
    
    func move(from source: IndexSet, to destination: Int) {
            notificationManager.moveLocalNotifications(from: source, to: destination)
        }

}

struct NotificationListView_Previews: PreviewProvider {
    static var previews: some View {
        NotificationListView()
    }
}


