//
//  ContentView.swift
//  atria
//
//  Created by Pavel Kroupa on 09.04.2025.
//

import SwiftUI

struct ContentView: View {
    @State private var selection: PathRoute? = .descriptionConvertor

    var body: some View {
        NavigationSplitView {
            List(selection: $selection) {
                NavigationLink("Description Convertor", value: PathRoute.descriptionConvertor)
            }
            .navigationTitle("Sidebar")
        } detail: {
            switch selection {
            case .descriptionConvertor:
                DescriptionConvertorScreen()
            case nil:
                Text("Select a screen")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }
}

#Preview {
    ContentView()
}
