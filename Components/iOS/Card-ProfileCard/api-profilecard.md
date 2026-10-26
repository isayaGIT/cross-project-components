 个人信息页, 自己、角色都通用

profile image
profile background image (ImgThumbnail 固定的比例 就现在这个比例 一个横躺的矩形)
card background image (这里为之后主题做准备, 先支持用静态图)
name text, font, fontsize, color
signature text, font, fontsize, color
recent moments(这里是最近ta发的朋友圈的图, 只计算有图/视频的朋友圈, 显示4个, 用我们写的ImgThumbnail 正方形)
card action panel:
    语音通话 button, 字体、button底色 需要加入protocol, 每个主题文件必须给出
    一起听 button, 字体、button底色 需要加入protocol, 每个主题文件必须给出
    发消息 button, 字体、button底色 需要加入protocol, 每个主题文件必须给出
    // 一行显示这两个buttons, 其中“语音通话”、一起听 button小一些(可能只占到1/5)


design:
background image/gif
profile image
name (在同一行中) status
signature
recent moment container
card action panel


// todo
去掉灰色遮罩, 改为给card加一个立体阴影, 因为灰色遮罩很麻烦需要确认层次, 比如现在这个theme button就没有被遮罩到

group1 color (这里是为了之后有按钮用的配色, 一个界面不需要给很多配色, 这个group1就表示主要配色, group数字越大越次要)
group2 color
group3 color
group4 color
group5 color (预留一些)