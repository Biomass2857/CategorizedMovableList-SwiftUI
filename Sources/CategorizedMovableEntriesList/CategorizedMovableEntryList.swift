import SwiftUI

@available(iOS 16, *)
public struct CategorizedMovableEntryList<T: Equatable & Hashable, Content: View>: View {
    @Binding private var isEditing: Bool
    
    @Binding private var categories: [[T]]
    private let cellBuilder: (T) -> Content
    private let backgroundColor: Color
    private let cellHeight: CGFloat = 40
    
    @State private var draggingItem: T?
    @State private var draggedFromPosition: CGFloat = .zero
    @State private var dragOffset: CGSize = .zero
    @State private var dragTargetPositon: CGPoint = .zero
    @State private var isDragging: Bool = false
    
    @Namespace private var animation
    
    public init(
        categories: Binding<[[T]]>,
        isEditing: Binding<Bool>,
        cellBuilder: @escaping (T) -> Content,
        backgroundColor: Color = .black
    ) {
        self._categories = categories
        self._isEditing = isEditing
        self.cellBuilder = cellBuilder
        self.backgroundColor = backgroundColor
    }
    
    private func isTop(item: T) -> Bool {
        item == categories.first?.first
    }
    
    private func isBottom(item: T) -> Bool {
        item == categories.last?.last
    }
    
    private func getClipShape(item: T) -> some Shape {
        if isTop(item: item) {
            return RoundedCorner(radius: 5, corners: [.topRight, .topLeft])
        }
        
        if isBottom(item: item) {
            return RoundedCorner(radius: 5, corners: [.bottomLeft, .bottomRight])
        }
        
        return RoundedCorner(radius: 0, corners: [])
    }
    
    private func getDragOffset(item: T) -> CGSize {
        guard item == draggingItem else { return .zero }
        let height = dragTargetPositon.y - draggedFromPosition - cellHeight / 2
        return CGSize(width: 0, height: height)
    }
    
    private func zIndex(item: T) -> Double {
        return item == draggingItem ? 2 : 1
    }
    
    private func isDraggingInCategory(category: [T]) -> Bool {
        if let draggingItem, category.contains(draggingItem) {
            return true
        }
        
        return false
    }
    
    private func findIndexes(of item: T) -> (Int, Int)? {
        if let categoryIndex = categories.firstIndex(where: { $0.contains(item) }) {
            let category = categories[categoryIndex]
            if let index = category.firstIndex(of: item) {
                return (categoryIndex, index)
            }
            
            return nil
        }
        
        return nil
    }
    
    private func findIndexesAt(offsetHeight: CGFloat) -> (Int, Int)? {
        var categoryIndex = 0
        var currentHeight = offsetHeight
        
        var categoryHeight = CGFloat(categories[categoryIndex].count) * cellHeight
        while currentHeight - categoryHeight > 0 {
            currentHeight -= categoryHeight
            if categoryIndex + 1 < categories.count {
                categoryIndex += 1
                categoryHeight = CGFloat(categories[categoryIndex].count) * cellHeight
            } else {
                break
            }
        }
        
        var index = Int(currentHeight) / Int(cellHeight)
        
        categoryIndex = clampZero(max: categories.count, value: categoryIndex)
        index = clampZero(max: categories[categoryIndex].count, value: index)
        
        return (categoryIndex, index)
    }
    
    private func clampZero(max: Int, value: Int) -> Int {
        if value < 0 {
            return 0
        }
        
        if value >= max {
            return max - 1
        }
        
        return value
    }
    
    private func move(item: T, to height: CGFloat) {
        guard let categoryIndex = categories.firstIndex(where: { $0.contains(item) }),
              let category = categories[safeIndex: categoryIndex],
              let inCategoryIndex = category.firstIndex(of: item)
        else {
            return
        }
        
        if let (targetCategoryIndex, targetIndex) = findIndexesAt(offsetHeight: height) {
            if 0..<categories.count ~= targetCategoryIndex {
                categories[categoryIndex].remove(at: inCategoryIndex)
                categories[targetCategoryIndex].insert(item, at: targetIndex)
            }
        }
    }
    
    private func getZeroPosition(of item: T) -> CGFloat {
        guard let (categoryIndex, index) = findIndexes(of: item)
        else { return .zero }
        
        var height: CGFloat = 0
        for previousIndex in 0..<categoryIndex {
            height += CGFloat(categories[previousIndex].count) * cellHeight
        }
        
        height += CGFloat(index) * cellHeight
        
        return height
    }
    
    private func getItemAt(position: CGPoint) -> T? {
        let flatItems: [T] = categories.reduce([]) { acc, next in return acc + next }
        
        let index: Int = Int(position.y) / Int(cellHeight)
        
        return flatItems[safeIndex: index]
    }
    
    private func cellFor(item: T) -> some View {
        VStack(spacing: 0) {
            ZStack {
                backgroundColor
                HStack {
                    HStack {
                        Spacer()
                        cellBuilder(item)
                            .animation(.easeInOut, value: item)
                            .conditionalModifier(draggingItem == item) { view in
                                view.transaction { transaction in
                                    transaction.animation = nil
                                }
                            }
                        Spacer()
                    }
                    
                    if isEditing {
                        Image(systemName: "line.horizontal.3")
                            .renderingMode(.template)
                            .foregroundColor(.white)
                            .padding()
                    }
                }
            }
            .frame(height: cellHeight)
            .clipShape(getClipShape(item: item))
            
            if !isBottom(item: item) {
                Divider()
            }
        }
        .zIndex(zIndex(item: item))
    }
    
    public var body: some View {
        VStack(spacing: 0) {
            ForEach(categories, id: \.self) { category in
                ZStack {
                    VStack(spacing: 0) {
                        ForEach(category, id: \.self) { item in
                            cellFor(item: item)
                                .matchedGeometryEffect(id: item, in: animation)
                                .offset(getDragOffset(item: item))
                        }
                    }
                    
                    if isDraggingInCategory(category: category) {
                        Rectangle()
                            .stroke(Color.red, lineWidth: 3)
                            .foregroundColor(.clear)
                            .frame(height: CGFloat(category.count) * cellHeight)
                    }
                }
            }
        }
        .gesture(
            DragGesture()
                .onChanged { dragState in
                    if isEditing {
                        isDragging = true
                        if draggingItem == nil {
                            draggingItem = getItemAt(position: dragState.startLocation)
                        }
                    
                        dragTargetPositon = dragState.location
                        dragOffset = CGSize(
                            width: 0,
                            height: dragState.translation.height
                        )
                        
                        if let draggingItem {
                            draggedFromPosition = getZeroPosition(of: draggingItem)
                            
                            move(item: draggingItem, to: dragTargetPositon.y)
                        }
                    }
                }
                .onEnded { dragState in
                    isDragging = false
                    guard let item = draggingItem else { return }
                    let targetOffsetHeight = dragState.predictedEndLocation.y
                    withAnimation {
                        move(item: item, to: targetOffsetHeight)
                        dragOffset = .zero
                        draggingItem = nil
                    }
                }
        )
    }
}

@available(iOS 16, *)
struct CatagorizedMovableList_Previews: PreviewProvider {
    static var previews: some View {
        CategorizedMovableEntryList(
            categories: .Just(value: [[1,2,3], [4,5], [6], [7,8]]),
            isEditing: .Just(value: true),
            cellBuilder: { number in
                Text("\(number)")
                    .foregroundColor(.white)
            }
        ).padding()
    }
}
