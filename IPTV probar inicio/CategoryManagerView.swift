import SwiftUI

// MARK: - Category Manager View (Dual Tab: Server + Custom)

struct CategoryManagerView: View {
    @EnvironmentObject private var viewModel: AppViewModel
    @Environment(\.dismiss) private var dismiss

    enum Tab: String, CaseIterable {
        case server       = "Servidor"
        case custom       = "Personalizadas"
    }

    @State private var selectedTab: Tab = .server
    @State private var searchText = ""
    @State private var showingAddCustom = false
    @State private var editingCustom: CustomCategory?

    private var currentType: MediaType { viewModel.selectedType }

    private var serverSections: [HomeSection] {
        viewModel.allServerSections(for: currentType)
    }

    private var filteredServerSections: [HomeSection] {
        let trimmed = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return serverSections }
        return serverSections.filter { $0.title.localizedCaseInsensitiveContains(trimmed) }
    }

    private var customCats: [CustomCategory] {
        viewModel.customCategoriesForType(currentType)
    }

    private var visibleCount: Int {
        serverSections.filter { !viewModel.isHidden(categoryId: $0.id) }.count
    }

    private var hiddenCount: Int {
        serverSections.filter { viewModel.isHidden(categoryId: $0.id) }.count
    }

    var body: some View {
        ZStack {
            Color(red: 0.07, green: 0.07, blue: 0.11).ignoresSafeArea()

            VStack(spacing: 0) {
                header
                    .padding(.horizontal, 24)
                    .padding(.top, 20)
                    .padding(.bottom, 12)

                // Segmented picker
                Picker("", selection: $selectedTab) {
                    ForEach(Tab.allCases, id: \.self) { tab in
                        Text(tab.rawValue).tag(tab)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, 24)
                .padding(.bottom, 12)

                Divider().background(Color.white.opacity(0.1))

                // Tab content
                switch selectedTab {
                case .server:
                    serverTabContent
                case .custom:
                    customTabContent
                }
            }
        }
        .frame(minWidth: 600, minHeight: 480)
        .preferredColorScheme(.dark)
        .sheet(isPresented: $showingAddCustom) {
            CustomCategoryEditorView(mode: .add, type: currentType, serverSections: serverSections)
                .environmentObject(viewModel)
        }
        .sheet(item: $editingCustom) { cat in
            CustomCategoryEditorView(mode: .edit(cat), type: currentType, serverSections: serverSections)
                .environmentObject(viewModel)
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Gestionar categorías")
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)

                Text("\(currentType.rawValue) · \(visibleCount) visibles · \(hiddenCount) ocultas · \(customCats.count) personalizadas")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.5))
            }

            Spacer()

            Button { dismiss() } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.title2)
                    .foregroundStyle(.white.opacity(0.4))
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Server Tab

    private var serverTabContent: some View {
        VStack(spacing: 0) {
            // Search + quick actions
            VStack(spacing: 10) {
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(.white.opacity(0.4))
                        .font(.system(size: 13))
                    TextField("Buscar categorías…", text: $searchText)
                        .textFieldStyle(.plain)
                        .font(.system(size: 13))
                        .foregroundStyle(.white)
                    if !searchText.isEmpty {
                        Button { searchText = "" } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(.white.opacity(0.3))
                                .font(.system(size: 11))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 8))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.white.opacity(0.1), lineWidth: 1)
                )

                HStack(spacing: 12) {
                    Button { viewModel.showAllCategories() } label: {
                        Label("Mostrar todas", systemImage: "eye")
                            .font(.caption.weight(.medium))
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(Color(red: 0.4, green: 0.7, blue: 0.5))

                    Button { viewModel.hideAllCategories(for: currentType) } label: {
                        Label("Ocultar todas", systemImage: "eye.slash")
                            .font(.caption.weight(.medium))
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.orange.opacity(0.8))

                    Spacer()

                    Text("\(serverSections.count) del servidor")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.3))
                }
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 12)

            Divider().background(Color.white.opacity(0.06))

            // Server categories list
            ScrollView {
                LazyVStack(spacing: 4) {
                    ForEach(filteredServerSections) { section in
                        let isHidden = viewModel.isHidden(categoryId: section.id)
                        Button { viewModel.toggleHideCategory(id: section.id) } label: {
                            HStack(spacing: 14) {
                                Image(systemName: isHidden ? "eye.slash.circle.fill" : "eye.circle.fill")
                                    .font(.title3)
                                    .foregroundStyle(isHidden ? .orange.opacity(0.6) : Color(red: 0.35, green: 0.65, blue: 0.45))

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(section.title)
                                        .font(.subheadline.weight(.medium))
                                        .foregroundStyle(.white.opacity(isHidden ? 0.35 : 1.0))
                                    Text("\(section.items.count) elementos")
                                        .font(.caption)
                                        .foregroundStyle(.white.opacity(0.25))
                                }

                                Spacer()

                                Text(isHidden ? "Oculta" : "Visible")
                                    .font(.caption2.weight(.semibold))
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 3)
                                    .background(
                                        isHidden ? Color.orange.opacity(0.15) : Color.green.opacity(0.12),
                                        in: Capsule()
                                    )
                                    .foregroundStyle(isHidden ? .orange.opacity(0.8) : Color(red: 0.35, green: 0.7, blue: 0.45))
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                            .background(RoundedRectangle(cornerRadius: 10).fill(Color.white.opacity(isHidden ? 0.02 : 0.04)))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
            }
        }
    }

    // MARK: - Custom Tab

    private var customTabContent: some View {
        VStack(spacing: 0) {
            // Add button
            HStack {
                Text("Agrupa categorías del servidor bajo un nombre personalizado.")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.4))
                Spacer()
                Button { showingAddCustom = true } label: {
                    Label("Nueva", systemImage: "plus.circle.fill")
                        .font(.subheadline.weight(.semibold))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 6)
                }
                .buttonStyle(.borderedProminent)
                .tint(Color(red: 0.35, green: 0.45, blue: 1.0))
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 12)

            Divider().background(Color.white.opacity(0.06))

            if customCats.isEmpty {
                VStack(spacing: 14) {
                    Spacer()
                    Image(systemName: "folder.badge.plus")
                        .font(.system(size: 44))
                        .foregroundStyle(.white.opacity(0.12))
                    Text("Sin categorías personalizadas")
                        .font(.headline)
                        .foregroundStyle(.white.opacity(0.25))
                    Text("Las personalizadas aparecen primero en el dashboard.")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.15))
                    Spacer()
                }
                .frame(maxWidth: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 10) {
                        ForEach(customCats) { cat in
                            customCategoryRow(cat)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                }
            }
        }
    }

    private func customCategoryRow(_ cat: CustomCategory) -> some View {
        let serverNames = serverSections
            .filter { section in
                let rawId = AppViewModel.extractRawCatId(from: section.id)
                return cat.serverCategoryIds.contains(rawId)
            }
            .map(\.title)

        return HStack(spacing: 14) {
            RoundedRectangle(cornerRadius: 5)
                .fill(
                    LinearGradient(
                        colors: [Color(red: 0.35, green: 0.45, blue: 1.0), Color(red: 0.5, green: 0.3, blue: 1.0)],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    )
                )
                .frame(width: 5, height: 40)

            VStack(alignment: .leading, spacing: 3) {
                Text(cat.name)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                Text("\(cat.serverCategoryIds.count) cat. → " + (serverNames.prefix(3).joined(separator: ", ")) + (serverNames.count > 3 ? "…" : ""))
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.35))
                    .lineLimit(1)
            }

            Spacer()

            Button { editingCustom = cat } label: {
                Image(systemName: "pencil.circle.fill")
                    .font(.title3)
                    .foregroundStyle(.white.opacity(0.35))
            }
            .buttonStyle(.plain)

            Button { viewModel.deleteCustomCategory(id: cat.id) } label: {
                Image(systemName: "trash.circle.fill")
                    .font(.title3)
                    .foregroundStyle(.red.opacity(0.5))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(RoundedRectangle(cornerRadius: 10).fill(Color.white.opacity(0.04)))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.white.opacity(0.06), lineWidth: 1))
    }
}

// MARK: - Custom Category Editor (Add / Edit)

struct CustomCategoryEditorView: View {
    enum Mode: Identifiable {
        case add
        case edit(CustomCategory)
        var id: String {
            switch self {
            case .add:           return "add"
            case .edit(let cat): return cat.id.uuidString
            }
        }
    }

    @EnvironmentObject private var viewModel: AppViewModel
    @Environment(\.dismiss) private var dismiss

    let mode: Mode
    let type: MediaType
    let serverSections: [HomeSection]

    @State private var name = ""
    @State private var selectedIds: Set<String> = []
    @State private var searchText = ""

    private var isEditing: Bool {
        if case .edit = mode { return true }
        return false
    }

    private var filteredServerSections: [HomeSection] {
        let trimmed = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return serverSections }
        return serverSections.filter { section in
            section.title.localizedCaseInsensitiveContains(trimmed) ||
            section.items.contains { $0.title.localizedCaseInsensitiveContains(trimmed) }
        }
    }

    var body: some View {
        ZStack {
            Color(red: 0.07, green: 0.07, blue: 0.11).ignoresSafeArea()

            VStack(spacing: 0) {
                HStack {
                    Text(isEditing ? "Editar categoría" : "Nueva categoría")
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                    Spacer()
                    Button { dismiss() } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title2)
                            .foregroundStyle(.white.opacity(0.4))
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 24).padding(.top, 20).padding(.bottom, 12)

                Divider().background(Color.white.opacity(0.1))

                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        // Name
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Nombre").font(.subheadline.weight(.semibold)).foregroundStyle(.white.opacity(0.7))
                            TextField("Ej: Deportes, Cine, Infantil…", text: $name)
                                .textFieldStyle(.plain)
                                .font(.body)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 10)
                                .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 10))
                                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.white.opacity(0.12), lineWidth: 1))
                                .foregroundStyle(.white)
                        }

                        Divider().background(Color.white.opacity(0.06))

                        // Server categories multi-select
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Categorías (\(selectedIds.count) seleccionadas)")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.white.opacity(0.7))

                            HStack(spacing: 8) {
                                Image(systemName: "magnifyingglass")
                                    .foregroundStyle(.white.opacity(0.4)).font(.system(size: 12))
                                TextField("Buscar…", text: $searchText)
                                    .textFieldStyle(.plain).font(.system(size: 13)).foregroundStyle(.white)
                            }
                            .padding(.horizontal, 12).padding(.vertical, 7)
                            .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 8))

                            HStack(spacing: 12) {
                                Button("Seleccionar todo") {
                                    for s in filteredServerSections {
                                        selectedIds.insert(extractRawId(from: s.id))
                                    }
                                }.font(.caption.weight(.medium)).foregroundStyle(Color(red: 0.4, green: 0.55, blue: 1.0))
                                Button("Deseleccionar") {
                                    if searchText.isEmpty { selectedIds.removeAll() }
                                    else { for s in filteredServerSections { selectedIds.remove(extractRawId(from: s.id)) } }
                                }.font(.caption.weight(.medium)).foregroundStyle(.white.opacity(0.4))
                                Spacer()
                            }.buttonStyle(.plain)
                        }

                        LazyVStack(spacing: 4) {
                            ForEach(filteredServerSections) { section in
                                let rawId = extractRawId(from: section.id)
                                let sel = selectedIds.contains(rawId)

                                DisclosureGroup {
                                    // Show items inside this category
                                    ForEach(section.items) { item in
                                        HStack(spacing: 8) {
                                            if let url = item.artworkURL {
                                                CachedAsyncImage(url: url)
                                                    .frame(width: 28, height: 28)
                                                    .cornerRadius(4)
                                            }
                                            Text(item.title)
                                                .font(.caption)
                                                .foregroundStyle(.white.opacity(0.5))
                                                .lineLimit(1)
                                            Spacer()
                                        }
                                        .padding(.leading, 24)
                                        .padding(.vertical, 2)
                                    }
                                } label: {
                                    Button {
                                        if sel { selectedIds.remove(rawId) } else { selectedIds.insert(rawId) }
                                    } label: {
                                        HStack(spacing: 10) {
                                            Image(systemName: sel ? "checkmark.circle.fill" : "circle")
                                                .foregroundStyle(sel ? Color(red: 0.35, green: 0.45, blue: 1.0) : .white.opacity(0.25))
                                            Text(section.title).font(.subheadline)
                                                .foregroundStyle(.white.opacity(sel ? 1 : 0.5))
                                            Spacer()
                                            Text("\(section.items.count)").font(.caption)
                                                .foregroundStyle(.white.opacity(0.3))
                                                .padding(.horizontal, 7).padding(.vertical, 2)
                                                .background(Color.white.opacity(0.06), in: Capsule())
                                        }
                                    }.buttonStyle(.plain)
                                }
                                .tint(.white.opacity(0.3))
                                .padding(.horizontal, 12).padding(.vertical, 5)
                                .background(RoundedRectangle(cornerRadius: 8).fill(sel ? Color.white.opacity(0.05) : .clear))
                            }
                        }
                    }
                    .padding(24)
                }

                Divider().background(Color.white.opacity(0.1))

                HStack {
                    Spacer()
                    Button { save(); dismiss() } label: {
                        Text(isEditing ? "Guardar" : "Crear")
                            .font(.headline)
                            .padding(.horizontal, 24).padding(.vertical, 10)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(Color(red: 0.35, green: 0.45, blue: 1.0))
                    .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || selectedIds.isEmpty)
                }
                .padding(16)
            }
        }
        .frame(minWidth: 520, minHeight: 480)
        .preferredColorScheme(.dark)
        .onAppear {
            if case .edit(let cat) = mode {
                name = cat.name
                selectedIds = Set(cat.serverCategoryIds)
            }
        }
    }

    private func save() {
        let n = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !n.isEmpty, !selectedIds.isEmpty else { return }
        switch mode {
        case .add:
            viewModel.addCustomCategory(name: n, type: type, serverCategoryIds: Array(selectedIds))
        case .edit(var cat):
            cat.name = n
            cat.serverCategoryIds = Array(selectedIds)
            viewModel.updateCustomCategory(cat)
        }
    }

    private func extractRawId(from sectionId: String) -> String {
        AppViewModel.extractRawCatId(from: sectionId)
    }
}
