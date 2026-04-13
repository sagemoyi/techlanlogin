# 🌐 校园网自动登录

开机自动登录校园网认证页面，无需手动操作。基于 Selenium + Edge 浏览器实现。

## ✨ 功能特性

- 🚀 **开机自动登录** — 配合任务计划程序，开机即联网
- 🔄 **失败自动重试** — 网络不稳定时自动重试多次
- 🧠 **联网预检** — 已连网时自动跳过，不做多余操作
- 🪟 **无头模式** — 后台静默运行，不弹窗打扰
- 📋 **日志记录** — 自动保存登录历史，方便排查问题
- 🔧 **驱动自动管理** — Selenium 4 自动下载匹配的 Edge 驱动

## 🚀 快速开始

### 1. 克隆项目

```bash
git clone https://github.com/sagemoyi/techlanlogin.git
cd techlanlogin
```

### 2. 安装依赖

需要 Python 3.8+ 和 Microsoft Edge 浏览器。

```bash
pip install -r requirements.txt
```

### 3. 创建配置文件

复制配置模板并填入你自己的账号信息：

```bash
cp config.ini.example config.ini
```

编辑 `config.ini`：

```ini
[login]
url = http://10.50.255.11/a79.htm?wlanacname=Huawei
username = 你的学号
password = 你的密码
isp = @cmcc
```

> ⚠️ **注意**：`config.ini` 包含你的账号密码，已被 `.gitignore` 排除，**不会被上传到 GitHub**。请勿手动提交此文件！

### 4. 测试运行

双击 `login.bat`，或在命令行执行：

```bash
python auto_login.py
```

首次运行时 Selenium 会自动下载匹配的 Edge 浏览器驱动，需要等待几秒。

### 5. 设置开机自启动

#### 方法一：启动文件夹（简单）

1. 按 `Win + R`，输入 `shell:startup`，回车
2. 将 `login.bat` 的 **快捷方式** 拖入该文件夹

#### 方法二：任务计划程序（推荐）

1. 按 `Win + R`，输入 `taskschd.msc`，回车
2. 右侧点击 **创建基本任务**
3. 名称填 `校园网自动登录`
4. 触发器选 **当用户登录时**
5. 操作选 **启动程序**：
   - 程序：`pythonw.exe`（用 `pythonw` 不会弹出控制台窗口）
   - 参数：`auto_login.py`
   - 起始目录：填你的项目实际路径
6. 勾选 **完成时打开属性对话框**，在 **条件** 选项卡里取消勾选"只有在计算机使用交流电源时才启动"

> **提示**：使用任务计划程序时，`config.ini` 中的 `startup_delay` 建议设为 `10`~`15`，给网卡留出初始化时间。

---

## ⚙️ 配置说明

| 配置项 | 说明 | 默认值 |
|--------|------|--------|
| `url` | 校园网认证页面地址 | — |
| `username` | 学号 | — |
| `password` | 密码 | — |
| `isp` | 运营商：`@cmcc` 移动 / `@telecom` 电信 / `@unicom` 联通 | `@cmcc` |
| `headless` | 无头模式：`true` 后台运行，`false` 显示浏览器 | `true` |
| `timeout` | 等待页面元素超时（秒） | `10` |
| `retry_count` | 登录失败重试次数 | `3` |
| `retry_delay` | 重试间隔（秒） | `5` |
| `startup_delay` | 开机延迟（秒），等待网卡就绪 | `10` |

---

## 📁 文件说明

```
campus-autologin/
├── auto_login.py        # 主脚本
├── config.ini.example   # 配置模板（复制为 config.ini 后使用）
├── config.ini           # 你的个人配置（不会上传，已 gitignore）
├── login.bat            # 双击启动 / 放入启动文件夹
├── login.log            # 运行日志（自动生成，不会上传）
├── requirements.txt     # Python 依赖
├── .gitignore           # Git 忽略规则
├── LICENSE              # MIT 开源协议
└── README.md            # 本文档
```

---

## 📝 日志

运行日志自动保存到 `login.log`，可随时查看历史登录记录和错误信息。

---

## 🤝 贡献

欢迎提 Issue 和 Pull Request！如果觉得有用请给个 ⭐ Star。

## 📄 License

[MIT](LICENSE)
