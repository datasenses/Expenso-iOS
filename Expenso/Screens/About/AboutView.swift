//
//  AboutView.swift
//  Expenso
//
//  Created by Sameer Nawaz on 31/01/21.
//

import SwiftUI

struct AboutView: View {
    
    @Environment(\.presentationMode) var presentationMode: Binding<PresentationMode>
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.primary_color.edgesIgnoringSafeArea(.all)
                
                VStack {
                    ToolbarModelView(title: "About") { self.presentationMode.wrappedValue.dismiss() }
                    
                    Spacer().frame(height: 80)
                    
                    Image("datasenses").resizable().frame(width: 120.0, height: 120.0)
                    TextView(text: "\(APP_NAME)", type: .h5).foregroundColor(Color.text_primary_color).padding(.top, 20)
                    TextView(text: "\(APP_DESC)", type: .h6).foregroundColor(Color.text_primary_color).padding(.top, 5)
                    TextView(text: "v\(Bundle.main.infoDictionary!["CFBundleShortVersionString"] ?? "")", type: .body_2)
                        .foregroundColor(Color.text_secondary_color).padding(.top, 2)
                    
                    VStack(spacing: 20) {
                        VStack(alignment: .leading, spacing: 4) {
                            HStack { Spacer() }
                            TextView(text: "ATTRIBUTIONS & LICENSE", type: .overline).foregroundColor(Color.text_primary_color)
                            TextView(text: "Licensed Under Apache License 2.0", type: .body_2)
                                .foregroundColor(Color.text_secondary_color).padding(.top, 2)
                        }
                    }.padding(20)
                    
                    Spacer()
                }.edgesIgnoringSafeArea(.all)
            }
            .navigationBarHidden(true)
        }
        .navigationViewStyle(StackNavigationViewStyle())
        .navigationBarHidden(true)
        .navigationBarBackButtonHidden(true)
    }
}

struct AboutView_Previews: PreviewProvider {
    static var previews: some View {
        AboutView()
    }
}
