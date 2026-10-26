每个都用一个button来做, 这个button是RoundedRectSmoothed, 但是给个参数用圆角矩形而不是默认的圆形来做

要有这些buttons, 一行最多5个, 最多2行,  更多就要翻页(目前不用写)
先定义好所有buttons, 然后写一个list表示顺序, 
1 2 3 4
5 6 7 8
  ..(表示翻页, apple主界面那种圆点)
这样的布局. 

list:
图片
相机
音乐
位置


## ScreenChat 默认操作

`ScreenChat` 的输入面板默认显示四个入口：图片、相机、音乐、位置。通过 `onInputAction` 将图片、相机和位置操作交给宿主应用处理；宿主负责系统选择器、权限、定位和上传等具体业务。音乐入口同时调用现有的 `onOpenApp(.music)`，并通知 `onInputAction(.music)`。这使组件不需要擅自申请宿主应用的系统权限，也不把业务逻辑耦合进展示网格。

```swift
ScreenChat(
    onOpenApp: { app in
        // 处理既有的应用导航，例如音乐
    },
    onInputAction: { action in
        switch action {
        case .image: /* 打开照片选择器 */ break
        case .camera: /* 检查权限后打开相机 */ break
        case .music: /* 处理音乐入口 */ break
        case .location: /* 请求定位并分享位置 */ break
        }
    }
)
```
