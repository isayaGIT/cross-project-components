关于“应用” button打开后的这个action panel, 我觉得 过于丑陋!! 我要大改特改!!!

主界面: 月历, 每天的表情是一个贴纸, 点击可以显示当天的文本记录, 像是消息气泡一样显示出来

我觉得可以这样, 通过缩放实现两个界面的打通, 主界面月历 , 双指捏合可以随着有个缩放过程, 然后缩放过程把它们都排成一行, 相当于每天的卡片从月历中慢慢自己排成一行, 然后进入coverflow式的卡片view, 可以左右滑动切换主要显示的卡片
连续的空间变形交互（Continuous Spatial Transformation）
这样可以体现出, 它们始终是同一批卡片，只是排列方式随着缩放发生了变化

todo:
1. 月历视图
2. coverflow视图
3. 捏合、放大 动画
// 按顺序做

任务说明: 
一、月历视图
1. 只需要做月历, 找swifft pieces、github已经做好的
2. 与传统月历的区别是, 每个日格子都是1宽2高的(因为要容纳两个人在当天所选择的sticker)
calendar container
month · year
weekday bar 
week1 
week2
...

borders: (这些lines都需要能够自定义, weight=0就是不绘制不要显示的意思, 要能够支持DashedLine component)
外边框(把weekday bar一直到最后一行整个包起来的边框) 可以传入offset, 正数表示在往外拓一些, 负数表示向内缩一些, 但是缩的是路径而不是line的样式, 比如不能因为缩放影响line weight、dashed line 每个线的长度、线段与线段间距等(这个由谁来负责?)
between weekdays (weekdays的分割线)
between daycells, vertical lines
between weeks, horizontal line




calendar:
month(这个应该有数据, 具体的几几年几月, 这个要用来确定需要显示哪些天、都是星期几)
month text color, font
year text color, font
weekday text color, font

day cell:
    sticker1
    sticker2

define sticker class
sticker:
    img
    sticker color (找开源实现, 应该有把sticker做出来的, swift pieces找) 这个color意思是img外拓的一圈描边的color, 因为贴纸都有一圈白在外面, 所以默认用白色, 然后如果nil的话就是不要显示这个, 如果这个不显示的话, 立体度就是直接给到img本身外边的阴影. 
    sticker weight(表示贴纸白边的宽度, 要给个合理的默认值, 但是外部也可以传入参数进来)
    还有手感也很重要, sticker点击可以稍微压下去, 伴随一个随即方向的轻微旋转
    sticker会有一个些微的立体度, 很小但是要有

