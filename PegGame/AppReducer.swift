import SwiftUI
import ComposableArchitecture


// 1. how do you calculate available moves?
// 2. how do you undo moves?
// 3. how do you know when it's done?
// 6. timer?

struct AppReducer: Reducer {
  struct State: Equatable {
    @BindingState var pegs = Peg.grid()
    @BindingState var selection: Peg? = nil
  }
  enum Action: BindableAction, Equatable {
    case pegTapped(Peg)
    case restartButtonTapped
    case binding(BindingAction<State>)
  }
  var body: some ReducerOf<Self> {
    BindingReducer()
    Reduce { state, action in
      switch action {
        
      case let .pegTapped(value):
        UIImpactFeedbackGenerator(style: .soft).impactOccurred()
        
        if state.isFirstMove {
          state.pegs[id: value.id]?.completed = true
          state.selection = nil
          return .none
        }
        guard state.availableMoves.contains(value) else {
          state.selection = value
          return .none
        }
        guard let selection = state.selection else {
          state.selection = state.selection == value ? nil : value
          return .none
        }
        guard !state.pegBetween(selection, value).completed else {
          return .none
        }
        state.pegs[id: state.pegBetween(selection, value).id]?.completed = true
        state.pegs[id: selection.id]?.completed = true
        state.pegs[id: value.id]?.completed = false
        state.selection = nil
        return .none
        
      case .restartButtonTapped:
        state.selection = nil
        state.pegs = Peg.grid()
        return .none
        
      case .binding:
        return .none
        
      }
    }
  }
}

struct Peg: Identifiable, Equatable {
  var id: [Int] { [row, col] }
  let row: Int
  let col: Int
  var completed = false

  static func grid() -> IdentifiedArrayOf<Peg> {
    IdentifiedArrayOf<Peg>(
      uniqueElements: (0..<5).map { row in
        (0..<row+1).map {
          Peg(row: row, col: $0)
        }
      }.flatMap {
        $0
      }
    )
  }
}

extension AppReducer.State {
  var isFirstMove: Bool {
    pegs.filter(\.completed).isEmpty
  }
  
  var availableMoves: IdentifiedArrayOf<Peg> {
    guard let selection = selection else { return [] }
    
    return .init(uniqueElements: [
      pegs[id: [selection.row+0, selection.col-2]], // left
      pegs[id: [selection.row+0, selection.col+2]], // right
      pegs[id: [selection.row-2, selection.col-2]], // up+left
      pegs[id: [selection.row-2, selection.col+0]], // up+right
      pegs[id: [selection.row+2, selection.col]],   // down+left
      pegs[id: [selection.row+2, selection.col+2]], // down+right
    ]
      .compactMap { $0 }
      .filter { $0.completed }
    )
  }
  
  var availableForCompletion: IdentifiedArrayOf<Peg> {
    guard let selection = selection else { return [] }
    
    return .init(uniqueElements: [
      pegs[id: [selection.row+0, selection.col-1]], // left
      pegs[id: [selection.row+0, selection.col+1]], // right
      pegs[id: [selection.row-1, selection.col-1]], // up+left
      pegs[id: [selection.row-1, selection.col+0]], // up+right
      pegs[id: [selection.row+1, selection.col]],   // down+left
      pegs[id: [selection.row+1, selection.col+1]], // down+right
    ].compactMap { $0 })
  }
  
  func pegBetween(_ a: Peg, _ b: Peg) -> Peg {
    pegs[id: [
      (a.row - b.row) == 0 ? a.row : {
        switch (a.row - b.row) {
        case +2: return -1 + a.row
        case -2: return +1 + a.row
        default: fatalError()
        }
      }(),
      (a.col - b.col) == 0 ? a.col : {
        switch (a.col - b.col) {
        case +2: return -1 + a.col
        case -2: return +1 + a.col
        default: fatalError()
        }
      }()
    ]]!
  }
}

// MARK: - SwiftUI

struct AppView: View {
  let store: StoreOf<AppReducer>
  
  var body: some View {
    WithViewStore(store, observe: { $0 }) { viewStore in
      NavigationStack {
        VStack {
          ForEach(0..<5) { row in
            HStack {
              ForEach(0..<row+1) { col in
                pegView(peg: viewStore.pegs[id: [row, col]]!)
              }
            }
          }
        }
        .navigationTitle("Peg Game")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
          ToolbarItem(placement: .navigationBarLeading) {
            Button(action: {}) {
              VStack {
                HStack {
                  Text("Undo")
                  Image(systemName: "arrow.uturn.backward")
                }
              }
            }
            .disabled(true)
            .buttonStyle(.bordered)
          }
          ToolbarItem(placement: .navigationBarTrailing) {
            Button("Restart") {
              viewStore.send(.restartButtonTapped)
            }
          }
        }
      }
    }
  }
}

private extension AppView {
  private func pegView(peg: Peg) -> some View {
    WithViewStore(store, observe: { $0 }) { viewStore in
      Button(action: { viewStore.send(.pegTapped(peg)) }) {
        Circle()
          .foregroundColor(Color(.systemGray))
          .frame(width: 50, height: 50)
          .overlay {
            if viewStore.selection == peg {
              Circle().foregroundColor(.accentColor)
            }
          }
          .opacity(!peg.completed ? 1 : 0.25)
      }
      .buttonStyle(.plain)
      .animation(.default, value: viewStore.selection)
    }
  }
}

#Preview {
  AppView(store: Store(
    initialState: AppReducer.State(),
    reducer: AppReducer.init
  ))
}
