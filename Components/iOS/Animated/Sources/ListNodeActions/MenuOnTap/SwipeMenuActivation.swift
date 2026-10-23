/// Keeps menu activation ordering explicit: close the row, then run the action.
public enum SwipeMenuActivation {
    public static func perform(close: () -> Void, action: () -> Void) {
        close()
        action()
    }
}
