# 🌐 校园网自动登录

校园网自动登录工具，包含两个实现：

- **Windows PowerShell 版**：不需要 Python、不需要浏览器、不需要 Selenium，直接调用 Dr.COM / EPortal 登录接口。
- **Router Dr.COM 版**：适合 SSH 解锁后的路由器直接承担校园网登录，不依赖电脑开机。

> ⚠️ 本仓库只提交模板与通用脚本。真实账号、密码、HAR 抓包、日志、学校内网地址请勿提交。

## Windows PowerShell 版

### 特点

- 使用 Windows 自带 PowerShell。
- 双击 `login.bat` 即可运行。
- 不依赖 Python、Edge、EdgeDriver 或 Selenium。
- 先检测是否已联网，已联网则跳过。
- 离线时抓取 portal 页面参数，再调用 Dr.COM JSONP 登录接口。
- 密码不会写入日志。

### 创建配置文件

```bash
cp config.ini.example config.ini
```

编辑 `config.ini`：

```ini
[login]
url = http://PORTAL_HOST/a79.htm?wlanacname=Huawei
login_base = http://PORTAL_HOST:801/eportal/portal/login
username = 你的学号
password = 你的密码
isp = @cmcc
account_prefix = ,0,
```

`config.ini` 包含账号密码，已被 `.gitignore` 排除，不要提交。

### 运行

双击：

```text
login.bat
```

或命令行运行：

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\login.ps1
```

日志写入：

```text
login.log
```

### Windows 开机自启动

可把 `login.bat` 的快捷方式放入：

```text
shell:startup
```

也可以使用任务计划程序，在用户登录时运行。

## Router Dr.COM 版

见 [`router/README.md`](router/README.md)。

核心思路：路由器每分钟检测是否联网；如果离线，使用 Dr.COM / EPortal 的 JSONP 登录接口提交认证；如果已联网，则跳过。

日志默认保存在：

```sh
/data/campus-login/campus-login.log
```

## 如何适配你的校园网

浏览器打开登录页，按 F12 → Network → Preserve log，手动登录一次，找到类似请求：

```text
/eportal/portal/login?callback=...&login_method=1&user_account=...&user_password=...
```

把观察到的值填入配置，尤其是：

- `url`
- `login_base`
- `isp`
- `account_prefix`

常见 Dr.COM 4.x 账号格式是：

```text
,0,学号@cmcc
```

也就是：

```ini
account_prefix = ,0,
isp = @cmcc
```

## 文件说明

```text
.
├── login.ps1                  # Windows PowerShell 主脚本
├── login.bat                  # Windows 双击入口
├── config.ini.example         # Windows 配置模板
├── requirements.txt           # 说明：不再需要 Python 依赖
├── router/
│   ├── README.md
│   ├── drcom-router-login.sh
│   └── router-config.example
└── README.md
```

## 安全提醒

- 不要提交 `config.ini`、`/data/campus-login/config`、HAR 抓包或日志。
- HAR / Copy as cURL 里通常包含账号密码，分享前必须脱敏。
- 日志不会记录密码，但会记录 portal 返回摘要，公开日志前仍建议检查。

## License

[MIT](LICENSE)
