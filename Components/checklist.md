current working on:
Sheet-ConfigSheet
Scree-Chat
Screen-Moments
Screen-Dashboard
    一日一页, 两个人的日记本
    两个耳机, 两人一起听音乐
    表示通话的, 两个人通电话
    消息树/记忆树, 点进去可以节点重温


ImgView
MomentSingleMoment
Animated/SlideDownDismiss

finished:
Avatar
InputBar
MessageBubble
LineDashed
ImgThumbnail
RoundedRectSmoothed
Capsules
StickerKeyboard
SheetConfig / BottomSheet
Banner
Animated/Popin
MessageListNode
UnreadBadge

not good enough but considered finished:
StickerKeyboard (背景、边框要能够自定义; 需要统一所有用到的背景为参数可以传入; 组件出现太生硬缺少动画)
SheetConfig / BottomSheet
Banner(丑死, 字体大小、字体、背景、边框、shape都要传参数)
ImgPolaroid(旋转范围只有90度)
Animated/PressedDown(丑)
MessageListNode(左滑菜单这个动画太墨迹)

还需要做:
通过message chunk直接配置 avatar, 所有Integrated的component都需要暴露子component, 避免出现传参遗漏. (如果不这样做, 一定会发生遗漏)
确保多用这个, 这个太漂亮了我太喜欢了 https://swiftpieces.com/docs/components/feedback/reaction-toggle

Components todo:
名片(点击头像出现)
设置界面
    API route
    providers 以及自定义的支持
    elevenlabs v4
    长按message bubble, 重新生成、删除、切换message tree等




Future Todo:
头像拍一拍的文本
