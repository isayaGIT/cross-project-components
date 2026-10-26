在好几个地方都有, 所以干脆统一设定一下

Status: character/user status
    cases: online, offline, replying, error
    colors: green, gray, yellow, red
    texts: 在线, 离线, 正在输入.. , 出错了!
    onAction: nil, nil, stream(这里之后做一个通用的组件, 能显示llm通信情况, input, output情况, 总之任何真实的本次回复有关的内容和信息), error message(这里之后做一个组件,能很好的显示错误的)