# 用AutoIt写的24小时转播艾菲卡的机器人，龙珠版
# An assitant for 24-hour rebroadcasting afreeca streams in AutoIt，Longzhu.com version

## 使用: ##
+ 先安装[LiveStreamer](https://github.com/chrippa/livestreamer/releases)
+ 再安装VLC播放器(http://www.videolan.org/)
+ 将plugins中的插件拷贝到LiveStreamer安装目录的plugins文件夹，官方的插件目前还未更新，若已经更新则可跳过
+ 编辑live.ini，设置房间号，把所有sk2出现的地方替换成自己的房间号。房间号查找方法，打开直播页：http://star.longzhu.com/[房间号]
+ 启动longzhu.exe，自动下载房间配置
+ 启动后在直播间聊天栏输入指令，指令一般以/打头，具体参考下一节: 支持的指令
+ 需要聊天功能还需配置Live.ini中的RobotKey以及RobotName，参见这个[链接](http://www.tuling123.com/)，在聊天栏@机器人名字，机器人会回复
+ 

## 支持的指令 ##
+ /online：查看在线列表，由于直播间发言限制，会自动启动online.exe在桌面显示在线列表
+ /bisu: 切换到bisu的直播视角，要切换其他人直接使用/\[主播名\]，管理员换台自动锁定15分钟，并且忽略30秒内的其他非管理员换台命令
+ /playing: 查看所有主播的屏幕截图，根据屏幕大小显示前20-30个
+ /set \[比赛名称\]：设定当前比赛的名称或字幕信息，显示在屏幕指定位置，默认在位置6（右下角），共7处，调整位置在比赛名称前加@位置，如/set @7bisu vs flash
+ /music \[歌名\]：播放歌曲，目前支持主流音乐网站和本地文件夹中的音乐，本地文件放在./music/中，不输入歌名则停止当前音乐
+ /speak \[内容\]：播放语音，/speech off 关闭，/speech on 打开
+ /block \[关键字\]：自动将发关键字的用户永久禁言，Live.ini中配置开关和是否踢出直播间
+ /lock \[\[分钟数\]\]：锁定换台分钟数，默认是30，锁定期间不能换台，管理员换台不受此限制，/unlock解锁
+ 还有很多，参见longzhu.au3中OnChatMsg和OnChatCmd，懒得写了，以后有空再看吧
+ ...

## 示例: ##
+ [星际第一频道](http://star.longzhu.com/sk2)，从2014年开始运行至今

## 联系:  ##
+ 欢迎提issues
+ 1595152095 @qq.com

## 关于 AutoIt: ##
+ [ AutoIt ](https://www.autoitscript.com/site/) 
+ [中文社区](http://www.autoitx.com/)
这也是我第一个用AutoIt写的工具，主要参考自带的资料和这两个社区

## 协议 ##
+ GNU GPL，知道也很难被遵守，但还是写上吧
